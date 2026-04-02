## Unreleased

### Fixes
- `from_regex/1`:
    - Ignore inline comments `(?# )`
    - Add support for `:extended` (`/x`) modifier
    - Add support for `:multiline` (`/m`) modifier

## 0.2.0 [2026-03-30]

### New Features
- `from_proto/1`
- `from_regex/1`:
    - Add support for `:caseless` (`/i`) modifier
    - Do not generate full text matching strings unless `^` and/or `$` are included

### Breaking changes
- Remove `timezone/0` generator

## 0.1.0 [2026-03-25]
Initial version
