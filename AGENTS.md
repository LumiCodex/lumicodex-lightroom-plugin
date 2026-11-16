# LumiCodex Lightroom Plugin

This project is a Lightroom Classic Lua export service. The `.lrplugin` bundle
must stay thin: Lightroom owns rendering and `lumicodex-upload` owns API calls,
album operations, ingest orchestration, and Ultra conversion.

## Contracts

- Never write the API key to a manifest, output file, fixture, or log. Pass it
  to the uploader through `LUMICODEX_API_KEY` only.
- Keep Standard output at JPEG quality 90 and sRGB.
- Keep Ultra input color-managed and 16-bit. The uploader converts the embedded
  input profile to Display P3; AVIF and JPEG XL are 10-bit.
- Ultra requires libvips with `icc_transform` and codec support. JPEG XL also
  requires `cjxl --override_bitdepth=10`; keep these as documented external
  dependencies unless licensing and packaging are deliberately revisited.
- A failed photo must not abort already successful ingests. Surface per-photo
  failures with Lightroom's rendition API.
- Network behavior belongs in `LumiCodex.Upload`; do not reimplement the ingest
  protocol in Lua.
- Use the uploader's `whoami` and `albums` JSON output for account/album
  discovery. Treat `encode ultra` output paths as generated upload inputs, and
  keep Standard renditions on the direct upload path.

## Release

Run `scripts/package.sh VERSION` for a local archive. `scripts/publish.sh` is a
separate, explicit deployment step and must stay scoped to the versioned
`lumicodex/VERSION-lightroom/` S3 prefix.

Lightroom cannot be exercised headlessly. Validate Lua syntax, uploader tests,
Ultra metadata, packaging contents, and then run the manual Lightroom matrix in
the README before release.
