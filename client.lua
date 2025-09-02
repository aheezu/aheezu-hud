local HUD = {
	Vehicle = false,
	Settings = false,
	Pause = false,
	Texture = 'map',
	PhoneOpen = false 
}

local function radarFunc(bool)
	SendNUIMessage({ action = 'updateVehicle', inVehicle = bool })
	DisplayRadar(bool)
	HUD.Vehicle = bool
end	

CreateThread(function()
	radarFunc(false)
	
	RequestStreamedTextureDict(HUD.Texture, false)
	while not HasStreamedTextureDictLoaded(HUD.Texture) do
		Wait(100)
	end
	AddReplaceTexture("platform:/textures/graphics", "radarmasksm", HUD.Texture, "radarmasksm")
	SetBlipAlpha(GetNorthRadarBlip(), 0)
	SetRadarZoom(1100)
	
	Wait(1000)
	SendNUIMessage({
		action = 'ticket',
		id = ESX.serverId,
		ssn = 1
	})	
end)

local function GetDistanceToWaypoint()
    if IsWaypointActive() then
        local waypointBlip = GetFirstBlipInfoId(8)
        if waypointBlip ~= 0 then
            local waypoint = GetBlipCoords(waypointBlip)
            local coords = GetEntityCoords(PlayerPedId())
            if waypoint and coords then
                local distance = #(coords - waypoint)
				return string.format("%.2f km", distance / 1000.0)
            end
        end
    end
    return ""
end

local function IsStreetCustom(coordX, coordY, rectStartX, rectStartY, rectEndX, rectEndY)
    local minX = math.min(rectStartX, rectEndX)
    local maxX = math.max(rectStartX, rectEndX)
    local minY = math.min(rectStartY, rectEndY)
    local maxY = math.max(rectStartY, rectEndY)

    return coordX >= minX and coordX <= maxX and coordY >= minY and coordY <= maxY
end

local function GetStreetAndDirection()
	local coords = GetEntityCoords(ESX.PlayerData.ped)
	local streetName = ''
	local subStreetName = ''

    if Config.CustomStreets then
        for _, streetDef in ipairs(Config.CustomStreets) do
            if IsStreetCustom(coords.x, coords.y, streetDef.start_x, streetDef.start_y, streetDef.end_x, streetDef.end_y) then
                streetName = streetDef.name
                break
            end
        end
    end

    if streetName == '' then
        local zone = GetNameOfZone(coords.x, coords.y, coords.z)
        streetName = (Config.Zones and Config.Zones[zone]) or zone

        local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z, nil) 
        subStreetName = GetStreetNameFromHashKey(streetHash)

        if streetName == subStreetName then subStreetName = '' end
    end

    local heading = GetEntityHeading(ESX.PlayerData.ped)
    local direction = 'N'

	if (heading >= 22.5 and heading < 67.5) then
		direction = 'NE'
	elseif (heading >= 67.5 and heading < 112.5) then
		direction = 'E'
	elseif (heading >= 112.5 and heading < 157.5) then
		direction = 'SE'
	elseif (heading >= 157.5 and heading < 202.5) then
		direction = 'S'
	elseif (heading >= 202.5 and heading < 247.5) then
		direction = 'SW'
	elseif (heading >= 247.5 and heading < 292.5) then
		direction = 'W'
	elseif (heading >= 292.5 and heading < 337.5) then
		direction = 'NW'
	else
		direction = 'N'
	end

	return streetName, subStreetName, direction
end


RegisterNetEvent('WestSideHud:onStatusUpdate', function(status)
	for i = 1, #status, 1 do
		if status[i].name == 'hunger' then SendNUIMessage({ action = 'update', status = 'hunger', value = status[i].percent })
		elseif status[i].name == 'thirst' then SendNUIMessage({ action = 'update', status = 'thirst', value = status[i].percent }) end
	end
end)

RegisterNetEvent("lb-phone:phoneToggled", function(open)
    HUD.PhoneOpen = open
end)


CreateThread(function()
    while true do
        Wait(250)

        local isPaused = IsPauseMenuActive()
        if isPaused ~= HUD.Pause then
            HUD.Pause = isPaused
            if isPaused then
                SendNUIMessage({ action = 'hide' }) 
            else
                SendNUIMessage({ action = 'show' }) 
            end
        end

        if ESX.IsPlayerLoaded() and not HUD.Pause then
            local veh = GetVehiclePedIsIn(ESX.PlayerData.ped, false)
            local inVehicle = (veh ~= 0)
            
            local street, subStreet, direction = GetStreetAndDirection()
            local distance = GetDistanceToWaypoint()

            local data = {
                action = 'updateHudState', 
                inVehicle = inVehicle,
                phoneOpen = HUD.PhoneOpen,
                streetName = street,
                subStreetName = subStreet,
                direction = direction,
                distance = distance,
                health = (GetEntityHealth(ESX.PlayerData.ped) - 100),
                armor = GetPedArmour(ESX.PlayerData.ped),
                voice = LocalPlayer.state.proximity and ({[1.0] = 25, [2.0] = 50, [3.0] = 100})[LocalPlayer.state.proximity.index] or 25,
                isTalking = NetworkIsPlayerTalking(PlayerId())
            }

            if inVehicle then
                data.speed = GetEntitySpeed(veh) * 3.6
                data.fuel = GetVehicleFuelLevel(veh)
            end
            
            SendNUIMessage(data)

            DisplayRadar(inVehicle or HUD.PhoneOpen)
        end
    end
end)


local function radarFunc(bool)
    SendNUIMessage({ action = 'updateVehicle', inVehicle = bool })
    DisplayRadar(bool)
    HUD.Vehicle = bool
end

---------------------------------------------------

exports('Hide', function(hide)
	if hide then
		SendNUIMessage({ action = 'hide' }) 
	else
		SendNUIMessage({ action = 'show' }) 
	end
end)

---------------------------------------------------

RegisterCommand('ustawienia', function()
    HUD.Settings = not HUD.Settings
    SetNuiFocus(HUD.Settings, HUD.Settings)
    SendNUIMessage({ action = 'toggleSettings', state = HUD.Settings })
end, false)

RegisterNUICallback('closeSettings', function(data, cb)
    HUD.Settings = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'toggleSettings', state = false })
    cb('ok')
end)

CreateThread(function()
    local sleep = 1000
    while true do
        local rebuildPosition = IsPedInAnyVehicle(PlayerPedId(), false) or HUD.PhoneOpen
        local channel = exports['pma-voice']:GetRadioChannel()

        if channel == 0 then
            sleep = 1000
            SendNUIMessage({
                action = 'showRadioList',
                show = false,
                inVehicle = rebuildPosition
            })
        else
            sleep = 250 
            ESX.TriggerServerCallback('westside-hud:server:getRadioPlayers', function(playersInRadio)
                if playersInRadio then
                    local CHNAME = Config.Channels[channel] or ("Channel "..channel)

                    SendNUIMessage({
                        action = 'showRadioList',
                        show = true,
                        channel = CHNAME,
                        count = #playersInRadio,
                        players = playersInRadio,
                        inVehicle = rebuildPosition
                    })
                else
                    SendNUIMessage({
                        action = 'showRadioList',
                        show = false,
                        inVehicle = rebuildPosition
                    })
                end
            end, channel) 
        end

        Wait(sleep)
    end
end)
