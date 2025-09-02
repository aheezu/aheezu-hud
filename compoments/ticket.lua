exports('Ticket', function()
	SendNUIMessage({
		action = 'ticket',
		id = ESX.serverId,
		ssn = LocalPlayer.state.ssn
	})
end)