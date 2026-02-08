TaskManager = {}

function TaskManager.sendAvailableTaskList(player)
    if not player then
        return false
    end

    local playerId = player:getGuid()
    local fullList = getMonsterTaskDefinitionList()
    local taskPoints = player:getTaskPoints()

    if taskPoints then
        player:sendExtendedOpcode(TASK_MANAGER_EXTENDED_OPCODES.SEND_PLAYER_TASK_POINTS, playerId .. ";" .. taskPoints)
    end

    local CHUNK_SIZE = 25

    for i = 1, #fullList, CHUNK_SIZE do
        local chunk = {}
        for j = i, math.min(i + CHUNK_SIZE - 1, #fullList) do
            table.insert(chunk, fullList[j])
        end

        local payload = json.encode(chunk)
        player:sendExtendedOpcode(4, "TASKLIST_PART;" .. payload)

    end

    player:sendExtendedOpcode(4, "TASKLIST_COMPLETE")

    TaskManager.sendPlayerTasksToClient(player)

    return true
end

function TaskManager.claimReward(taskId, rewardType, player)
    if not player or not taskId then
        print("[TaskManager] Missing taskId or player")
        return false
    end

    if TaskManager.blockPz(player) then
        return false
    end

    local result = player:claimMonsterTaskReward(taskId, rewardType)

    if not result or result.success ~= true then
        if result and result.error == "task_not_found" then
            player:sendExtendedOpcode(
                    EXTENDED_ERROR_OPCODES.CLAIM_REWARD_ERROR_NOT_FOUND
            )
        elseif result and result.error == "not_finished" then
            player:sendExtendedOpcode(
                    EXTENDED_ERROR_OPCODES.CLAIM_REWARD_ERROR_NO_FINISHED
            )
            player:sendTextMessage(
                    MESSAGE_STATUS_WARNING,
                    "Your task is not finished yet"
            )
        else
            player:sendTextMessage(
                    MESSAGE_STATUS_WARNING,
                    "Failed to claim task reward."
            )
        end
        return false
    end

    if result.gold and result.gold > 0 then
        player:addMoney(result.gold)
    end

    if result.experience and result.experience > 0 then
        player:addExperience(result.experience, true)
    end

    local message = "You received: "
    local parts = {}

    if result.gold > 0 then
        table.insert(parts, result.gold .. " gold coins")
    end

    if result.experience > 0 then
        table.insert(parts, result.experience .. " experience")
    end

    table.insert(parts, result.taskPoints .. " task points")

    message = message .. table.concat(parts, ", ")

    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, message)
    player:sendExtendedOpcode(
            TASK_MANAGER_EXTENDED_OPCODES.CLAIM_REWARD_SUCCESS
    )

    TaskManager.sendPlayerTasksToClient(player)
    return true
end

function TaskManager.taskRewardRequest(taskId, player)
    if not taskId then
        print('Error no Taskid')
        return false
    end

    local reward = player:getPlayerMonsterTaskById(taskId)

    if not reward then
        print('ERROR: Could not get reward for task', taskId)
        return false
    end

    local rewardData = string.format("%d;%d;%d", reward.gold, reward.exp, reward.points)
    player:sendExtendedOpcode(TASK_MANAGER_EXTENDED_OPCODES.TASK_REWARD_REQUEST, rewardData)

    return true
end

function TaskManager.blockPz(player)
    if player:isPzLocked() or player:getCondition(CONDITION_INFIGHT, CONDITIONID_DEFAULT) then
        return true
    end

    return false
end

function TaskManager.startTask(player, taskId, amount)
    if not player or not taskId or amount == nil then
        return false
    end

    taskId = tonumber(taskId)
    amount = tonumber(amount)

    if taskId == 0 then
        return false
    end

    if TaskManager.blockPz(player) then
        return false
    end

    local success = player:startMonsterTask(taskId, amount)
    if not success then
        player:sendTextMessage(
                MESSAGE_STATUS_WARNING,
                "Could not start task."
        )
        return false
    end

    TaskManager.sendPlayerTasksToClient(player)
    return true
end

function TaskManager.updateTaskProgress(player, taskId, kills)
    if not player or not taskId then
        return false
    end

    kills = tonumber(kills) or 1

    local success = player:updateMonsterTaskProgress(taskId, kills)
    if not success then
        return false
    end

    TaskManager.sendPlayerTasksToClient(player)
    return true
end

function TaskManager.pauseTask(player, taskId)
    if not player or not taskId then
        return false
    end

    if TaskManager.blockPz(player) then
        return false
    end

    local success = player:pauseMonsterTask(taskId)
    if not success then
        return false
    end

    player:sendExtendedOpcode(TASK_MANAGER_EXTENDED_OPCODES.PAUSE_TASK_SUCCESS)
    TaskManager.sendPlayerTasksToClient(player)
    return true
end

function TaskManager.resumeTask(player, taskId)
    if not player or not taskId then
        return false
    end

    if TaskManager.blockPz(player) then
        return false
    end

    local success = player:resumeMonsterTask(taskId)
    if not success then
        player:sendExtendedOpcode(EXTENDED_ERROR_OPCODES.RESUME_ERROR)
        return false
    end

    player:sendExtendedOpcode(TASK_MANAGER_EXTENDED_OPCODES.RESUME_TASK)
    TaskManager.sendPlayerTasksToClient(player)
    return true
end

function TaskManager.cancelTask(player, taskId)
    if not player or not taskId then
        return false
    end

    if TaskManager.blockPz(player) then
        return false
    end

    local success = player:cancelMonsterTask(taskId)
    if success then
        TaskManager.sendPlayerTasksToClient(player)
    end

    return success
end

function TaskManager.sendPlayerTasksToClient(player)
    local tasks = player:getPlayerMonsterTasks()

    local jsonTasks = json.encode(tasks)
    player:sendExtendedOpcode(
            TASK_MANAGER_EXTENDED_OPCODES.SEND_TASKS,
            player:getGuid() .. ";" .. jsonTasks
    )
end


