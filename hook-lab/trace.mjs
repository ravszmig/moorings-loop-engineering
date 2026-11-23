// Every hook appends one JSON line per decision to .loop/<name>.jsonl.

import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'

export const ROOT = resolve(import.meta.dirname, '..')
export const LOOP = join(ROOT, '.loop')

// Windows PowerShell can put a byte order mark in front of the event.
export const readEvent = () => {
  try {
    return JSON.parse(readFileSync(0, 'utf8').replace(/^\uFEFF/, ''))
  } catch {
    return null
  }
}

export const trace = (name, entry) => {
  mkdirSync(LOOP, { recursive: true })
  const ignore = join(LOOP, '.gitignore')
  if (!existsSync(ignore)) writeFileSync(ignore, '*\n')
  appendFileSync(join(LOOP, `${name}.jsonl`),
    JSON.stringify({ at: new Date().toISOString(), ...entry }) + '\n')
}

export const readTrace = (name) => {
  const file = join(LOOP, `${name}.jsonl`)
  if (!existsSync(file)) return []
  return readFileSync(file, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l))
}

export const writeLog = (name, text) => {
  const file = join(LOOP, 'logs', `${name.replace(/[^A-Za-z0-9-]+/g, '-')}.log`)
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, text)
}
