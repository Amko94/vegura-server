function onKill(creature, target)
    if not creature:isPlayer() or not target:isMonster() then
        return true
    end

    local player = creature

    local activeTask = player:getActiveMonsterTask()
    if not activeTask then
        return true
    end

    local taskDef = getMonsterTaskDefinitionById(activeTask.taskId)
    if not taskDef then
        return true
    end

    local killedName = target:getName():lower()

    local matches = false
    for _, monster in ipairs(taskDef.monsters) do
        if monster.name:lower() == killedName then
            matches = true
            break
        end
    end

    if not matches then
        return true
    end

    local success = player:updateMonsterTaskProgress(activeTask.taskId, 1)
    if not success then
        return true
    end

    local updatedTask = player:getActiveMonsterTask()

    if not updatedTask then
        player:sendTextMessage(
                MESSAGE_EVENT_ADVANCE,
                "You have completed the task! Claim your reward!"
        )
        TaskManager.sendPlayerTasksToClient(player)
        return true
    end

    local remaining = updatedTask.amount - updatedTask.progress

    player:sendTextMessage(
            MESSAGE_STATUS_CONSOLE_ORANGE,
            string.format("[%s] %d monsters left to kill",
                    taskDef.name,
                    remaining
            )
    )

    TaskManager.sendPlayerTasksToClient(player)
    return true
end
