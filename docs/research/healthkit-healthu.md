# Apple Health + HealthU+ integration findings

Decided 2026-11-12. All claims below were verified against the cited
sources during this session; unknowns are marked as such.

## HealthU+ scale path (verified)

HealthU+ (`com.lefuhealthu.app`, Lefu smart-scale companion) syncs
**Weight, Body Fat %, Lean Body Mass, BMI and Height** straight into
Apple HealthKit ([mwm.ai app page](https://mwm.ai/apps/healthu-tracker-weightloss/1397276518)).
There is no public API and no need for one: the user enables HealthKit
sync once inside HealthU+ (profile → Apple Health), steps on the scale,
and the readings arrive as ordinary HealthKit samples with source
`HealthU+`. Any other scale app that writes to Apple Health (Renpho,
Withings, Eufy, Wyze) works through the identical path — no per-vendor
code.

## Apple Health read pattern (verified)

- `HKAnchoredObjectQuery` per type with a persisted `HKQueryAnchor`
  returns only new/changed samples plus deleted UUIDs — the lossless
  incremental primitive ([Apple docs](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit)).
- `HKObserverQuery` fires while the app runs; `enableBackgroundDelivery`
  needs the background-delivery entitlement, so we sync on foreground
  + observer instead — no gap that an anchor can't cover.
- Anchors and samples are per-type; deleted objects report UUIDs only,
  so our own `externalId` registry is what makes deletes precise.
- Never read our own writes back (we write nothing, but the service
  still skips our bundle id defensively).

## Permissions (verified)

- Read-only import needs only `NSHealthShareUsageDescription` in
  Info.plist. No `NSHealthUpdateUsageDescription` (we never write).
- HealthKit capability: `com.apple.developer.healthkit = true`,
  works with a free Apple ID ([xtool source](https://github.com/xtool-org/xtool/blob/main/Sources/XKit/DeveloperServices/App%20IDs/Entitlements/DeveloperServicesCapability.swift)).
- The user grants categories in the iOS sheet; changes later in
  Settings → Privacy & Security → Health.

## xtool packaging (verified)

SwiftPM apps declare packaging in `xtool.yml` (`version: 1`,
`bundleID:`, `product:`, `infoPath:`, `entitlementsPath:`) — xtool
merges the given Info.plist and signs with the given entitlements
([skill guide](https://eliteai.tools/agent-skills/using-xtool),
[example](https://github.com/ethanlipnik/xtool/blob/HEAD/Documentation/xtool.docc/Control.md)).
Our files: `xtool.yml` (bundle `com.healthify.app`),
`Healthify-Info.plist` (share usage string),
`Healthify.entitlements` (healthkit only).

## Design decisions

- Import is additive and lossless: one entry per sample, never
  aggregated; re-imports dedupe by HealthKit UUID; deletions honored
  for imported entries only; manual entries are never touched.
- Nutrition samples become diary entries with time-of-day meal
  inference (documented, deterministic) and an "Apple Health · <app>"
  source line shown in the diary.
- Water merges per day with a UUID registry — the one type where a
  naive merge would double-count.
- Scale clusters (weight + fat + lean + BMI within 10 min) join into
  one weigh-in, matching how HealthU+ writes them.
- Anchors live in UserDefaults, not in the backup: after a reinstall,
  the first sync backfills and dedupes — duplicates impossible by
  construction, so no anchor backup is needed.
- Unknown: exact HealthU+ in-app toggle labels (verify on device);
  background-delivery entitlement deferred (foreground sync covers it).
