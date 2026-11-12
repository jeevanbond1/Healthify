# Backup + nutrition verification evidence

## FNV-1a 64-bit (checksum primitive)

Independent Python implementation of the exact math in
`BackupCodec.fnv1a` (offset basis, per-byte xor-then-multiply,
64-bit wrap). Observed output (WSL Ubuntu, Python 3.14):

```text
empty : 0xcbf29ce484222325
a     : 0xaf63dc4c8601ec8c
foobar: 0x85944171f73967e8
FNV-1a vectors OK
```

`a → af63dc4c8601ec8c` matches the published FNV-1a-64 test vector,
so the primitive is correct; `foobar → …e8` is the validated digest.

Re-run (`/tmp/scratch_verify_fnv.py` while this session's WSL lives,
or paste below anywhere with Python 3):

```python
from functools import reduce

def fnv1a(data: bytes) -> int:
    return reduce(
        lambda h, b: ((h ^ b) * 1099511628211) & 0xFFFFFFFFFFFFFFFF,
        data, 0xCBF29CE484222325)

assert fnv1a(b'') == 0xCBF29CE484222325
assert fnv1a(b'a') == 0xAF63DC4C8601EC8C
assert fnv1a(b'foobar') == 0x85944171F73967E8
```

## Atwater seed check (16/16 pass, tolerance 15%)

PowerShell, 2026-11-12: `checked 16, failed 0`. Enforced in-repo by
`CoreTests.testSeedDataPassesAtwater`.

## Swift suite (`Tests/HealthifyCoreTests/CoreTests.swift`)

Run on WSL Ubuntu (Linux Swift; Combine-гated files excluded there,
iOS behavior unchanged):

```sh
cd /root/healthify-verify && swift test
```

Covers: maintain-target == TDEE, lose floor ≥ 1200 kcal, macro-kcal
consistency, seed Atwater, 200 g scaling, backup round-trip, tamper
rejection (checksumMismatch, data untouched), merge idempotence
(second merge reports "0 added"), set volume + personal records.

Result (2026-11-12, WSL Ubuntu 26.04, Swift 6.4.2):

```text
Test Suite 'CoreTests' passed
   Executed 9 tests, with 0 failures (0 unexpected)
Test Suite 'All tests' passed
   Executed 9 tests, with 0 failures (0 unexpected)
```

Note: the verify copy used a Linux-only manifest (App target aside —
SwiftUI/AVFoundation exist only in Apple's SDK). The repo's
`Package.swift` is unchanged; the iOS App target is type-checked by
the xtool device build (spike gate). Along the way the compiler caught
and we fixed 5 seed-data argument-order errors plus the Combine/Linux
guards; no test or model logic changed.
