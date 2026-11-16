# Export to LumiCodex for Lightroom Classic

This Lightroom Classic export service sends finished photos straight to a
LumiCodex album. It can select an existing album or create a public or private
one during export.

Gallery conflicts stop further uploads in the current export and display the
API explanation. Completed uploads remain in the album. Albums and collections
can receive future additions, including after a one-time gallery purchase.

## Requirements

- Adobe Lightroom Classic 13 or newer.
- `lumicodex-upload` v1.2.0 or newer, installed separately. Use the
  [uploader installers](https://github.com/LumiCodex/lumicodex-mcp-plugin/tree/main/scripts)
  or download the [uploader release](https://github.com/LumiCodex/lumicodex-mcp-plugin/releases/latest).
- A LumiCodex API key and account ID.
- Ultra exports only: libvips 8.15 or newer with ICC and AVIF support. JPEG XL
  also requires `cjxl` with `--override_bitdepth` support. Standard JPEG export
  needs neither tool.

Check the codec support used by Ultra mode:

```bash
vips list classes | grep VipsForeignSaveHeif
cjxl --version
```

## Install

1. Download `lumicodex-lightroom-plugin-1.0.0.zip` from the
   [latest release](https://github.com/LumiCodex/lumicodex-lightroom-plugin/releases/latest)
   and unzip it. Use the plugin archive, rather than GitHub's automatic source archive.
2. In Lightroom Classic, open **File → Plug-in Manager**.
3. Choose **Add**, then select `LumiCodex.lrplugin`.
4. Open the Export dialog and choose **LumiCodex** as the destination.
5. Check the uploader path, API URL, and account ID, then choose **Verify**.
   Leave the API key blank if you configured the uploader's saved credential,
   or enter a key for this export dialog only.

The default uploader path is `~/.lumicodex/bin/lumicodex-upload` on macOS and
`%USERPROFILE%\.lumicodex\bin\lumicodex-upload.exe` on Windows. Use the full
path so Lightroom can find it without a terminal's `PATH`. If the Windows
installer used the .NET fallback, select `lumicodex-upload.cmd` instead and
ensure .NET 10 is installed.

This plugin is for **Lightroom Classic**, not the cloud-based Lightroom app.

## Export

The destination section can search the current album list or create a new
album. New albums are private by default; the selected access is sent with the
create request before rendering starts.

Quality modes:

- **Standard** renders a high-quality JPEG at quality 90 in sRGB.
- **Ultra / AVIF** renders a 16-bit ProPhoto TIFF, color-converts it to Display
  P3, and writes a 10-bit 4:4:4 AVIF at quality 80.
- **Ultra / JPEG XL** uses the same Display P3 conversion and writes a 10-bit
  master at distance 0.7.

The long-edge field is optional. Leave it at `0` for full resolution.

Each completed rendition is uploaded through LumiCodex's existing asynchronous
ingest flow. If one photo fails, Lightroom marks that rendition failed and
continues; successful ingests remain in the album and can be published from the
admin. Export completion means the files were uploaded; server processing
continues asynchronously. Publish the album from LumiCodex when it is ready.
Entered API keys are passed through the child process environment and are not
saved in Lightroom preferences, export presets, manifests, or logs. Credentials
saved by `lumicodex-upload configure` use the operating-system credential store.

## Validate Ultra output

The verifier checks the encoded master before a development upload:

```bash
./scripts/verify-ultra.sh photo.avif photo.jxl
```

It requires `vipsheader` and `exiftool`. AVIF must report exactly 10 bits per
sample; JPEG XL must also report exactly 10; both must contain an ICC profile.

## Package

```bash
./scripts/package.sh 1.0.0
```

The archive is written to `dist/lumicodex-lightroom-plugin-1.0.0.zip`. Publishing
to GitHub is a separate operation after validation:

```bash
gh release create v1.0.0 dist/lumicodex-lightroom-plugin-1.0.0.zip \
  --repo LumiCodex/lumicodex-lightroom-plugin \
  --title "LumiCodex Lightroom Classic plugin v1.0.0" \
  --notes-file CHANGELOG.md
```

The optional CDN mirror is also an explicit operation:

```bash
./scripts/publish.sh 1.0.0
```

This uploads only the versioned Lightroom archive beneath
`s3://lc-media-eu-we-1/lumicodex/1.0.0-lightroom/`.

## Development checks

Lua 5.1 syntax and the gallery-conflict regression can be checked without
Lightroom. The contract runner uses the actual uploader with an isolated
localhost API fixture; it never uploads to a real account:

```bash
luac -p LumiCodex.lrplugin/*.lua tests/*.lua
python3 tests/check.py --lua lua --uploader /absolute/path/to/lumicodex-upload
```

To test actual Ultra encoding too, supply a color-managed 16-bit ProPhoto TIFF
named `render.tif`. Install the codec dependencies first:

```bash
python3 tests/check.py --lua lua --uploader /absolute/path/to/lumicodex-upload \
  --ultra-input /path/to/render.tif --keep-output /tmp/lightroom-ultra-check
./scripts/verify-ultra.sh /tmp/lightroom-ultra-check/render.avif /tmp/lightroom-ultra-check/render.jxl
```

The simulated host covers command quoting, Unicode and BOM handling, account
verification, private album creation, Standard and optional Ultra uploads,
individual upload failures, credential failures, and gallery conflicts. Windows
command construction is tested without executing Windows PowerShell.

See [VALIDATION.md](VALIDATION.md) for the first release's checked behavior and
remaining manual checks.

There is no headless Lightroom runtime. Before release, test five Standard
photos to a new private album, one AVIF and one JPEG XL export to an existing
album, invalid credentials, and a deliberately failed rendition. Confirm the
stored originals and generated derivatives in the admin.
