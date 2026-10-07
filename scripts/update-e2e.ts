// `node scripts/update-e2e.ts`: in-app updates end to end, the way a user gets them. A signed build of
// 0.0.1 finds 0.0.2 on a local feed, 0.0.3 ships before the user gets to it, and "Restart to Update"
// (clicked in the menu bar panel) relaunches it as 0.0.3, the latest, in one go. CI runs it before every release.
// Needs Accessibility for the terminal (it clicks the panel). It builds under its own name, app id, and
// a throwaway EdDSA key, so an installed Tony, its settings, and the real signing key stay untouched.
import { execFileSync, spawn } from 'node:child_process'
import { generateKeyPairSync } from 'node:crypto'
import { createReadStream, existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { createServer } from 'node:http'
import type { AddressInfo } from 'node:net'
import { homedir } from 'node:os'
import { join } from 'node:path'

const NAME = 'TonyUpdateTest'
const ID = 'com.bestboyhq.tony.updatetest'
const dir = join(import.meta.dirname, '../.context/update-e2e.noindex') // .noindex: Spotlight never lists the test builds
const app = join(dir, 'Applications', `${NAME}.app`) // in an Applications folder, so it never offers to move itself
const sh = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const run = (cmd: string, args: string[]) => execFileSync(cmd, args, { stdio: 'inherit' })
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
// Opens the menu bar panel and returns the accessibility identifiers in it, then clicks the element with
// identifier `press`, or closes the panel again. Identifiers, since System Events can't read a SwiftUI
// button's label: its description is "button".
const panel = (press?: string) => sh('osascript', ['-l', 'JavaScript', '-e', `
  const p = Application('System Events').processes['${NAME}'], icon = p.menuBars[1].menuBarItems[0]
  const id = (e) => { try { return e.attributes.byName('AXIdentifier').value() } catch (_) { return '' } }
  const shown = () => p.windows().flatMap((w) => w.entireContents()).filter(id)
  let elements = shown()
  if (!elements.some((e) => id(e) === 'settings')) { icon.click(); delay(0.5); elements = shown() }
  const ids = elements.map(id) // before the click: once the panel closes, its elements read as nothing
  ${press ? `elements.find((e) => id(e) === '${press}').click()` : 'icon.click()'}
  ids.join(', ')`])
const executable = `${app}/Contents/MacOS/${NAME}`
const quit = (signal: string) => spawn('pkill', [signal, '-f', executable])
function running() {
  try {
    return sh('pgrep', ['-f', executable]).length > 0
  } catch {
    return false // pgrep exits 1 when nothing matches
  }
}
const version = () => sh('defaults', ['read', join(app, 'Contents/Info.plist'), 'CFBundleShortVersionString'])

async function until(what: string, test: () => boolean, ms = 180_000) {
  let last: unknown
  for (const end = Date.now() + ms; Date.now() < end; await sleep(1000)) {
    try {
      if (test()) return
    } catch (error) {
      last = error // not there yet: no process, no panel
    }
  }
  throw new Error(`timed out waiting for ${what}`, { cause: last })
}

// The app must be gone before its files: deleting a starting app crashes it.
async function cleanup() {
  quit('-TERM')
  await until('the app to quit', () => !running(), 15_000).catch(() => quit('-KILL'))
  await until('the app to be killed', () => !running(), 5000)
  try {
    sh('defaults', ['delete', ID]) // before the files: it leaves an empty plist behind
  } catch {} // nothing to delete
  for (const p of [`Library/Caches/${ID}`, `Library/HTTPStorages/${ID}`, `Library/HTTPStorages/${ID}.binarycookies`, `Library/Preferences/${ID}.plist`]) rmSync(join(homedir(), p), { recursive: true, force: true })
  if (existsSync(app)) execFileSync('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister', ['-u', app])
  rmSync(join(dir, 'Applications'), { recursive: true, force: true })
}

// A throwaway Sparkle key: base64 of the Ed25519 seed (private) and of the raw public key.
const { privateKey, publicKey } = generateKeyPairSync('ed25519')
const seed = privateKey.export({ format: 'der', type: 'pkcs8' }).subarray(-32)
const pub = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64')
mkdirSync(dir, { recursive: true })
const keyFile = join(dir, 'ed25519.key')
writeFileSync(keyFile, seed.toString('base64'), { mode: 0o600 })

// The feed: the latest release's appcast.xml and zip, on a free port (other runs may hold any fixed one).
let latest = '0.0.2'
const feed = createServer((req, res) => {
  const file = join(dir, latest, decodeURIComponent(new URL(req.url!, 'http://x').pathname))
  if (!existsSync(file)) return res.writeHead(404).end()
  createReadStream(file).pipe(res)
})
await new Promise<void>((resolve) => feed.listen(0, '127.0.0.1', resolve))
const url = `http://127.0.0.1:${(feed.address() as AddressInfo).port}/`

// Signed builds with the update zip and feed; no DMG, no notarization (Sparkle checks the EdDSA
// signature and the code signature, not the ticket).
for (const v of ['0.0.1', '0.0.2', '0.0.3']) {
  run('node', [join(import.meta.dirname, 'package.ts'), '--update', '--version', v, '--name', NAME, '--id', ID, '--out', join(dir, v),
    '--feed', `${url}appcast.xml`, '--download-url', url, '--public-key', pub, '--ed-key-file', keyFile])
}

try {
  await cleanup()
  sh('ditto', ['-x', '-k', join(dir, '0.0.1', `${NAME}-0.0.1.zip`), join(dir, 'Applications')])
  sh('defaults', ['write', ID, 'onboarded', '-bool', 'true']) // no onboarding window in the way
  spawn('open', ['-g', app], { stdio: 'ignore', detached: true }).unref()
  await until('0.0.1 to start', running)
  await until('Restart to Update in the panel', () => panel().includes('restart-to-update'))
  latest = '0.0.3' // a release ships while the user hasn't restarted yet
  // Retried: the panel the last check closed can still be fading out, its buttons gone.
  await until('a click on Restart to Update', () => {
    console.log(`panel: ${panel('restart-to-update')}`)
    return true
  })
  await until('an update to be installed', () => version() !== '0.0.1')
  await until('the update to relaunch', () => running() && panel().includes('settings'))
  if (version() !== '0.0.3') throw new Error(`updated to ${version()}, not the latest, 0.0.3`)
  console.log(`ok: 0.0.1 updated itself to ${version()}, the latest, and relaunched`)
} catch (error) {
  // What the app saw, since CI shows nothing else.
  try {
    console.log(`panel: ${panel()}`)
  } catch (e) {
    console.log(`panel: ${e}`)
  }
  const log = execFileSync('log', ['show', '--last', '5m', '--info', '--style', 'compact', '--predicate', 'subsystem BEGINSWITH "org.sparkle-project"'], { encoding: 'utf8', maxBuffer: 1 << 30 })
  console.log(log.split('\n').slice(-80).join('\n'))
  throw error
} finally {
  feed.close()
  await cleanup()
  rmSync(dir, { recursive: true, force: true })
}
