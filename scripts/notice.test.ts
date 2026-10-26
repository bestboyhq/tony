import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const read = (file: string) => readFileSync(join(import.meta.dirname, '..', file), 'utf8')

test('NOTICE lists every Swift package, and About credits the same components in the same order', () => {
  const notice = read('NOTICE')
  // A component is a section with a License: line; the Apache License text at the end is not one.
  const components = notice.split(/^=+$/m).slice(1).filter((s) => /^License: /m.test(s)).map((s) => s.trim().split('\n')[0])
  const about = [...read('Sources/Tony/Shell/AboutView.swift').matchAll(/credit\("([^"]+)"/g)].map((m) => m[1])
  assert.deepEqual(about, components, 'About and NOTICE credit different components')
  for (const { identity } of JSON.parse(read('Package.resolved')).pins)
    assert.ok(components.some((c) => c.toLowerCase() === identity), `NOTICE lacks the package ${identity}`)
})

test('one copyright line everywhere', () => {
  const line = '2026 Szymon Grącki and Tony contributors'
  for (const file of ['NOTICE', 'README.md', 'build/Info.plist', 'Sources/Tony/Shell/AboutView.swift', 'site/src/lib/Footer.svelte'])
    assert.ok(read(file).includes(line), `${file} lacks "${line}"`)
})
