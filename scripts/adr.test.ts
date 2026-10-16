import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

const dir = join(import.meta.dirname, '../docs/adr')

test('docs/adr/README.md lists every ADR, numbered in order, each with a valid status', () => {
  const files = readdirSync(dir).filter((f) => f !== 'README.md').sort()
  const index = readFileSync(join(dir, 'README.md'), 'utf8')
  const listed = [...index.matchAll(/^\| \[(\d{4})\]\((.+?)\)/gm)].map((m) => m[2])
  assert.deepEqual(listed, files, 'the index rows and the files differ')
  files.forEach((file, i) => {
    const number = String(i + 1).padStart(4, '0')
    assert.match(file, new RegExp(`^${number}-[a-z0-9-]+\\.md$`), `${file}: expected number ${number}`)
    const text = readFileSync(join(dir, file), 'utf8')
    assert.match(text, new RegExp(`^# ${number} - .+\\n\\nStatus: (accepted|deprecated|superseded by \\d{4})\\n`), `${file}: title or status`)
    const by = text.match(/^Status: superseded by (\d{4})/m)?.[1]
    if (by) assert.ok(files.some((f) => f.startsWith(`${by}-`)), `${file}: superseded by a missing ADR ${by}`)
  })
})
