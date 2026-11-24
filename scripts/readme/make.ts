// Records Tony's real HUD and panel for the README and the site, with nothing on the screen. `Tony --transcribe -hud
// YES` draws the HUD over a desktop from scene.html, in a window under the desktop picture; capture.swift records that
// window while a voice from `say` plays the user, and Tony swaps in the scene with the text typed the moment it lands.
// `Tony --panel` draws the panel's Home and Settings the same way, with made-up stats, for a still.
// Each comes in a dark and a light take, for the README's <picture> and the site's theme.
// Run from the repo, with Homebrew's ffmpeg (libsvtav1) and cwebp, and Screen Recording for the terminal:
//   node scripts/readme/make.ts [demo... | panel]   (all by default)
// It writes .github/readme/<demo>[-light].avif, and site/static/media/<demo>[-light].mp4 and .webp, its poster; and
// panel[-light].webp in both.
import { execFileSync } from 'node:child_process'
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

interface Demo {
  app: 'terminal' | 'assistant' | 'chat' | 'mail' // the window in scene.html
  voice: string // a `say` voice
  say: string
  languages?: string[]
  words?: string[] // the user's words
}

const DEMOS: Record<string, Demo> = {
  // Talking to an agent: the README's and the site's hero.
  hero: { app: 'terminal', voice: 'Samantha', say: 'Nice. Now do the same for gift cards. And make the error say the date the code expired, so people know it is not a typo.' },
  // A long prompt: the caption grows to five lines, then scrolls.
  long: {
    app: 'assistant',
    voice: 'Samantha',
    say: 'I am planning three days in Lisbon in March with two friends. We like long walks, good coffee, and small local restaurants more than famous ones. ' +
      'Can you plan each day around one neighborhood, with a place for lunch and a place for dinner, and keep the walking under ten kilometers a day? ' +
      'Also tell me which day is best for a trip to Sintra, and whether we need to book anything ahead.',
  },
  // Parakeet alone writes "tail scale" and "versal".
  words: { app: 'chat', voice: 'Samantha', say: 'Can you add Tailscale to the staging boxes and ping me on Vercel when the preview is up?', words: ['Tailscale', 'Vercel'] },
  languages: {
    app: 'mail',
    voice: 'Zosia',
    say: 'Cześć! Spotkanie z klientem przenosimy na czwartek. Przygotuję prezentację, a ty wyślij proszę notatki z ostatniego tygodnia. Dzięki!',
    languages: ['en', 'pl'],
  },
}

const ROOT = join(import.meta.dirname, '../..')
const README = join(ROOT, '.github/readme')
const SITE = join(ROOT, 'site/static/media')
const FPS = 60
const LEAD = 0.5 // s of Tony's 1 s lead before the pill that the clip keeps
const FADE = 0.5 // s the end takes to fade into the start, so the clip loops
const SCENE = { width: 830, height: 548, foot: 8 } // pt; the foot is under the screen's edge, so the clip leaves it out
const PANEL = { width: 960, height: 761 } // pt: Home and Settings side by side, Settings' glass 40 pt from top and foot
// The panel's last dictation: what Tony typed in the hero.
const LAST = 'Nice, now do the same for gift cards, and make the error say the date the code expired, so people know it is not a typo.'

const all = [...Object.keys(DEMOS), 'panel']
const names = process.argv.slice(2).length ? process.argv.slice(2) : all
for (const name of names) if (!all.includes(name)) throw new Error(`No demo ${name}: ${all.join(', ')}`)
const tmp = mkdtempSync(join(process.env.TMPDIR ?? tmpdir(), 'tony-readme-'))
const run = (cmd: string, args: string[], stderr: 'inherit' | 'ignore' = 'inherit') =>
  execFileSync(cmd, args, { encoding: 'utf8', timeout: 300_000, stdio: ['ignore', 'pipe', stderr], env: { ...process.env, SVT_LOG: '1' } })
const ff = (args: string[]) => run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args])

