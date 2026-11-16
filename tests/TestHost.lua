-- Minimal Lightroom boundary for exercising the real plugin and uploader.
local Host = { prefs = { apiKey = "obsolete-fixture-key" }, dialogs = {} }
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function Host.base64(value)
    local out = {}
    for i = 1, #value, 3 do
        local a, b, c = value:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = alphabet:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = alphabet:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = b and alphabet:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = c and alphabet:sub(n % 64 + 1, n % 64 + 1) or "="
    end
    return table.concat(out)
end
local modules = {
    LrBinding = {}, LrView = {},
    LrPrefs = { prefsForPlugin = function() return Host.prefs end },
    LrStringUtils = { encodeBase64 = Host.base64 },
    LrDialogs = { message = function(title, message) Host.dialogs[#Host.dialogs + 1] = { title, message } end },
    LrTasks = { pcall = pcall, execute = function(command)
        if Host.execute then return Host.execute(command) end
        local status = os.execute(command)
        return status == true and 0 or status
    end },
    LrPathUtils = {
        child = function(parent, child) return parent .. "/" .. child end,
        leafName = function(path) return path:match("[^/]+$") end,
        getStandardFilePath = function() return assert(os.getenv("LUMICODEX_TEST_TEMP")) end,
    },
    LrFileUtils = {
        readFile = function(path)
            if Host.readFile then return Host.readFile(path) end
            local file = io.open(path, "rb")
            if not file then return nil end
            local contents = file:read("*a"); file:close(); return contents
        end,
        delete = os.remove,
        createAllDirectories = function() end, -- fixture runner creates this directory
    },
}
function import(name) return assert(modules[name], name) end
package.path = "LumiCodex.lrplugin/?.lua;tests/?.lua;" .. package.path

function Host.context(settings, paths)
    local failed = {}
    return {
        propertyTable = settings,
        configureProgress = function() return { setPortionComplete = function() end } end,
        exportSession = { countRenditions = function() return #paths end },
        renditions = function()
            local i = 0
            return function()
                i = i + 1
                if i > #paths then return end
                local current = i
                return current, {
                    waitForRender = function() return true, paths[current] end,
                    uploadFailed = function(_, message) failed[current] = message end,
                }
            end
        end,
    }, failed
end
return Host
