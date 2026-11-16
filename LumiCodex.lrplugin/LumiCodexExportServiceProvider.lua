local LrBinding = import "LrBinding"
local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrPrefs = import "LrPrefs"
local LrTasks = import "LrTasks"
local LrView = import "LrView"

local Command = require "LumiCodexCommand"
local bind = LrView.bind
local prefs = LrPrefs.prefsForPlugin()
local states = setmetatable({}, { __mode = "k" })

local Provider = {
    hideSections = { "exportLocation", "fileNaming", "video", "outputSharpening", "watermarking", "postProcessing" },
    allowFileFormats = { "JPEG", "TIFF" },
    allowColorSpaces = { "sRGB", "ProPhotoRGB" },
    exportPresetFields = {
        { key = "LC_apiUrl", default = "https://api.lumicodex.com/" },
        { key = "LC_accountId", default = "" },
        { key = "LC_albumId", default = "" },
        { key = "LC_newAlbum", default = false },
        { key = "LC_newAlbumName", default = "" },
        { key = "LC_newAlbumAccess", default = "private" },
        { key = "LC_quality", default = "standard" },
        { key = "LC_codec", default = "avif" },
        { key = "LC_longEdge", default = 0 },
    },
}

local function commandSettings(propertyTable)
    return {
        apiKey = propertyTable.LC_apiKey,
        uploaderPath = propertyTable.LC_uploaderPath,
    }
end

local function filteredAlbumItems(propertyTable)
    local state = states[propertyTable] or { albums = {} }
    local search = (propertyTable.LC_albumSearch or ""):lower()
    local items = {}
    for _, album in ipairs(state.albums) do
        local name = album.name or "Untitled album"
        if search == "" or name:lower():find(search, 1, true) then
            local access = album.access == 1 and "Public" or "Private"
            items[#items + 1] = { title = name .. " — " .. access, value = album.id }
        end
    end
    if #items == 0 then items[1] = { title = "No matching albums", value = "" } end
    propertyTable.LC_albumItems = items
end

local function refreshAlbums(propertyTable, showErrors)
    propertyTable.LC_status = "Loading albums…"
    local ok, result = LrTasks.pcall(function()
        return Command.captureJson(
            commandSettings(propertyTable),
            Command.accountArguments(propertyTable, { "albums", "list" }))
    end)
    if not ok then
        propertyTable.LC_status = "Could not load albums"
        if showErrors then LrDialogs.message("LumiCodex", tostring(result), "critical") end
        return
    end
    states[propertyTable].albums = result
    filteredAlbumItems(propertyTable)
    propertyTable.LC_status = string.format("%d album%s", #result, #result == 1 and "" or "s")
end

local function verifyAccount(propertyTable)
    propertyTable.LC_status = "Checking API key…"
    local ok, result = LrTasks.pcall(function()
        return Command.captureJson(
            commandSettings(propertyTable),
            Command.accountArguments(propertyTable, { "whoami" }))
    end)
    if not ok then
        propertyTable.LC_verified = false
        propertyTable.LC_status = "API key not verified"
        LrDialogs.message("LumiCodex", tostring(result), "critical")
        return
    end
    propertyTable.LC_verified = true
    propertyTable.LC_status = "Connected to " .. (result.uniqueName or result.accountId or "LumiCodex")
    prefs.uploaderPath = propertyTable.LC_uploaderPath
    prefs.codec = propertyTable.LC_codec
    refreshAlbums(propertyTable, false)
end

function Provider.startDialog(propertyTable)
    states[propertyTable] = { albums = {} }
    -- Keys entered here last only for this dialog. Saved credentials belong to
    -- the uploader's operating-system credential store, never Lightroom prefs.
    prefs.apiKey = nil
    propertyTable.LC_apiKey = ""
    local defaultUploader = LrPathUtils.child(LrPathUtils.getStandardFilePath("home"), ".lumicodex/bin/lumicodex-upload")
    if WIN_ENV then defaultUploader = defaultUploader .. ".exe" end
    propertyTable.LC_uploaderPath = prefs.uploaderPath or defaultUploader
    propertyTable.LC_codec = prefs.codec or propertyTable.LC_codec or "avif"
    propertyTable.LC_albumSearch = ""
    propertyTable.LC_albumItems = { { title = "Verify your account to load albums", value = "" } }
    propertyTable.LC_status = "Not connected"
    propertyTable.LC_verified = false
    propertyTable:addObserver("LC_albumSearch", function() filteredAlbumItems(propertyTable) end)
end

function Provider.sectionsForTopOfDialog(f, propertyTable)
    return {
        {
            title = "LumiCodex account",
            synopsis = bind "LC_status",
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "Uploader", width = LrView.share "label_width" },
                f:edit_field { value = bind "LC_uploaderPath", width_in_chars = 42, immediate = true },
            },
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "API URL", width = LrView.share "label_width" },
                f:edit_field { value = bind "LC_apiUrl", width_in_chars = 42, immediate = true },
            },
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "Account ID", width = LrView.share "label_width" },
                f:edit_field { value = bind "LC_accountId", width_in_chars = 28, immediate = true },
            },
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "API key", width = LrView.share "label_width" },
                f:password_field { value = bind "LC_apiKey", width_in_chars = 30, immediate = true },
                f:push_button { title = "Verify", action = function() LrTasks.startAsyncTask(function() verifyAccount(propertyTable) end) end },
                f:static_text { title = bind "LC_status" },
            },
            f:static_text { title = "Leave the API key blank to use the uploader's saved credential. Entered keys are kept only for this dialog.", width_in_chars = 72, height_in_lines = 2 },
        },
        {
            title = "Destination album",
            f:row {
                spacing = f:control_spacing(),
                f:checkbox { title = "Create a new album", value = bind "LC_newAlbum" },
            },
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "Find", width = LrView.share "label_width" },
                f:edit_field { value = bind "LC_albumSearch", width_in_chars = 24, immediate = true },
                f:push_button { title = "Refresh", action = function() LrTasks.startAsyncTask(function() refreshAlbums(propertyTable, true) end) end },
            },
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "Existing", width = LrView.share "label_width" },
                f:popup_menu { value = bind "LC_albumId", items = bind "LC_albumItems", width_in_chars = 38 },
            },
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "New name", width = LrView.share "label_width" },
                f:edit_field { value = bind "LC_newAlbumName", width_in_chars = 28, immediate = true },
                f:popup_menu {
                    value = bind "LC_newAlbumAccess",
                    items = { { title = "Private", value = "private" }, { title = "Public", value = "public" } },
                },
            },
        },
    }
