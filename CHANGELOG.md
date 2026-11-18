# Changelog



## [0.2.14] - 2026-11-18

### Added

- `dabar_author_orcid_or_mbz`: new community test for metric `FM_R1.2_M_ORCID_MBZ` (FAIR Metric – R1.2 – Metadata – ORCID or MBZ identifiers for people), per #21. The test collects DataCite authors (`datacite:creator`) from two sources: the `oai_datacite` record that the harvester now picks up from a repository's OAI-PMH endpoint (e.g. FULIR / DABAR), and, for DataCite DOIs, the DataCite XML returned by content negotiation on the DOI. For each author it checks `nameIdentifier` (by `nameIdentifierScheme`) and `creatorIdentifier` (by `identifierType` or `scheme`), and accepts a non-empty value whose scheme is `ORCID` or `MBZ`. Each author's identifiers, or the lack of them, are written to the test comments. Pass if at least one author has an ORCID or MBZ, as the metric definition states; fail if authors are found but none has one; indeterminate if no DataCite metadata with identifiable authors can be retrieved (e.g. a Crossref DOI, or a landing page with no discoverable OAI-PMH `oai_datacite` record). Verified against the issue's example record, given as either its URN (`https://urn.nsk.hr/urn:nbn:hr:241:219629`) or its landing page (`https://data.fulir.irb.hr/object/irb:906`); both pass, with 3 of 3 authors identified.
- `dabar_croatian_classification_subject`: new community test for metric `FM_R1.3_M_UseCCSAA` (FAIR Metric – R1.3 – Metadata – use of Croatian classification of scientific and artistic areas, fields and branches), per #22. It uses the same two DataCite sources as `dabar_author_orcid_or_mbz`: the harvested OAI-PMH `oai_datacite` record, and DataCite XML from content negotiation on DataCite DOIs. Pass if at least one `datacite:subject` has `subjectScheme="nvzz.hr"` (ignoring case) and a non-empty value; the matching classification values, with their language, are written to the comments. Ordinary keywords without that scheme do not count. Fail if subjects are found but none uses `nvzz.hr`; the comments name the schemes that were used instead. Indeterminate if no DataCite subject values can be retrieved, as the issue specifies. Verified against FULIR records `irb:906` and `irb:33` (pass), the ESRF DataCite DOI `10.15151/ESRF-ES-2303075148`, whose subjects use other schemes (fail), and a Crossref DOI (indeterminate).

### Fixed

- Corrected the version heading of the previous release in this file, `0.5.12` → `0.2.13`, to match `VERSION.txt` and the image tag that release published.

## [0.2.13] - 2026-09-30

### Bump harvester gem
0.1.18 which now has OAI-PMH support and issues a specific user agent header 
to be allowed in to blocked websites


## [0.2.12] - 2026-09-16

### Changed

- Standardized DOI-URL handling across all DOI-aware tests (`community_license_information`, `community_metadata_includes_author_affiliation`, `community_panet_vocabulary_in_metadata`, `community_open_access_publication`, `dv_portugal_minimal_datacite`, `dv_portugal_dv_controlled_vocabularies`): the incoming guid is now stripped down to a bare DOI only when it is specifically a `doi.org` URL, matching the fix already applied to `community_funding_information_registered` in the previous release. Previously each of these tests stripped *any* URL-shaped guid down to its path, which (a) silently mangled non-DOI URLs before resolution, and (b) meant that submitting a DOI as a bare string versus as a `https://doi.org/...` URL could take different code paths through the harvester and produce different results for the same underlying identifier. Both forms of a DOI now always resolve identically. Bumped test versions accordingly.

## [0.2.11] - 2026-09-16

### Changed

- `community_funding_information_registered`: per #17, the test now also checks the harvested metadata graph (`metadata.graph`) for a `schema:funding` triple, under either the `http://schema.org/` or `https://schema.org/` namespace, e.g. an embedded JSON-LD snippet on the landing page. This runs regardless of GUID type, so non-DOI GUIDs (previously always "indeterminate") now get a real pass/fail. The DataCite/Crossref check remains as a DOI-only fallback when no schema.org funding metadata is found. Also fixed a latent bug where the guid-to-raw-DOI stripping logic matched *any* URL, not just `doi.org` URLs — this silently mangled non-DOI GUIDs like `https://ora.ox.ac.uk/objects/uuid:...` into a bare path before resolution, causing them to be misidentified. Bumped test version to `Tst-0.0.3`.

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
