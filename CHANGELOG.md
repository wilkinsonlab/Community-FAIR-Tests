# Changelog

## [0.2.10] - 2026-09-04

### Changed

- `community_panet_vocabulary_in_metadata`: added additional valid ways for a DataCite subject to be recognized as PaNET, per community feedback on #12. Previously only `subjects[].schemeUri` or `subjects[].subjectScheme` containing the literal string "PaNET" counted; now `subjects[].schemeUri` or `subjects[].valueUri` containing the PaNET namespace `https://w3id.org/PaN/` also counts. This fixes false negatives for real-world records like ESRF's `10.15151/esrf-es-2494098874`, whose subjects use `schemeUri: "https://w3id.org/PaN/ESRFET/"` without the string "PaNET" anywhere in it. Bumped test version to `Tst-0.0.3`.

## [0.2.9] - 2026-08-11

### Fixed

- Bumped `fair_champion_harvester` to `~> 0.1.17`, which adds a TTL and a `Cache.purge` method to the harvester's `/tmp` file cache. Previously that cache never expired — once a record was written under `/tmp`, it was returned forever, since `/tmp` inside this container isn't a persistent volume and the only way to clear a stale entry was a full container restart or manually deleting files over SSH. Default TTL is 5 minutes (`CACHE_TTL` env var), short by design since harvested DCAT/TTL records under test change frequently and testers need to see edits reflected quickly.

## [0.2.8] - 2026-08-05

### Fixed

- Bumped `fair_champion_harvester` to `~> 0.1.16`. 0.1.15 adds a hard timeout to the external `extruct` subprocess `Extruct.do_extruct` shells out to: without it, a request whose content-type/magic-bytes didn't get caught as binary (unreliable headers, or just very large/slow HTML) could block a Puma worker thread — and leak an orphaned Python process — indefinitely, since `worker_timeout` only restarts a worker whose *every* thread has stopped responding. This was the primary driver of repeated multi-hour outages on `tests.ostrails.eu` (load average 40-50, multiple runaway `python3 extruct` processes, 68 zombie processes observed during one incident) — this container runs on the same host. 0.1.16 additionally syncs the `HARVESTER_VERSION` string embedded in every test's `testversion` output, which had drifted out of sync with the gem version.

## [0.2.7] - 2026-07-24

### Changed

- `dv_portugal_dv_controlled_vocabulariese`: implemented the PT Dataverse controlled-vocabulary keyword check (previously a placeholder copy-pasted from `dv_portugal_minimal_datacite`). Rather than a second Dataverse-specific HTTP fetch, the test scans `metadata.full_response` — the raw HTTP bodies the generic harvester already collected while resolving the DOI — for the Dataverse landing page's `#metadata_keyword` metadata-tab table row (the schema.org/JSON-LD block only exposes keywords as a flat string list, with no vocabulary info). Parses each keyword entry into Term / Term URI / Controlled Vocabulary Name / Controlled Vocabulary URL. Passes if at least one keyword carries both a vocabulary name and URL; Term URI is reported when present but not required for a pass, since real-world PT Dataverse records (including the community's own positive example) rarely populate it.

## [0.2.6] - 2026-07-24

### Changed

- `dv_portugal_minimal_datacite`: replaced the placeholder funding-block test (copy-pasted from `community_metadata_includes_author_affiliation`) with the actual PT Dataverse minimal provenance check. The test now resolves the DOI's registration agency, requires DataCite (indeterminate otherwise), then content-negotiates the DOI itself for `application/vnd.datacite.datacite+xml` and checks for creator, contributor, contributor role, date of collection (`dateType="Created"`), deposit date (`dateType="Submitted"`), publication date (`publicationYear`), and grant information (`fundingReferences`). Fails listing any missing elements rather than a single pass/fail funding check.

## [0.2.5] - 2026-06-30

### Changed

- Updated `fair_champion_harvester` dependency to `~> 0.1.14`, which fixes a critical cache collision bug: `Cache.checkRDFCache` was matching on byte-count instead of MD5 hash, causing wrong RDF graphs to be returned for unrelated resources after days of accumulated cache files. Symptom was completely incorrect metadata (from a different dataset) being returned, disappearing on service restart. Fixed by keying the cache lookup directly on `MD5(body)`, consistent with the write path.

## [0.2.4] - 2026-06-30

### Changed

- Updated `fair_champion_harvester` dependency to `~> 0.1.13`, which fixes JSON-LD context expansion: remote `@context` URLs (e.g. `http://schema.org`) are now resolved during parsing so that `@type: @id` coercions are applied correctly. Properties like `schema:license` now produce IRI resources rather than string literals, allowing FAIR license assessment tests to pass for datasets such as ESRF DOIs.

## [0.2.3] - 2026-05-27

- Previous release.