end

function Provider.sectionsForBottomOfDialog(f, propertyTable)
    return {
        {
            title = "LumiCodex quality",
            synopsis = bind "LC_quality",
            f:row {
                spacing = f:control_spacing(),
                f:radio_button { title = "Standard — high-quality JPEG, sRGB", value = bind "LC_quality", checked_value = "standard" },
            },
            f:row {
                spacing = f:control_spacing(),
                f:radio_button { title = "Ultra — wide-gamut master", value = bind "LC_quality", checked_value = "ultra" },
                f:popup_menu {
                    value = bind "LC_codec",
                    items = {
                        { title = "AVIF · 10-bit P3", value = "avif" },
                        { title = "JPEG XL · 10-bit P3", value = "jxl" },
                    },
                },
            },
            f:row {
                spacing = f:control_spacing(),
                f:static_text { title = "Optional long edge", width = LrView.share "label_width" },
                f:edit_field { value = bind "LC_longEdge", width_in_digits = 6, min = 0, max = 100000, precision = 0 },
                f:static_text { title = "pixels · 0 keeps full size" },
            },
            f:static_text {
                title = "Ultra renders a 16-bit ProPhoto TIFF, then the uploader color-converts it to Display P3 before encoding.",
                width_in_chars = 72,
                height_in_lines = 2,
            },
        },
    }
end

function Provider.updateExportSettings(exportSettings)
    local ultra = exportSettings.LC_quality == "ultra"
    exportSettings.LR_format = ultra and "TIFF" or "JPEG"
    exportSettings.LR_export_colorSpace = ultra and "ProPhotoRGB" or "sRGB"
    exportSettings.LR_jpeg_quality = 0.90
    exportSettings.LR_tiff_bitDepth = 16
    exportSettings.LR_tiff_compressionMethod = "compressionMethod_ZIP"
    exportSettings.LR_export_destinationType = "tempFolder"
    exportSettings.LR_collisionHandling = "overwrite"
    local longEdge = tonumber(exportSettings.LC_longEdge) or 0
    exportSettings.LR_size_doConstrain = longEdge > 0
    exportSettings.LR_size_resizeType = "longEdge"
    exportSettings.LR_size_maxWidth = longEdge
    exportSettings.LR_size_maxHeight = longEdge
