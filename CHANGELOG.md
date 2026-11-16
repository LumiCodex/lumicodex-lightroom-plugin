# Changelog

## 1.0.0

- Export Lightroom Classic photos to existing or new public/private LumiCodex albums.
- Standard JPEG export at quality 90 in sRGB, with optional long-edge resizing.
- Ultra AVIF and JPEG XL export through a 16-bit ProPhoto TIFF and Display P3 conversion.
- Use the uploader's saved credential or a key entered for the current dialog.
- Handle individual failures and gallery conflicts without undoing successful uploads.
- Quote Windows commands safely and read PowerShell UTF-8 output.

Requires Lightroom Classic 13+ and LumiCodex uploader v1.2.0+.
Lightroom host behavior on macOS and Windows still requires the manual checks
described in the README; automated checks use a simulated Lightroom host.
