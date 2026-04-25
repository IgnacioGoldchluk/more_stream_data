## Unreleased

### Fixes
- `from_regex/1`:
    - Treat escaped `/` character as literal instead of returning error

## 0.4.0 [2026-04-21]

### New features
- `sample/2`: Samples elements from an input enum in random order

## 0.3.4 [2026-04-17]

### Fixes
- `from_regex/1`:
    - Union of empty string and pattern. For example `~r/^(|foo)$/` which matches the empty string `""` or the literal `"foo"` would previously raise
    - Edge case of `~r//` failing

## 0.3.3 [2026-04-16]

### Fixes
- `from_regex/1`:
    - Fix regression for strings of length = 1

## 0.3.2 [2026-04-16]

### Fixes
- `from_regex/1`:
    - Fix line and string anchors (`\A, ^, $, \z`) not working in unions. For example the regex `~r/^a$|^b$/` would previously raise

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
