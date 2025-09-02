ESX.RegisterServerCallback('westside-hud:server:getRadioPlayers', function(source, cb, channel)

    local success, result = pcall(function()
        local playersInPma = exports['pma-voice']:getPlayersInRadioChannel(Player(source).state['radioChannel'])
        local playerList = {}

        if not playersInPma then
            return {}
        end

        for player, isTalking in pairs(playersInPma) do
            if GetPlayerName(player) then
                local playerData = {
                    name = GetRPName(player),
                    isTalking = isTalking,
                    badge = GetPlayerBadge(player)
                }
                table.insert(playerList, playerData)
            end
        end
        return playerList
    end)

    if not success then
        cb({})
        return
    end
    
    cb(result)
end)


function GetRPName(player)
    local xPlayer = ESX.GetPlayerFromId(player)
    if not xPlayer then return "Błąd Nazwy" end
    local fname = xPlayer.get('firstName')
    local sname = xPlayer.get('lastName')
    if not fname or not sname or fname == '' or sname == '' then
        return xPlayer.getName()
    end
    return string.upper(string.sub(fname, 1, 1)) .. '. ' .. sname
end


function GetPlayerBadge(player)
    local xPlayer = ESX.GetPlayerFromId(player)
    if not xPlayer then 
		return "ERR" 
	end
	
	if not xPlayer.badge or not Player(xPlayer.source).state.badge then
		return '???'
	else
		return xPlayer.badge or Player(xPlayer.source).state.badge
	end
end