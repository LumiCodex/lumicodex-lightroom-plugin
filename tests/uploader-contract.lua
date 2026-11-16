package.path = "tests/?.lua;" .. package.path
local Host = require "TestHost"
local Command = require "LumiCodexCommand"
local Provider = require "LumiCodexExportServiceProvider"
local temp = assert(os.getenv("LUMICODEX_TEST_TEMP"))
local settings = {
    LC_uploaderPath = assert(os.getenv("LUMICODEX_TEST_UPLOADER")),
    LC_apiUrl = assert(os.getenv("LUMICODEX_TEST_API_URL")),
    LC_accountId = "fixture-account",
    LC_apiKey = "fixture-'key-$&%",
    LC_albumId = "fixture-album",
    LC_quality = "standard",
}
local function capture(args)
    return Command.captureJson({ uploaderPath = settings.LC_uploaderPath, apiKey = settings.LC_apiKey },
        Command.accountArguments(settings, args))
end
assert(capture({ "whoami" }).accountId == "fixture-account")
assert(capture({ "albums", "list" })[1].name == "Sélection 📷")
local name = "L'été $&% \"selects\" 📷"
assert(capture({ "albums", "create", "--name", name, "--access", "private" }).name == name)

local dialog = { addObserver = function() end }
Provider.startDialog(dialog)
assert(Host.prefs.apiKey == nil and dialog.LC_apiKey == "", "Never keep keys in Lightroom preferences")
local standard = { LC_quality = "standard", LC_longEdge = 0 }
Provider.updateExportSettings(standard)
assert(standard.LR_format == "JPEG" and standard.LR_jpeg_quality == 0.90)
assert(standard.LR_export_colorSpace == "sRGB" and not standard.LR_size_doConstrain)
local ultra = { LC_quality = "ultra", LC_longEdge = 2048 }
Provider.updateExportSettings(ultra)
assert(ultra.LR_format == "TIFF" and ultra.LR_tiff_bitDepth == 16)
assert(ultra.LR_export_colorSpace == "ProPhotoRGB" and ultra.LR_size_maxWidth == 2048)

local context, failed = Host.context(settings, { temp .. "/one's $&% 📷.jpg", temp .. "/reject.jpg", temp .. "/three.jpg" })
Provider.processRenderedPhotos({}, context)
assert(not failed[1] and failed[2] and not failed[3], "A failed photo must not prevent later uploads")

settings.LC_apiKey = "invalid-fixture-key"
context, failed = Host.context(settings, { temp .. "/three.jpg" })
Provider.processRenderedPhotos({}, context)
assert(failed[1], "Authentication failure must mark renditions failed")
settings.LC_apiKey = "fixture-'key-$&%"
settings.LC_newAlbum = true
settings.LC_newAlbumName = "Export-created album"
settings.LC_newAlbumAccess = "private"
context, failed = Host.context(settings, { temp .. "/three.jpg" })
Provider.processRenderedPhotos({}, context)
assert(not failed[1], "Export must create an album before uploading")

local tiff = os.getenv("LUMICODEX_TEST_TIFF")
if tiff and tiff ~= "" then
    settings.LC_newAlbum = false
    settings.LC_quality = "ultra"
    for _, codec in ipairs({ "avif", "jxl" }) do
        settings.LC_codec = codec
        context, failed = Host.context(settings, { tiff })
        Provider.processRenderedPhotos({}, context)
        assert(not failed[1], failed[1])
        assert(not io.open(temp .. "/lumicodex-ultra/render." .. codec), "Encoded temporary input must be deleted")
    end
end
print("Lightroom real-uploader contract tests passed")
