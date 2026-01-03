function onKill(creature, target)
    if not creature:isPlayer() then
        return true
    end

    local player = creature
    if not target:isMonster() then
        return true
    end

    local activeTasks = TaskManager.getActiveTasks(player)
    if #activeTasks == 0 then
        print("[TASK DEBUG] Keine aktiven Tasks für Spieler:", player:getName())
        return true
    end

    local killedName = target:getName():lower()
    local function sendProgressMessage(taskName, remaining)
        local message = string.format("[%s] Progress: %d monsters left to kill", taskName, remaining)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, message)
    end

    for _, activeTask in ipairs(activeTasks) do
        if activeTask.paused == 1 then
            print("[TASK DEBUG] Task ist pausiert, überspringen")
            goto continue
        end

        local taskDef = TaskManager.getTaskDefinitionById(activeTask.taskId)
        if not taskDef then
            goto continue
        end

        local monsterFound = false
        for _, monsterName in ipairs(taskDef.monsterNames) do
            if monsterName:lower() == killedName then
                monsterFound = true
                break
            end
        end

        if monsterFound then

            TaskManager.updateTaskProgress(player, activeTask.taskId, 1)

            local newProgress = activeTask.progress + 1
            local remaining = activeTask.amount - newProgress

            player:sendExtendedOpcode(1, "TASK_UPDATED;" .. activeTask.taskId .. ";" .. newProgress .. ";" .. activeTask.amount)

            if newProgress == activeTask.amount then
                player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have completed the task! Claim your reward!")
                TaskManager.updateMaxAmount(player, activeTask.taskId)
            end

            if newProgress <= activeTask.amount then
                sendProgressMessage(taskDef.taskName, remaining)
            end

            break
        end

        :: continue ::
    end

    return true
end