// Tony for release, with an Info.plist in the binary, where Bundle.main finds it, so Settings shows the latest
// release's version, not a development build's 0.0.0. And the capture tool, which compiles only as main.swift.
const version = run('git', ['describe', '--tags', '--abbrev=0']).trim().replace(/^v/, '')
const plist = join(tmp, 'Info.plist')
writeFileSync(plist, `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>${version}</string></dict></plist>
`)
execFileSync('swift', ['build', '-c', 'release', '--product', 'Tony', '-Xlinker', '-sectcreate', '-Xlinker', '__TEXT', '-Xlinker', '__info_plist', '-Xlinker', plist],
  { cwd: ROOT, stdio: 'inherit' })
const tony = join(run('swift', ['build', '-c', 'release', '--show-bin-path']).trim(), 'Tony')
const capture = join(tmp, 'capture')
copyFileSync(join(import.meta.dirname, 'capture.swift'), join(tmp, 'main.swift'))
run('swiftc', ['-O', '-swift-version', '5', '-suppress-warnings', '-o', capture, join(tmp, 'main.swift')])
mkdirSync(README, { recursive: true })
mkdirSync(SITE, { recursive: true })

/** scene.html at 2x. */
function scene(file: string, query: Record<string, string>, size = SCENE) {
  const url = pathToFileURL(join(import.meta.dirname, 'scene.html'))
  url.search = new URLSearchParams(query).toString()
  run(capture, [file, url.href, String(size.width), String(size.height)])
  return file
}

