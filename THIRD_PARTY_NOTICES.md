# Third-party notices

The Lightroom plugin archive contains Lua source only. It does not redistribute
the following tools:

- Adobe Lightroom Classic SDK runtime, supplied by Lightroom Classic.
- `lumicodex-upload`, distributed separately by LumiCodex.
- libvips, licensed under LGPL-2.1-or-later.
- libheif/libavif and their selected AV1 encoder, used through libvips for AVIF.
- libjxl, licensed under the BSD 3-Clause license; its `cjxl` tool writes
  JPEG XL.

Users install the native codec stack separately. A future release that bundles
native binaries must include the exact licenses and source-offer obligations
for those artifacts.