end

local function resolveAlbum(propertyTable)
    if not propertyTable.LC_newAlbum then
        if not propertyTable.LC_albumId or propertyTable.LC_albumId == "" then error("Choose an existing album.") end
        return propertyTable.LC_albumId
    end
    if not propertyTable.LC_newAlbumName or propertyTable.LC_newAlbumName:match("%S") == nil then
        error("Enter a name for the new album.")
    end
    local result = Command.captureJson(
        commandSettings(propertyTable),
        Command.accountArguments(propertyTable, {
            "albums", "create",
            "--name", propertyTable.LC_newAlbumName,
            "--access", propertyTable.LC_newAlbumAccess,
        }))
    if not result.id then error("The API created no album id.") end
    return result.id
end

local function uploadFile(propertyTable, albumId, path)
    local arguments = Command.accountArguments(propertyTable, {
        "--container", albumId,
        "--no-wait",
        path,
    })
    Command.execute(commandSettings(propertyTable), arguments)
end

function Provider.processRenderedPhotos(functionContext, exportContext)
    local propertyTable = exportContext.propertyTable
    local progress = exportContext:configureProgress { title = "Exporting to LumiCodex", renderPortion = 0.45 }

    local function stopExport(message)
        for _, rendition in exportContext:renditions { stopIfCanceled = true } do
            rendition:uploadFailed(message)
        end
        LrDialogs.message("LumiCodex export stopped", message, "critical")
    end

    local ok, account = LrTasks.pcall(function()
        return Command.captureJson(
            commandSettings(propertyTable),
            Command.accountArguments(propertyTable, { "whoami" }))
    end)
    if not ok then
        stopExport("The API key could not be verified: " .. tostring(account))
        return
    end

    local albumOk, albumId = LrTasks.pcall(function() return resolveAlbum(propertyTable) end)
    if not albumOk then
        stopExport(tostring(albumId))
        return
    end

    local failures = {}
    local galleryConflict
    local completed = 0
    local total = exportContext.exportSession:countRenditions()
    for _, rendition in exportContext:renditions { stopIfCanceled = true } do
        local success, renderedPath = rendition:waitForRender()
        if success then
            local uploadPath = renderedPath
            local encodedPath
            local photoOk, message = LrTasks.pcall(function()
                if galleryConflict then error(galleryConflict) end
                if propertyTable.LC_quality == "ultra" then
                    local outputDirectory = LrPathUtils.child(LrPathUtils.getStandardFilePath("temp"), "lumicodex-ultra")
                    LrFileUtils.createAllDirectories(outputDirectory)
                    local result = Command.captureJson(commandSettings(propertyTable), {
                        "encode", "ultra",
                        "--codec", propertyTable.LC_codec,
                        "--out", outputDirectory,
                        renderedPath,
                    })
                    if not result[1] or not result[1].path then error("Ultra encoder returned no output path.") end
                    encodedPath = result[1].path
                    uploadPath = encodedPath
                end
                uploadFile(propertyTable, albumId, uploadPath)
            end)
            if not photoOk then
                if tostring(message):find("gallery_", 1, true) then
                    galleryConflict = tostring(message)
                end
                rendition:uploadFailed(tostring(message))
                failures[#failures + 1] = LrPathUtils.leafName(renderedPath) .. ": " .. tostring(message)
            end
            if encodedPath then LrFileUtils.delete(encodedPath) end
        else
            failures[#failures + 1] = tostring(renderedPath)
        end
        completed = completed + 1
        progress:setPortionComplete(0.45 + (0.55 * completed / math.max(total, 1)))
    end

    prefs.codec = propertyTable.LC_codec
    if #failures > 0 then
        LrDialogs.message(
            "LumiCodex export partly completed",
            table.concat(failures, "\n") .. (galleryConflict
                and "\n\nFurther uploads were stopped. Review the gallery in LumiCodex before exporting again. Completed ingests remain in the album."
                or "\n\nRetry the failed photos; completed ingests remain in the album."),
            "warning")
    end
end

return Provider
