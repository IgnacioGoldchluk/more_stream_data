## Unreleased

### New features
- `from_regex/1`:
    - Limited support for atomic groups `(?>...)`. Generates values based on the first group option

## 0.3.1 [2026-04-06]

### New features
- `from_regex/1`:
    - Add `:character_set` option

## 0.3.0 [2026-04-04]

### Fixes
- `from_regex/1`:
    - Ignore inline comments `(?# )`
    - Generate characters from extended ASCII range and non-printable characters

### New features
- `from_regex/1`:
    - Add support for `:extended` (`/x`) modifier
    - Add support for `:multiline` (`/m`) modifier
    - Add support for `:firstline` (`/f`) modifier
    - Add support for `:dotall` (`/s`) modifier

## 0.2.0 [2026-03-30]

### New features
- `from_proto/1`
- `from_regex/1`:
    - Add support for `:caseless` (`/i`) modifier
    - Do not generate full text matching strings unless `^` and/or `$` are included

### Breaking changes
- Remove `timezone/0` generator

## 0.1.0 [2026-03-25]
Initial version
