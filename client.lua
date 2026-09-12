local identifier = "sundhed"
local resourceName = GetCurrentResourceName()

local function getTodayDate()
    local year = GetClockYear()
    local month = GetClockMonth() + 1
    local day = GetClockDayOfMonth()
    return string.format("%04d-%02d-%02d", year, month, day)
end

local STEP_LENGTH = 0.75
local MAX_TELEPORT_DIST = 15.0

local data = {
    date = getTodayDate(),
    awakeSeconds = 0,
    steps = 0,
    carMeters = 0.0,
    heartRate = 70,
    stepGoal = 10000
}

local function loadData()
    local raw = GetResourceKvpString("sundhed_data")
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == "table" then
            if decoded.date == getTodayDate() then
                data.date = decoded.date
                data.awakeSeconds = decoded.awakeSeconds or 0
                data.steps = decoded.steps or 0
                data.carMeters = decoded.carMeters or 0.0
                data.heartRate = decoded.heartRate or 70
            end
            data.stepGoal = decoded.stepGoal or data.stepGoal
        end
    end
end

local function saveData()
    SetResourceKvp("sundhed_data", json.encode(data))
end

loadData()

local function addApp()
    if GetResourceState("lb-phone") ~= "started" then return end

    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = identifier,
        name = "Sundhed",
        description = "Hold styr på dine skridt, kørsel i bil, vågen-tid og puls",
        developer = "Lexxi",
        defaultApp = true,
        size = 42112,
        ui = resourceName .. "/ui/index.html",
        icon = "https://cfx-nui-" .. resourceName .. "/ui/assets/icon.svg",
        fixBlur = true
    })

    if not added then
        print(string.format("[%s] Kunne ikke tilføje app: %s", resourceName, tostring(errorMessage)))
    end
end

CreateThread(function()
    while GetResourceState("lb-phone") ~= "started" do
        Wait(500)
    end
    Wait(500)
    addApp()
end)

AddEventHandler("onResourceStart", function(resource)
    if resource == "lb-phone" then
        addApp()
    end
end)

RegisterNUICallback("getData", function(_, cb)
    cb(data)
end)

RegisterNUICallback("setStepGoal", function(body, cb)
    local goal = tonumber(body and body.goal)
    if goal and goal >= 500 and goal <= 100000 then
        data.stepGoal = math.floor(goal)
        saveData()
    end
    cb(data)
end)

RegisterNUICallback("resetData", function(_, cb)
    data.steps = 0
    data.carMeters = 0.0
    data.awakeSeconds = 0
    data.heartRate = 70
    saveData()
    cb(data)
end)

local currentHeartRate = data.heartRate or 70

local function updateHeartRate(speed, inVehicle, ped)
    local target = 70

    if IsPedShooting(ped) or (IsPedInMeleeCombat and IsPedInMeleeCombat(ped)) then
        target = 145
    elseif inVehicle then
        target = 75 + math.min(speed * 1.3, 30)
    else
        if speed > 4.5 then
            target = 135
        elseif speed > 2.0 then
            target = 100
        elseif speed > 0.3 then
            target = 82
        else
            target = 70
        end
    end

    currentHeartRate = currentHeartRate + (target - currentHeartRate) * 0.12
    local jitter = math.random(-1, 1)

    return math.max(45, math.floor(currentHeartRate + jitter))
end

local isAppOpen = false

RegisterNUICallback("appOpened", function(_, cb)
    isAppOpen = true
    cb(true)
end)

RegisterNUICallback("appClosed", function(_, cb)
    isAppOpen = false
    cb(true)
end)

local function pushUpdate()
    if not isAppOpen then
        local phoneOpen = false
        pcall(function()
            phoneOpen = exports["lb-phone"]:IsOpen()
        end)
        if not phoneOpen then
            return
        end
    end

    exports["lb-phone"]:SendCustomAppMessage(identifier, {
        type = "update",
        data = data
    })
end

CreateThread(function()
    local lastCoords = nil
    local saveTick = 0

    while true do
        Wait(1000)

        local today = getTodayDate()
        if data.date ~= today then
            data.date = today
            data.steps = 0
            data.carMeters = 0.0
            data.awakeSeconds = 0
        end

        data.awakeSeconds = data.awakeSeconds + 1

        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local inVehicle = IsPedInAnyVehicle(ped, false)
            local speed = GetEntitySpeed(ped)

            if lastCoords then
                local dist = #(coords - lastCoords)

                if dist < MAX_TELEPORT_DIST then
                    if inVehicle then
                        data.carMeters = data.carMeters + dist
                    elseif speed > 0.15 then
                        data.steps = data.steps + math.floor(dist / STEP_LENGTH)
                    end
                end
            end
            lastCoords = coords

            data.heartRate = updateHeartRate(speed, inVehicle, ped)
        end

        pushUpdate()

        saveTick = saveTick + 1
        if saveTick >= 30 then
            saveTick = 0
            saveData()
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == resourceName then
        saveData()
    end
end)
