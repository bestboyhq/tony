// `node scripts/package.ts`: builds Tony.app, signed with the Developer ID and the hardened runtime (ad hoc
// without one), into release/. Options:
//   --version 1.2.3      written into CFBundleShortVersionString and CFBundleVersion (Sparkle compares the latter)
//   --debug              a debug build, for development
//   --dmg                also the DMG users download, notarized and stapled when APPLE_KEYCHAIN_PROFILE names
//                        notarytool credentials (its ticket covers the app inside, which is stapled too)
//   --update             also the update zip, and appcast.xml signed with the EdDSA key in SPARKLE_PRIVATE_KEY
//                        (or --ed-key-file)
//   --name, --id, --feed, --public-key, --download-url, --out: a test build under its own identity
//                        (scripts/update-e2e.ts), so the installed Tony stays untouched. Its --out must be in a
//                        .noindex folder, so Spotlight and Open With never list it next to Tony
import { execFileSync } from 'node:child_process'
import { cpSync, mkdirSync, mkdtempSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { parseArgs } from 'node:util'

const root = resolve(import.meta.dirname, '..')
const { values: o } = parseArgs({
  options: {
    version: { type: 'string', default: '0.0.0' },
    debug: { type: 'boolean', default: false },
    dmg: { type: 'boolean', default: false },
    update: { type: 'boolean', default: false },
    name: { type: 'string', default: 'Tony' },
    id: { type: 'string', default: 'com.bestboyhq.tony' },
    feed: { type: 'string' },
    'public-key': { type: 'string' },
    'download-url': { type: 'string' },
    'ed-key-file': { type: 'string' },
    out: { type: 'string', default: join(root, 'release') },
  },
})
if (o.name !== 'Tony' && !/\.noindex(\/|$)/.test(resolve(o.out))) throw new Error(`--out ${o.out}: put a test build in a .noindex folder, so Spotlight never lists it`)
const sh = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: 'utf8', cwd: root, stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const run = (cmd: string, args: string[]) => execFileSync(cmd, args, { cwd: root, stdio: 'inherit' })

const config = o.debug ? 'debug' : 'release'
run('swift', ['build', '-c', config, '--arch', 'arm64', '--product', 'Tony'])
const products = sh('swift', ['build', '-c', config, '--arch', 'arm64', '--show-bin-path'])

// The bundle.
mkdirSync(o.out, { recursive: true })
const app = join(o.out, `${o.name}.app`)
rmSync(app, { recursive: true, force: true })
const contents = join(app, 'Contents')
for (const dir of ['MacOS', 'Frameworks', 'Resources']) mkdirSync(join(contents, dir), { recursive: true })
cpSync(join(products, 'Tony'), join(contents, 'MacOS', o.name))
run('ditto', [join(products, 'Sparkle.framework'), join(contents, 'Frameworks', 'Sparkle.framework')])
// The icon, from its one source: the Icon Composer file, compiled the way Xcode does (Assets.car, plus Tony.icns before macOS 26).
sh('xcrun', ['actool', join(root, 'build/Tony.icon'), '--compile', join(contents, 'Resources'), '--output-partial-info-plist', join(mkdtempSync(join(tmpdir(), 'tony-')), 'icon.plist'),
  '--app-icon', 'Tony', '--enable-on-demand-resources', 'NO', '--development-region', 'en', '--target-device', 'mac', '--minimum-deployment-target', '15.0', '--platform', 'macosx'])

const plist = join(contents, 'Info.plist')
cpSync(join(root, 'build/Info.plist'), plist)
const set = (key: string, value: string) => run('plutil', ['-replace', key, '-string', value, plist])
set('CFBundleShortVersionString', o.version)
set('CFBundleVersion', o.version)
set('CFBundleExecutable', o.name)
set('CFBundleName', o.name)
set('CFBundleDisplayName', o.name)
set('CFBundleIdentifier', o.id)
if (o.feed) set('SUFeedURL', o.feed)
if (o['public-key']) set('SUPublicEDKey', o['public-key'])
// A local test feed is plain http, which App Transport Security blocks unless it is local networking.
if (o.feed?.startsWith('http://')) run('plutil', ['-insert', 'NSAppTransportSecurity', '-json', '{"NSAllowsLocalNetworking":true}', plist])

// Signed inside out: Sparkle's helpers, Sparkle, then the app with its entitlements.
const identity = process.env.TONY_SIGN_IDENTITY ?? (sh('security', ['find-identity', '-v', '-p', 'codesigning']).includes('Developer ID Application') ? 'Developer ID Application' : '-')
// Ad hoc without the hardened runtime: its library validation refuses to load an ad hoc Sparkle, which has no Team ID.
// Debug builds skip the secure timestamp: only notarization needs it, and Apple's timestamp server often fails.
const sign = (path: string, ...extra: string[]) =>
  run('codesign', ['--force', '--sign', identity, ...(identity === '-' ? [] : ['--options', 'runtime', ...(o.debug ? [] : ['--timestamp'])]), ...extra, path])
const sparkle = join(contents, 'Frameworks/Sparkle.framework/Versions/B')
sign(join(sparkle, 'XPCServices/Installer.xpc'))
sign(join(sparkle, 'XPCServices/Downloader.xpc'), '--preserve-metadata=entitlements')
sign(join(sparkle, 'Autoupdate'))
sign(join(sparkle, 'Updater.app'))
sign(join(contents, 'Frameworks/Sparkle.framework'))
sign(app, '--entitlements', join(root, 'build/entitlements.plist'))
run('codesign', ['--verify', '--deep', '--strict', app])
console.log(`${app} (${identity === '-' ? 'ad hoc' : identity})`)

if (o.dmg) {
  // Notarized, then stapled; its ticket covers the app inside, which gets stapled before it is zipped.
  const dmg = join(o.out, `${o.name}-${o.version}.dmg`)
  const stage = mkdtempSync(join(tmpdir(), 'tony-dmg-'))
  run('ditto', [app, join(stage, `${o.name}.app`)])
  symlinkSync('/Applications', join(stage, 'Applications'))
  rmSync(dmg, { force: true })
  run('hdiutil', ['create', '-volname', o.name, '-srcfolder', stage, '-fs', 'APFS', '-format', 'UDZO', '-ov', dmg])
  rmSync(stage, { recursive: true })
  if (identity !== '-') run('codesign', ['--force', '--sign', identity, '--timestamp', dmg])
  const profile = process.env.APPLE_KEYCHAIN_PROFILE
  if (profile) {
    run('xcrun', ['notarytool', 'submit', dmg, '--keychain-profile', profile, '--wait'])
    run('xcrun', ['stapler', 'staple', dmg])
    run('xcrun', ['stapler', 'staple', app])
  } else {
    console.log('not notarized: set APPLE_KEYCHAIN_PROFILE')
  }
  console.log(dmg)
}

if (o.update) {
  // A zip of the app, signed with Sparkle's EdDSA key, and the feed that points at it.
  const zip = join(o.out, `${o.name}-${o.version}.zip`)
  rmSync(zip, { force: true })
  run('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', app, zip])
  let keyFile = o['ed-key-file']
  if (!keyFile) {
    if (!process.env.SPARKLE_PRIVATE_KEY) throw new Error('set SPARKLE_PRIVATE_KEY or --ed-key-file to sign the update')
    keyFile = join(mkdtempSync(join(tmpdir(), 'tony-key-')), 'key')
    writeFileSync(keyFile, process.env.SPARKLE_PRIVATE_KEY, { mode: 0o600 })
  }
  const signature = sh(join(root, '.build/artifacts/sparkle/Sparkle/bin/sign_update'), ['--ed-key-file', keyFile, '-p', zip])
  if (!o['ed-key-file']) rmSync(keyFile)
  const url = `${o['download-url'] ?? `https://github.com/bestboyhq/tony/releases/download/v${o.version}/`}${o.name}-${o.version}.zip`
  writeFileSync(join(o.out, 'appcast.xml'), appcast(o.name, o.version, url, statSync(zip).size, signature))
  console.log(`${zip}\n${join(o.out, 'appcast.xml')}`)
}

/** Sparkle's feed with the one latest version: it only ever needs the newest. */
function appcast(name: string, version: string, url: string, length: number, signature: string) {
  return `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>${name}</title>
    <item>
      <title>${version}</title>
      <pubDate>${new Date().toUTCString()}</pubDate>
      <sparkle:version>${version}</sparkle:version>
      <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <enclosure url="${url}" length="${length}" type="application/octet-stream" sparkle:edSignature="${signature}"/>
    </item>
  </channel>
</rss>
`
}
