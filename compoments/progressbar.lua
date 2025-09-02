local isDoingAction = false
local currentAction = {}

local function cleanup(wasCancelled)
    if not isDoingAction then return end

    local onFinish = currentAction.onFinish

    ClearPedTasks(PlayerPedId())

    if currentAction.propObject then
        DeleteEntity(currentAction.propObject)
    end

    isDoingAction = false
    currentAction = {}

    SendNUIMessage({ action = "progressCancel" })

    if onFinish then
        onFinish(wasCancelled)
    end
end

local function startProgress(data, onFinishCallback)
    if isDoingAction then
        ESX.ShowNotification("Już wykonujesz inną akcję")
        if onFinishCallback then onFinishCallback(true) end
        return
    end

    isDoingAction = true
    currentAction = data
    currentAction.onFinish = onFinishCallback

    if data.prop then
        lib.requestModel(data.prop.model)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        currentAction.propObject = CreateObject(data.prop.model, coords.x, coords.y, coords.z, true, false, false)
        AttachEntityToEntity(currentAction.propObject, ped, GetPedBoneIndex(ped, data.prop.bone or 60309), data.prop.pos.x, data.prop.pos.y, data.prop.pos.z, data.prop.rot.x, data.prop.rot.y, data.prop.rot.z, true, true, false, true, data.prop.rotOrder or 0, true)
        SetModelAsNoLongerNeeded(data.prop.model)
    end

    if data.anim then
        local ped = PlayerPedId()
        if data.anim.task then
            TaskStartScenarioInPlace(ped, data.anim.task, 0, true)
        elseif data.anim.dict and data.anim.clip then
            lib.requestAnimDict(data.anim.dict)
            TaskPlayAnim(ped, data.anim.dict, data.anim.clip, 3.0, 1.0, data.duration, data.anim.flags or 49, 0, false, false, false)
        end
    end

    SendNUIMessage({
        action = "showProgress",
        data = {
            duration = data.duration,
            label = data.label,
            show = true
        }
    })

    CreateThread(function()
        local startTime = GetGameTimer()
        while isDoingAction and currentAction.label == data.label do 
            Wait(0)

            if GetGameTimer() - startTime >= data.duration then
                cleanup(false) 
                break
            end

            if data.canCancel and IsControlJustPressed(0, 73) then -- X
                cleanup(true) 
                break
            end

            if data.disable then
                if data.disable.move then DisableControlAction(0, 30, true); DisableControlAction(0, 31, true) end
                if data.disable.car then DisableControlAction(0, 71, true); DisableControlAction(0, 72, true) end
                if data.disable.combat then DisablePlayerFiring(PlayerId(), true); DisableControlAction(1, 37, true) end
            end
        end
    end)
end

RegisterNUICallback('actionFinish', function(data, cb)
    if cb then cb('ok') end
end)



exports('Progress', function(actionData, onFinish)
    local data = {
        duration = actionData.duration or 5000,
        label = actionData.label or 'Wykonywanie akcji...',
        canCancel = actionData.canCancel ~= nil and actionData.canCancel or true,
        disable = actionData.disable or actionData.controlDisables,
        anim = actionData.anim or actionData.animation,
        prop = actionData.prop
    }
    startProgress(data, onFinish)
end)


exports('isProgressActive', function()
    return isDoingAction
end)

exports('cancelProgress', function()
    if isDoingAction and currentAction.canCancel then
        cleanup(true)
    end
end)


