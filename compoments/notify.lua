exports('Notify', function(text, duration, typeof)
	if type(duration) ~= 'number' or duration == 0 then
		duration = 5000
	end

    SendNUIMessage({
        action = 'showNotify',
        text = text or 'Błędna konfiguracja! Powiadom o błędzie na odpowiednim kanale wraz z informacją podczas jakiej czynności ta notyfikacja wystąpiła',
        duration = duration,
        type = (typeof or 'info')
    })
end)
