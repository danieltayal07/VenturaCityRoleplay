local cam = nil
local charPed = nil
local loadScreenCheckState = false
local QBCore = exports['qb-core']:GetCoreObject()
local cached_player_skins = {}
local currentCamAngle = "body" -- Default view

local randommodels = { 'mp_m_freemode_01', 'mp_f_freemode_01' }

-- Main Thread
CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            TriggerEvent('qb-multicharacter:client:chooseChar')
            return
        end
    end
end)

-- Functions
local function loadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
end

local function initializePedModel(model, data)
    CreateThread(function()
        if not model then model = joaat(randommodels[math.random(#randommodels)]) end
        loadModel(model)
        if charPed then DeleteEntity(charPed) end
        
        charPed = CreatePed(2, model, Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z - 0.98, Config.PedCoords.w, false, true)
        SetPedComponentVariation(charPed, 0, 0, 0, 2)
        FreezeEntityPosition(charPed, false)
        SetEntityInvincible(charPed, true)
        PlaceObjectOnGroundProperly(charPed)
        SetBlockingOfNonTemporaryEvents(charPed, true)
        
        if data then TriggerEvent('qb-clothing:client:loadPlayerClothing', data, charPed) end
        
        -- Default Animation
        RequestAnimDict("anim@heists@heist_corona@single_team")
        while not HasAnimDictLoaded("anim@heists@heist_corona@single_team") do Wait(0) end
        TaskPlayAnim(charPed, "anim@heists@heist_corona@single_team", "single_team_loop_boss", 2.0, 2.0, -1, 1, 0, false, false, false)

        -- Apply Camera Angle
        updateCameraAngle(currentCamAngle)
    end)
end

function updateCameraAngle(type)
    if not cam then return end
    currentCamAngle = type
    
    local targetCoords
    local fov = 60.0

    if type == "face" then
        -- FIX: Lowered Z from +0.6 to +0.15 to look directly at the face
        targetCoords = vector3(Config.CamCoords.x + 0.00, Config.CamCoords.y + 0.10, Config.CamCoords.z + 0.10)
        fov = 30.0
    elseif type == "wide" then
        targetCoords = vector3(Config.CamCoords.x - 1.0, Config.CamCoords.y - 1.0, Config.CamCoords.z + 1.0)
        fov = 80.0
    else -- "body" / default
        targetCoords = vector3(Config.CamCoords.x, Config.CamCoords.y, Config.CamCoords.z)
        fov = 60.0
    end
    
    -- Smooth Transition
    local newCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', targetCoords.x, targetCoords.y, targetCoords.z, 0.0, 0.0, Config.CamCoords.w, fov, false, 0)
    SetCamActiveWithInterp(newCam, cam, 1000, true, true)
    Wait(1000)
    DestroyCam(cam, true)
    cam = newCam
end

local function skyCam(bool)
    TriggerEvent('qb-weathersync:client:DisableSync')
    if bool then
        DoScreenFadeIn(1000)
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(1.0)
        FreezeEntityPosition(PlayerPedId(), false)
        
        -- Intro Cam
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', Config.CamCoords.x, Config.CamCoords.y, Config.CamCoords.z, 0.0, 0.0, Config.CamCoords.w, 60.00, false, 0)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 1, true, true)
    else
        SetTimecycleModifier('default')
        SetCamActive(cam, false)
        DestroyCam(cam, true)
        RenderScriptCams(false, false, 1, true, true)
        FreezeEntityPosition(PlayerPedId(), false)
        TriggerEvent('qb-weathersync:client:EnableSync')
    end
end

-- Helper to get Weather String
local function GetCurrentWeather()
    -- Tries to get QB weather, fallbacks to native
    local weather = "SUNNY"
    if GetPrevWeatherTypeHashName then 
        local wHash = GetPrevWeatherTypeHashName()
        if wHash == `EXTRASUNNY` then weather = "EXTRA SUNNY"
        elseif wHash == `CLEAR` then weather = "CLEAR"
        elseif wHash == `CLOUDS` then weather = "CLOUDY"
        elseif wHash == `RAIN` then weather = "RAINY"
        elseif wHash == `THUNDER` then weather = "STORM"
        else weather = "CLEAR" end
    end
    return weather
end

local function openCharMenu(bool)
    QBCore.Functions.TriggerCallback('qb-multicharacter:server:GetNumberOfCharacters', function(result, countries)
        SetNuiFocus(bool, bool)
        SendNUIMessage({
            action = 'ui',
            toggle = bool,
            nChar = result,
            enableDeleteButton = Config.EnableDeleteButton,
            countries = countries,
            -- FIX: Sending Real Data
            weather = GetCurrentWeather(),
            time = GetClockHours() .. ":" .. GetClockMinutes(),
            myId = GetPlayerServerId(PlayerId())
        })
        skyCam(bool)
        if not loadScreenCheckState then
            ShutdownLoadingScreenNui()
            loadScreenCheckState = true
        end
    end)
end

-- Events & Callbacks
RegisterNetEvent('qb-multicharacter:client:closeNUI', function() DeleteEntity(charPed) SetNuiFocus(false, false) end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    SetNuiFocus(false, false)
    DoScreenFadeOut(10)
    Wait(1000)
    local interior = GetInteriorAtCoords(Config.Interior.x, Config.Interior.y, Config.Interior.z - 18.9)
    LoadInterior(interior)
    while not IsInteriorReady(interior) do Wait(1000) end
    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityCoords(PlayerPedId(), Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z)
    Wait(1500)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    openCharMenu(true)
end)

RegisterNUICallback('closeUI', function(_, cb) openCharMenu(false) cb('ok') end)
RegisterNUICallback('selectCharacter', function(data, cb)
    local cData = data.cData
    DoScreenFadeOut(10)
    TriggerServerEvent('qb-multicharacter:server:loadUserData', cData)
    openCharMenu(false)
    SetEntityAsMissionEntity(charPed, true, true)
    DeleteEntity(charPed)
    cb('ok')
end)
RegisterNUICallback('cDataPed', function(nData, cb)
    local cData = nData.cData
    if cData ~= nil then
        if not cached_player_skins[cData.citizenid] then
            local temp_model = promise.new()
            local temp_data = promise.new()
            QBCore.Functions.TriggerCallback('qb-multicharacter:server:getSkin', function(model, data)
                temp_model:resolve(model)
                temp_data:resolve(data)
            end, cData.citizenid)
            local resolved_model = Citizen.Await(temp_model)
            local resolved_data = Citizen.Await(temp_data)
            cached_player_skins[cData.citizenid] = { model = resolved_model, data = resolved_data }
        end
        local model = cached_player_skins[cData.citizenid].model
        local data = cached_player_skins[cData.citizenid].data
        model = model ~= nil and tonumber(model) or false
        if model ~= nil then initializePedModel(model, json.decode(data)) else initializePedModel() end
        cb('ok')
    else initializePedModel() cb('ok') end
end)
RegisterNUICallback('setupCharacters', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-multicharacter:server:setupCharacters', function(result)
        cached_player_skins = {}
        SendNUIMessage({ action = 'setupCharacters', characters = result })
        cb('ok')
    end)
end)
RegisterNUICallback('removeBlur', function(_, cb) SetTimecycleModifier('default') cb('ok') end)
RegisterNUICallback('createNewCharacter', function(data, cb)
    local cData = data
    DoScreenFadeOut(150)
    cData.gender = (cData.gender == 'Male') and 0 or 1
    TriggerServerEvent('qb-multicharacter:server:createCharacter', cData)
    Wait(500)
    cb('ok')
end)
RegisterNUICallback('removeCharacter', function(data, cb)
    TriggerServerEvent('qb-multicharacter:server:deleteCharacter', data.citizenid)
    DeletePed(charPed)
    TriggerEvent('qb-multicharacter:client:chooseChar')
    cb('ok')
end)

-- CAMERA CALLBACK
RegisterNUICallback('changeCamera', function(data, cb)
    updateCameraAngle(data.type)
    cb('ok')
end)

-- OPEN URL CALLBACK (Links)
RegisterNUICallback('openUrl', function(data, cb)
    -- This allows JS to send a link to your browser
    SendNUIMessage({ action = 'openUrl_response', url = data.url })
    cb('ok')
end)