/** The clip from a recording: from the lead, without the foot, at FPS, fading back into its first frame. */
function clip(mov: string, out: string, poster: number) {
  const duration = Number(run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', mov])) - LEAD
  const master = join(tmp, `${out}-master.mov`)
  // Constant frames from the recording's start, then the lead trimmed: the recording has a frame only where the window
  // changed, so a seek past the lead would start at the next change and pull the clip ahead of Tony's timing.
  ff(['-i', mov, '-filter_complex',
    `[0]crop=iw:ih-${SCENE.foot * 2}:0:0,fps=${FPS},trim=start=${LEAD},setpts=PTS-STARTPTS,split[clip][head];` +
    `[head]trim=end_frame=1,loop=loop=${FPS}:size=1,setpts=PTS-STARTPTS[first];` +
    `[clip][first]xfade=transition=fade:duration=${FADE}:offset=${(duration - FADE).toFixed(3)}`,
    '-c:v', 'prores_ks', '-profile:v', '4444', '-pix_fmt', 'yuv444p10le', master])
  // AV1 in screen content mode, as Grip's README does (its export.ts says why): text stays sharp, and the tags keep
  // the dark UI from lifting.
  const tags = 'setparams=colorspace=bt709:color_primaries=bt709:color_trc=iec61966-2-1:range=tv'
  ff(['-i', master, '-an', '-vf', `scale='min(1660,iw)':-2:flags=lanczos:out_color_matrix=bt709:out_range=tv,format=yuv420p10le,${tags}`,
    '-c:v', 'libsvtav1', '-crf', '24', '-preset', '4', '-svtav1-params', 'scm=1', '-movie_timescale', String(FPS), join(README, `${out}.avif`)])
  // The site's clip and poster, as Grip's site/media.sh makes them, 1440 px wide for a column of about 720 pt.
  ff(['-i', master, '-an', '-vf', `scale=1440:-2:flags=lanczos:out_color_matrix=bt709:out_range=tv,format=yuv420p,${tags}`,
    '-c:v', 'libx264', '-preset', 'veryslow', '-crf', '26', '-level:v', '5.1', '-movflags', '+faststart', join(SITE, `${out}.mp4`)])
  const still = join(tmp, `${out}.png`)
  ff(['-ss', poster.toFixed(3), '-i', master, '-frames:v', '1', '-vf', 'scale=1440:-2:flags=lanczos', still])
  run('cwebp', ['-quiet', '-q', '88', still, '-o', join(SITE, `${out}.webp`)])
}

/** Half a year of made-up dictations for the panel, its days counted back from today, as Swift encodes Stats. The
 * same every run. */
function stats() {
  let seed = 20260
  const random = () => (seed = (seed * 16807) % 2147483647) / 2147483647
  const days: Record<number, { words: number }> = {}
  for (let back = 181; back >= 0; back--) {
    const weekend = [0, 6].includes(new Date(Date.now() - back * 86_400_000).getDay())
    // Every day of the last month, a streak; before that, most weekdays and a few weekends.
    if (back > 30 && random() < (weekend ? 0.8 : 0.15)) continue
    const words = Math.round((220 + (181 - back) * 2.4) * (0.4 + random() * 1.2) * (weekend ? 0.35 : 1))
    const dictations = Math.ceil(words / 24)
    days[-back] = {
      dictations,
      words,
      seconds: (words / (146 + random() * 12)) * 60,
      fillers: Math.round(words * 0.03 * random() * 2),
      yourWords: Math.round(dictations * 0.12 * random() * 2),
    }
  }
  const total = Object.values(days).reduce((sum, day) => sum + day.words, 0)
  // Apple's apps, which every Mac has, so the panel finds their names and icons.
  const share = { 'com.apple.Terminal': 0.43, 'com.apple.Safari': 0.27, 'com.apple.MobileSMS': 0.18, 'com.apple.Notes': 0.12 }
  const apps = Object.fromEntries(Object.entries(share).map(([id, part]) => [id, Math.round(total * part)]))
  const latencies = Array.from({ length: 100 }, () => Math.round(62 + random() * 30))
  return { days, apps, latencies }
}

for (const name of names.filter((name) => DEMOS[name])) {
  const demo = DEMOS[name]
  const voice = join(tmp, `${name}.aiff`)
  run('say', ['-v', demo.voice, '-o', voice, demo.say])
  const flags = ['-languages', `(${(demo.languages ?? ['en']).join(', ')})`, '-words', `(${(demo.words ?? []).join(', ')})`]
  // The text Tony will type, for the scene it lands in: the same audio always comes out the same.
  const text = run(tony, ['--transcribe', voice, ...flags], 'ignore').trim().split('\n').at(-1)!
  console.log(`${name}: ${text}`)
  for (const theme of ['dark', 'light']) {
    const out = theme === 'dark' ? name : `${name}-light`
    const backdrop = scene(join(tmp, `${out}.png`), { theme, app: demo.app, text })
    const landed = scene(join(tmp, `${out}-typed.png`), { theme, app: demo.app, text, landed: '1' })
    const mov = join(tmp, `${out}.mov`)
    // Each line Tony prints, on the recording's clock: the drafts, the text, and the key up's timing.
    const lines = run(capture, [mov, '--', tony, '--transcribe', voice, '-realtime', 'YES', '-hud', 'YES', '-backdrop', backdrop, '-landed', landed,
      '-appearance', theme, ...flags]).trim().split('\n').map((l) => l.split('\t'))
    const timing = lines.find(([, line]) => line.includes('key up to text'))
    if (!lines.some(([, line]) => line === text) || !timing) throw new Error(`${out}: Tony typed something else this time:\n${lines.map((l) => l.join('\t')).join('\n')}`)
    // The poster: the caption with every word, just before the key up. Tony prints the timing unbuffered, the moment
    // the text lands.
    const keyUp = Number(timing[0]) - Number(timing[1].match(/(\d+) ms/)![1]) / 1000
    console.log(`${out}: key up at ${keyUp.toFixed(2)} s, ${timing[1]}`)
    clip(mov, out, keyUp - LEAD - 0.1)
  }
}
if (names.includes('panel')) {
  const file = join(tmp, 'stats.json')
  writeFileSync(file, JSON.stringify(stats()))
  for (const theme of ['dark', 'light']) {
    const out = theme === 'dark' ? 'panel' : 'panel-light'
    const backdrop = scene(join(tmp, `${out}.png`), { theme, app: 'desk' }, PANEL)
    const mov = join(tmp, `${out}.mov`)
    run(capture, [mov, '--', tony, '--panel', '-backdrop', backdrop, '-stats', file, '-last', LAST, '-appearance', theme,
      '-languages', '(en, pl)', '-words', '(Tailscale, Vercel, Supabase, Moondream, Grafana)', '-AppleLocale', 'en_US'])
    // The last frame of the 2 s Tony shows it: the recording has a frame only where it changes.
    const still = join(tmp, `${out}-still.png`)
    ff(['-i', mov, '-vf', "select='lte(t,1.5)'", '-fps_mode', 'passthrough', '-update', '1', still])
    run('cwebp', ['-quiet', '-q', '90', still, '-o', join(README, `${out}.webp`)])
    copyFileSync(join(README, `${out}.webp`), join(SITE, `${out}.webp`))
    console.log(`${out}: done`)
  }
}
rmSync(tmp, { recursive: true })
