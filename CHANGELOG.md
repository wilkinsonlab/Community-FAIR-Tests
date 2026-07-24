# Changelog

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
