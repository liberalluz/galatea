### Added
- Detail shell hosting the zone skeleton in the fixed section order: switcher → 发音区 → 口型区 → 书写区 → 例词例句 (wireframe P3, SDD layout)
- Horizontal phoneme switcher at the top of the detail page: a strip of phoneme chips with the current chip highlighted plus prev/next arrows (`REQ-011`, wireframe P3)
- prev/next move to the adjacent phoneme in catalog order and refresh every section; the ends are disabled and do not wrap (`TC-DETAIL-004`)
- Chart grid navigation passes the full catalog to the detail route so the switcher can walk the catalog order
