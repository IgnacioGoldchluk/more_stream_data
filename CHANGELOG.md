## Unreleased

## 0.7.1 [2026-05-07]

### Internal
- Update `:decimal` version. See [CVE-2026-32686](https://cna.erlef.org/cves/CVE-2026-32686.html)

## 0.7.0 [2026-05-06]

### Breaking changes
- Remove `from_proto/1`. The code adds an unnecessary dependency (`protobuf`) for most cases, and is trivial to implement.

## 0.6.1 [2026-05-02]

### Fixes
- `from_regex/1`:
    - Fix codepoints being treated as multiple literal bytes. For example the character `’` (8217) was previously being treated as the codepoints 226, 128, 253.

## 0.6.0 [2026-04-29]

### New features
- `email/1`
    - Add `:max_length` option

## 0.5.1 [2026-04-25]

### Fixes
- `from_regex/1`:
    - Fix group inside negative lookahead and negative lookbehind creating invalid AST


## 0.5.0 [2026-04-25]

### New features
- `from_regex/1`:
    - Add support for negative lookahead and negative lookbehind assertions

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
