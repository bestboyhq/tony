// `node scripts/update-e2e.ts`: in-app updates end to end, the way a user gets them. A signed build of
// 0.0.1 finds 0.0.2 on a local feed, downloads it, and "Restart to Update" (clicked in the menu bar
// menu) relaunches it as 0.0.2. CI runs it before every release.
// Needs Accessibility for the terminal (it clicks the menu). It builds under its own name, app id, and
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
const dir = join(import.meta.dirname, '../.context/update-e2e')
const app = join(dir, 'Applications', `${NAME}.app`) // in an Applications folder, so it never offers to move itself
const sh = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const run = (cmd: string, args: string[]) => execFileSync(cmd, args, { stdio: 'inherit' })
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
const bar = `menu bar item 1 of menu bar 2 of process "${NAME}"`
const menu = () => {
  // Opening the status item's menu builds it fresh; Escape closes it again.
  const items = sh('osascript', ['-e', `tell application "System Events"
    click ${bar}
    delay 0.3
    set names to name of menu items of menu 1 of ${bar}
    key code 53
    return names
  end tell`])
  return items
}
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
  for (const end = Date.now() + ms; Date.now() < end; await sleep(1000)) {
    try {
      if (test()) return
    } catch {} // not there yet: no process, no menu
  }
  throw new Error(`timed out waiting for ${what}`)
}

// The app must be gone before its files: deleting a starting app crashes it.
async function cleanup() {
  quit('-TERM')
  await until('the app to quit', () => !running(), 15_000).catch(() => quit('-KILL'))
  await until('the app to be killed', () => !running(), 5000)
  for (const p of [`Library/Caches/${ID}`, `Library/HTTPStorages/${ID}`, `Library/Preferences/${ID}.plist`]) rmSync(join(homedir(), p), { recursive: true, force: true })
  try {
    sh('defaults', ['delete', ID])
  } catch {} // nothing to delete
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

// The feed: 0.0.2's appcast.xml and zip, on a free port (other runs may hold any fixed one).
const feed = createServer((req, res) => {
  const file = join(dir, '0.0.2', decodeURIComponent(new URL(req.url!, 'http://x').pathname))
  if (!existsSync(file)) return res.writeHead(404).end()
  createReadStream(file).pipe(res)
})
await new Promise<void>((resolve) => feed.listen(0, '127.0.0.1', resolve))
const url = `http://127.0.0.1:${(feed.address() as AddressInfo).port}/`

// Two signed builds with the update zip and feed; no DMG, no notarization (Sparkle checks the EdDSA
// signature and the code signature, not the ticket).
for (const v of ['0.0.1', '0.0.2']) {
  run('node', [join(import.meta.dirname, 'package.ts'), '--update', '--version', v, '--name', NAME, '--id', ID, '--out', join(dir, v),
    '--feed', `${url}appcast.xml`, '--download-url', url, '--public-key', pub, '--ed-key-file', keyFile])
}

try {
  await cleanup()
  sh('ditto', ['-x', '-k', join(dir, '0.0.1', `${NAME}-0.0.1.zip`), join(dir, 'Applications')])
  sh('defaults', ['write', ID, 'onboarded', '-bool', 'true']) // no onboarding window in the way
  spawn('open', ['-g', app], { stdio: 'ignore', detached: true }).unref()
  await until('0.0.1 to start', running)
  await until('Restart to Update in the menu', () => menu().includes('Restart to Update'))
  console.log(`menu: ${menu()}`)
  sh('osascript', ['-e', `tell application "System Events"
    click ${bar}
    delay 0.3
    click menu item "Restart to Update" of menu 1 of ${bar}
  end tell`])
  await until('0.0.2 to be installed', () => version() === '0.0.2')
  await until('0.0.2 to relaunch', () => running() && menu().includes('Check for Updates…'))
  console.log(`ok: 0.0.1 updated itself to ${version()} and relaunched`)
} finally {
  feed.close()
  await cleanup()
}
