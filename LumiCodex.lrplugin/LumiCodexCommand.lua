local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrStringUtils = import "LrStringUtils"
local LrTasks = import "LrTasks"

local Json = require "Json"
local Command = {}

local isWindows = package.config:sub(1, 1) == "\\"

local function rejectControl(value, label)
    if value:find("[\r\n%z]") then error(label .. " contains an unsupported control character") end
    return value
end

local function unixQuote(value)
    value = rejectControl(tostring(value), "command argument")
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function powershellValue(value)
    value = rejectControl(tostring(value), "command argument")
    -- Keep user data out of cmd.exe's parsing of quotes, %, &, and Unicode.
    return "([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" ..
        LrStringUtils.encodeBase64(value) .. "')))"
end

local function readAndDelete(path)
    local contents = LrFileUtils.readFile(path) or ""
    LrFileUtils.delete(path)
    -- Windows PowerShell's UTF-8 redirection includes a BOM.
    return contents:gsub("^\239\187\191", "")
end

function Command.execute(settings, arguments)
    local apiKey = rejectControl(settings.apiKey or "", "API key")
    local executable = rejectControl(settings.uploaderPath or "", "uploader path")
    if executable == "" then error("Choose the lumicodex-upload executable first.") end

    local token = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
    local temp = LrPathUtils.getStandardFilePath("temp")
    local stdoutPath = LrPathUtils.child(temp, "lumicodex-" .. token .. ".json")
    local stderrPath = LrPathUtils.child(temp, "lumicodex-" .. token .. ".err")
    local command

    if isWindows then
        local parts = {
            "$ErrorActionPreference='Continue';",
            "$PSDefaultParameterValues['Out-File:Encoding']='utf8';",
            "[Console]::OutputEncoding=New-Object Text.UTF8Encoding;",
        }
        if apiKey ~= "" then
            parts[#parts + 1] = "$env:LUMICODEX_API_KEY=" .. powershellValue(apiKey) .. ";"
        end
        parts[#parts + 1] = "&"
        parts[#parts + 1] = powershellValue(executable)
        for _, argument in ipairs(arguments) do parts[#parts + 1] = powershellValue(argument) end
        parts[#parts + 1] = "1>" .. powershellValue(stdoutPath)
        parts[#parts + 1] = "2>" .. powershellValue(stderrPath)
        parts[#parts + 1] = "; exit $LASTEXITCODE"
        local script = table.concat(parts, " ")
        -- The script is ASCII; EncodedCommand requires UTF-16LE.
        command = "powershell.exe -NoProfile -NonInteractive -EncodedCommand " ..
            LrStringUtils.encodeBase64((script:gsub(".", "%0\0")))
    else
        local parts = { "/usr/bin/env" }
        if apiKey ~= "" then parts[#parts + 1] = "LUMICODEX_API_KEY=" .. unixQuote(apiKey) end
        parts[#parts + 1] = unixQuote(executable)
        for _, argument in ipairs(arguments) do parts[#parts + 1] = unixQuote(argument) end
        parts[#parts + 1] = "1>" .. unixQuote(stdoutPath)
        parts[#parts + 1] = "2>" .. unixQuote(stderrPath)
        command = table.concat(parts, " ")
    end

    local executed, status = LrTasks.pcall(function() return LrTasks.execute(command) end)
    local stdout = readAndDelete(stdoutPath)
    local stderr = readAndDelete(stderrPath)
    if not executed then error(status) end
    if status ~= 0 then
        local detail = stderr ~= "" and stderr or stdout
        error(detail ~= "" and detail or ("lumicodex-upload exited with status " .. tostring(status)))
    end
    return stdout
end

function Command.captureJson(settings, arguments)
    local stdout = Command.execute(settings, arguments)
    if stdout == "" then error("lumicodex-upload returned no JSON output") end
    return Json.decode(stdout)
end

function Command.accountArguments(propertyTable, command)
    local arguments = command
    if propertyTable.LC_apiUrl and propertyTable.LC_apiUrl ~= "" then
        arguments[#arguments + 1] = "--api-url"
        arguments[#arguments + 1] = propertyTable.LC_apiUrl
    end
    if propertyTable.LC_accountId and propertyTable.LC_accountId ~= "" then
        arguments[#arguments + 1] = "--account"
        arguments[#arguments + 1] = propertyTable.LC_accountId
    end
    return arguments
end

return Command
