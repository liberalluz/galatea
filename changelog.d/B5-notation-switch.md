### Added
- Notation switch (KK / DJ / IPA) at the top of the chart page, KK as the default on first launch (`REQ-003`, `TC-CHART-003`, wireframe P1)
- Switching to DJ or IPA re-renders the grid symbols from the bundled correspondence data (B3) while the phoneme identities stay the same
- Selected-phoneme state on the chart grid: the highlighted phoneme survives notation switches and route round-trips
- Domain glyph resolver with the SDD §3.2 missing-glyph fallback: a phoneme missing in the target notation keeps the previous notation's glyph (unit-tested)
