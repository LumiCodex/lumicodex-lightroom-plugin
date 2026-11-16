# v1.0.0 validation

Automated checks completed on Linux on 2026-11-16:

- All Lua files parse under Lua 5.1.5.
- Current development uploader: all eight .NET uploader tests pass.
- Plugin contract tests pass against both the published v1.2.0 Linux uploader
  and the current development uploader. These exercise real child processes
  and HTTP uploads against an isolated local API fixture.
- Standard export settings, account verification, listing and creating albums,
  per-photo failure recovery, invalid credentials, and gallery conflicts pass.
- Unicode, quotes, shell characters, Windows command construction, and
  PowerShell UTF-8 BOM handling pass in the simulated Lightroom host.
- Real Ultra exports pass with libvips 8.15.1 and cjxl 0.13.0. Both received
  AVIF and JPEG XL files report 10 bits per sample and an embedded ICC profile.
- Admin production build and desktop/mobile rendering of the integration links pass.
- The release ZIP contains the Lua plugin and user documentation only.

The local API fixture follows the current account, container-creation and ingest
request/response contracts. It does not replace a test against a live backend.

## Manual checks still required

Adobe Lightroom Classic cannot run on this Linux host. No manual Lightroom
validation or real account upload was performed. Before declaring host support
verified, run the README matrix on Windows and macOS:

1. Install the plugin and uploader; verify the account and album picker.
2. Export five Standard photos to a new private album.
3. Export one AVIF and one JPEG XL photo to an existing album.
4. Verify invalid credentials and an individual failed rendition.
5. Confirm stored originals and generated derivatives in the LumiCodex admin.
6. Check cancellation and repeat exports, including the Windows .NET fallback
   if it is used and native uploader/codec discovery from the macOS GUI.
