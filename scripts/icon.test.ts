import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { artwork } from './icon.ts'

test('build/Tony.icon holds what scripts/icon.ts draws', () => {
  for (const [file, text] of Object.entries(artwork())) {
    assert.equal(readFileSync(join(import.meta.dirname, '../build/Tony.icon', file), 'utf8'), text, `${file} is stale: run node scripts/icon.ts`)
  }
})
