package.path = "tests/?.lua;" .. package.path
local Host = require "TestHost"
package.config = "\\" -- simulate Windows command construction only
Host.execute = function(command)
    assert(command:match("^powershell.exe %-NoProfile %-NonInteractive %-EncodedCommand [A-Za-z0-9+/=]+$"))
    local file = assert(io.open(os.getenv("LUMICODEX_TEST_TEMP") .. "/windows-command.txt", "w"))
    file:write(command); file:close()
    return 0
end
Host.readFile = function(path)
    return path:match("%.json$") and '\239\187\191{"name":"Sélection 📷"}' or ""
end
local Command = require "LumiCodexCommand"
local result = Command.captureJson({
    apiKey = "fixture-'key-$&%",
    uploaderPath = [[C:\Users\L'été\lumicodex-upload.exe]],
}, { "albums", "create", "--name", [[Sélection "quoted" %PATH% $& 📷]] })
assert(result.name == "Sélection 📷", "PowerShell's BOM must not break JSON")
print("Windows command quoting and BOM tests passed (simulated host)")
