CreateThread(function()
    Wait(2000)

    local resource = GetCurrentResourceName()
    local currentVersion = GetResourceMetadata(resource, "version", 0)

    if not currentVersion then
        return
    end

    PerformHttpRequest("https://raw.githubusercontent.com/Dreamlexxi/lx_sundhed/main/version", function(status, latestVersion)
        if status ~= 200 or not latestVersion then
            return
        end

        latestVersion = latestVersion:gsub("%s+", "")

        if latestVersion > currentVersion then
            print(("^3--------------------------------------------------^7"))
            print((string.format("^3[%s]^7 En ny version er tilgængelig: ^2v%s^7 (Nuværende: ^1v%s^7)", resource, latestVersion, currentVersion)))
            print(("^3Hent den nyeste opdatering: ^4https://github.com/Dreamlexxi/lx_sundhed^7"))
            print(("^3--------------------------------------------------^7"))
        end
    end, "GET")
end)
