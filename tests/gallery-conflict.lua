-- Run from the plugin root with Lua 5.1+; no Lightroom host or network required.
local uploads, failed, dialogs = 0, {}, {}
local command = {
    accountArguments = function(_, args) return args end,
    captureJson = function() return { accountId = "fixture" } end,
    execute = function()
        uploads = uploads + 1
        if uploads == 2 then error('LumiCodex returned 409: {"code":"gallery_maintenance","message":"Try again after maintenance."}') end
    end,
}
package.loaded.LumiCodexCommand = command
local modules = {
    LrPrefs = { prefsForPlugin = function() return {} end },
    LrTasks = { pcall = pcall },
    LrView = {}, LrBinding = {}, LrFileUtils = {},
    LrPathUtils = { leafName = function(path) return path end },
    LrDialogs = { message = function(_, message) dialogs[#dialogs + 1] = message end },
}
function import(name) return assert(modules[name], name) end
local provider = dofile("LumiCodex.lrplugin/LumiCodexExportServiceProvider.lua")
local context = {
    propertyTable = { LC_albumId = "album", LC_quality = "standard" },
    configureProgress = function() return { setPortionComplete = function() end } end,
    exportSession = { countRenditions = function() return 3 end },
    renditions = function()
        local i = 0
        return function()
            i = i + 1
            if i > 3 then return nil end
            local current = i
            return current, {
                waitForRender = function() return true, "photo" .. current .. ".jpg" end,
                uploadFailed = function(_, message) failed[current] = message end,
            }
        end
    end,
}
provider.processRenderedPhotos({}, context)
assert(uploads == 2, "The third photo must not contact the uploader after a gallery conflict")
assert(failed[1] == nil, "A completed photo must remain successful")
assert(failed[2] and failed[3], "Both unfinished renditions must report the conflict")
assert(dialogs[1]:find("Further uploads were stopped", 1, true))
print("Lightroom gallery-conflict export test passed")
