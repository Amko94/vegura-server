TaskManager = {}

local CACHE_DURATION = 300000

function TaskManager.getAllTaskMonsters()
    local resultId = db.storeQuery("SELECT * FROM TaskDefinitions")
    if not resultId then
        return {}
    end

    local fullList = {}
    repeat
        local monsterNamesJson = result.getString(resultId, "MonsterNames")
        local lookTypeIdsJson = result.getString(resultId, "LookTypeIds")

        local monsterNames = parseJsonArray(monsterNamesJson, true)
        local lookTypeIds = parseJsonArray(lookTypeIdsJson, false)

        local task = {
            id = result.getNumber(resultId, "Id"),
            taskName = result.getString(resultId, "TaskName"),
            monsterNames = monsterNames,
            lookTypeIds = lookTypeIds,
            category = result.getNumber(resultId, "Category"),
            experience = result.getNumber(resultId, "Experience")
        }
        table.insert(fullList, task)
    until not result.next(resultId)
    result.free(resultId)

    return fullList
end

function parseJsonArray(jsonStr, isStringArray)
    local result = {}
    if not jsonStr or jsonStr == "" or jsonStr == "[]" then
        return result
    end

    jsonStr = jsonStr:gsub("%[", ""):gsub("%]", "")

    for item in jsonStr:gmatch('[^,]+') do
        item = item:match("^%s*(.-)%s*$")

        if isStringArray then
            item = item:gsub('"', "")
            if item ~= "" then
                table.insert(result, item)
            end
        else
            item = tonumber(item)
            if item then
                table.insert(result, item)
            end
        end
    end

    return result
end

function TaskManager.sendAvailableTaskList(player)
    if not player then
        return false
    end

    local playerId = player:getGuid()
    local fullList = TaskManager.getAllTaskMonsters()
    local taskPoints = TaskManager.getPlayerTaskPoints(player)

    if taskPoints then
        player:sendExtendedOpcode(EXTENDED_OPCODES.SEND_PLAYER_TASK_POINTS, playerId .. ";" .. taskPoints)
    end

    print(taskPoints, 'TASKPOINTS')

    local CHUNK_SIZE = 25

    local totalChunks = math.ceil(#fullList / CHUNK_SIZE)

    for i = 1, #fullList, CHUNK_SIZE do
        local chunk = {}
        for j = i, math.min(i + CHUNK_SIZE - 1, #fullList) do
            table.insert(chunk, fullList[j])
        end

        local payload = json.encode(chunk)
        player:sendExtendedOpcode(4, "TASKLIST_PART;" .. payload)

        print("[TaskManager] Chunk " .. math.ceil(i / CHUNK_SIZE) .. "/" .. totalChunks .. " sent (" .. #chunk .. " tasks)")
    end

    player:sendExtendedOpcode(4, "TASKLIST_COMPLETE")
    print("[TaskManager] All tasks sent - Total: " .. #fullList)

    TaskManager.sendTasksToClient(player)

    return true
end

function TaskManager.checkPlayerHasActiveTask(player)
    local resultId = db.storeQuery(string.format("SELECT Id FROM PlayerTasks WHERE PlayerId = %d AND Paused = 0 AND Active = 1", player:getGuid()))

    if resultId ~= false then
        player:sendTextMessage(MESSAGE_STATUS_WARNING, "Start task failed. You already have an active task.")
        result.free(resultId)
        return true
    end
end

function TaskManager.getPlayerTaskById(playerTaskId)
    local resultId = db.storeQuery(string.format(
            "SELECT * FROM PlayerTasks WHERE Id = %d",
            playerTaskId
    ))

    if not resultId then
        print('ERROR, NO task found', playerTaskId)
        result.free(resultId)
        return false
    end

    local gold = result.getNumber(resultId, "Reward_Gold")
    local exp = result.getNumber(resultId, "Reward_Experience")
    local points = result.getNumber(resultId, "Reward_TaskPoints")
    local finished = result.getNumber(resultId, "Finished")
    local taskId = result.getNumber(resultId, "TaskId")
    local amount = result.getNumber(resultId, "Amount")

    result.free(resultId)

    return {
        gold = gold,
        exp = exp,
        points = points,
        finished = finished,
        taskId = taskId,
        amount = amount
    }
end

function TaskManager.claimReward(playerTaskId, rewardType, player)
    if not playerTaskId then
        print('Error no Taskid')
        return false
    end

    local hasPz = TaskManager.blockPz(player)

    if hasPz then
        return false
    end

    local reward = TaskManager.getPlayerTaskById(playerTaskId)

    if not reward then
        player:sendExtendedOpcode(EXTENDED_ERROR_OPCODES.CLAIM_REWARD_ERROR_NOT_FOUND)
        return false
    end

    if reward.finished == 0 then
        player:sendExtendedOpcode(EXTENDED_ERROR_OPCODES.CLAIM_REWARD_ERROR_NO_FINISHED)
        player:sendTextMessage(MESSAGE_STATUS_WARNING, "Your task is not finished yet")
        return false
    end

    local gold = 0
    local exp = 0
    local points = reward.points

    if rewardType == "gold" then
        gold = reward.gold
        exp = 0
    elseif rewardType == "exp" then
        gold = 0
        exp = reward.exp
    elseif rewardType == "split" then
        gold = math.floor(reward.gold / 2)
        exp = math.floor(reward.exp / 2)
    end

    player:addMoney(gold)
    player:addExperience(exp, true)

    local rewardTypeMap = {
        gold = 1,
        exp = 2,
        split = 3
    }

    db.query(string.format("UPDATE Players SET TaskPoints = TaskPoints + %d WHERE id = %d", points, player:getGuid()))

    db.query(string.format(
            "INSERT INTO playertaskhistories (PlayerId, TaskId, RewardType, Gold, Experience, TaskPoints, KillsCompleted, CreatedAt) VALUES (%d, %d, '%s', %d, %d, %d, %d, NOW())",
            player:getGuid(),
            reward.taskId,
            rewardTypeMap[rewardType],
            gold,
            exp,
            points,
            reward.amount
    ))

    db.query(string.format("DELETE FROM PlayerTasks WHERE Id = %d", playerTaskId))

    local message = "You received: "
    if rewardType == "gold" then
        message = message .. gold .. " gold coins"
    elseif rewardType == "exp" then
        message = message .. exp .. " experience"
    elseif rewardType == "split" then
        message = message .. gold .. " gold coins and " .. exp .. " experience"
    end
    message = message .. " and " .. points .. " task points"

    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, message)
    player:sendExtendedOpcode(EXTENDED_OPCODES.CLAIM_REWARD_SUCCESS)
    TaskManager.sendTasksToClient(player)

    return true
end

function TaskManager.taskRewardRequest(playerTaskId, player)
    if not playerTaskId then
        print('Error no Taskid')
        return false
    end

    local reward = TaskManager.getPlayerTaskById(playerTaskId)

    if not reward then
        print('ERROR: Could not get reward for task', playerTaskId)
        return false
    end

    local rewardData = string.format("%d;%d;%d", reward.gold, reward.exp, reward.points)
    player:sendExtendedOpcode(EXTENDED_OPCODES.TASK_REWARD_REQUEST, rewardData)

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
        print("[TaskManager] Missing Data: TaskId:", taskId, "Amount:", amount)
        return false
    end

    taskId = tonumber(taskId)
    amount = tonumber(amount)

    if taskId == 0 then
        print("[TaskManager] ERROR: TaskId must be provided!")
        return false
    end

    local hasPz = TaskManager.blockPz(player)

    if hasPz then
        return false
    end

    local hasActiveTask = TaskManager.checkPlayerHasActiveTask(player)

    if hasActiveTask then
        return false
    end

    if amount < 50 or amount > 1000 then
        player:sendTextMessage(MESSAGE_STATUS_WARNING, "Task amount must be between 50 and 1000.")
        return false
    end

    local taskDef = TaskManager.getTaskDefinitionById(taskId)

    if not taskDef then
        print("[TaskManager] ERROR: Task definition not found for ID:", taskId)
        player:sendTextMessage(MESSAGE_STATUS_WARNING, "Task not found!")
        return false
    end

    local totalGold = TaskManager.calculateGoldReward(amount, taskDef.experience, taskDef.category)
    local totalExp = TaskManager.calculateExperienceReward(amount, taskDef.experience)
    local totalTaskPoints = TaskManager.calculateTaskPointsReward(amount, taskDef.experience, taskDef.category)

    local success = db.query(string.format(
            "INSERT INTO PlayerTasks (PlayerId, TaskId, Amount, Progress, Paused, Finished, Active, StartTime, EndTime, Reward_Experience, Reward_Gold, Reward_TaskPoints) VALUES (%d, %d, %d, 0, 0, 0, 1, NOW(), NULL, %d, %d, %d)",
            player:getGuid(),
            taskId,
            amount,
            totalExp,
            totalGold,
            totalTaskPoints
    ))

    if success then
        print("[TaskManager] Task started with TaskId:", taskId)
        TaskManager.sendTasksToClient(player)
        return true
    else
        print("[TaskManager] ERROR: Failed to insert task!")
        return false
    end
end

function TaskManager.updateTaskProgress(player, taskId, kills)
    if not player or not taskId then
        return false
    end

    local resultId = db.storeQuery(string.format(
            "SELECT Id, Progress, Amount FROM PlayerTasks WHERE PlayerId = %d AND TaskId = %d AND Finished = 0",
            player:getGuid(), taskId))
    if not resultId then
        return false
    end

    local playerTaskId = result.getNumber(resultId, "Id")
    local currentProgress = result.getNumber(resultId, "Progress")
    local amount = result.getNumber(resultId, "Amount")
    result.free(resultId)

    local newProgress = currentProgress + (kills or 1)

    if newProgress >= amount then
        db.query(string.format("UPDATE PlayerTasks SET Progress = %d, Finished = 1, EndTime = NOW() WHERE Id = %d", newProgress, playerTaskId))
    else
        db.query(string.format("UPDATE PlayerTasks SET Progress = %d WHERE Id = %d", newProgress, playerTaskId))
    end

    TaskManager.sendTasksToClient(player)
    return true
end

function TaskManager.pauseTask(player, taskId)
    if not player or not taskId then
        return false
    end

    local hasPz = TaskManager.blockPz(player)

    if hasPz then
        return false
    end

    local resultId = db.storeQuery(string.format(
            "SELECT Id, Finished FROM PlayerTasks WHERE PlayerId = %d AND TaskId = %d AND Active = 1 AND Paused = 0",
            player:getGuid(), taskId))
    if not resultId then
        return false
    end

    local playerTaskId = result.getNumber(resultId, "Id")
    local finished = result.getNumber(resultId, "Finished")
    result.free(resultId)

    if finished == 1 then
        player:sendTextMessage(MESSAGE_STATUS_WARNING, "You cannot paused a completed task.")
        return false
    end

    db.query(string.format("UPDATE PlayerTasks SET Paused = 1 WHERE Id = %d", playerTaskId))
    player:sendExtendedOpcode(EXTENDED_OPCODES.PAUSE_TASK_SUCCESS)
    TaskManager.sendTasksToClient(player)
    return true
end

function TaskManager.resumeTask(player, taskId)
    if not player or not taskId then
        return false
    end

    local hasPz = TaskManager.blockPz(player)

    if hasPz then
        return false
    end

    local haveActiveTask = TaskManager.checkPlayerHasActiveTask(player)

    if haveActiveTask == true then
        player:sendExtendedOpcode(EXTENDED_ERROR_OPCODES.RESUME_ERROR)
        return false
    end

    local resultId = db.storeQuery(string.format(
            "SELECT Id FROM PlayerTasks WHERE PlayerId = %d AND TaskId = %d AND Finished = 0 AND Paused = 1",
            player:getGuid(), taskId))
    if not resultId then
        return false
    end

    local playerTaskId = result.getNumber(resultId, "Id")
    result.free(resultId)

    db.query(string.format("UPDATE PlayerTasks SET Paused = 0 WHERE Id = %d", playerTaskId))
    player:sendExtendedOpcode(EXTENDED_OPCODES.RESUME_TASK)
    TaskManager.sendTasksToClient(player)
    return true
end

function TaskManager.cancelTask(player, taskId)
    if not player or not taskId then
        return false
    end

    local hasPz = TaskManager.blockPz(player)

    if hasPz then
        return false
    end

    local success = db.query(string.format(
            "DELETE FROM PlayerTasks WHERE PlayerId = %d AND TaskId = %d",
            player:getGuid(), taskId))

    if success then
        TaskManager.sendTasksToClient(player)
    end

    return success
end

function TaskManager.getActiveTasks(player)
    if not player then
        return {}
    end

    local resultId = db.storeQuery(string.format("SELECT * FROM PlayerTasks WHERE PlayerId = %d AND Active = 1", player:getGuid()))
    if not resultId then
        return {}
    end

    local tasks = {}
    repeat
        table.insert(tasks, {
            id = result.getNumber(resultId, "Id"),
            taskId = result.getNumber(resultId, "TaskId"),
            amount = result.getNumber(resultId, "Amount"),
            progress = result.getNumber(resultId, "Progress"),
            paused = result.getNumber(resultId, "Paused"),
            active = result.getNumber(resultId, "Active"),
            finished = result.getNumber(resultId, "Finished"),
            startTime = result.getString(resultId, "StartTime"),
            endTime = result.getString(resultId, "EndTime")
        })
    until not result.next(resultId)

    result.free(resultId)

    return tasks
end

function TaskManager.getTaskName(taskId)
    local resultId = db.storeQuery(string.format("SELECT TaskName FROM TaskDefinitions WHERE Id = %d", taskId))
    if resultId then
        local name = result.getString(resultId, "TaskName")
        result.free(resultId)
        return name
    end
    return "Unknown Task"
end

function TaskManager.getTaskDefinitionById(taskId)
    local resultId = db.storeQuery(string.format(
            "SELECT * FROM TaskDefinitions WHERE Id = %d", taskId
    ))

    if not resultId then
        return nil
    end

    local taskDef = {
        id = result.getNumber(resultId, "Id"),
        taskName = result.getString(resultId, "TaskName"),
        monsterNames = parseJsonArray(result.getString(resultId, "MonsterNames"), true),
        lookTypeIds = parseJsonArray(result.getString(resultId, "LookTypeIds"), false),
        category = result.getNumber(resultId, "Category"),
        maxAmount = result.getNumber(resultId, "MaxAmount"),
        experience = result.getNumber(resultId, "Experience")
    }

    result.free(resultId)
    return taskDef
end

function TaskManager.sendTasksToClient(player)
    local tasks = TaskManager.getActiveTasks(player)
    if not tasks then
        return
    end

    local array = {}
    for _, task in ipairs(tasks) do
        table.insert(array, task)
    end

    local playerId = player:getGuid()
    local jsonString = json.encode(array)
    player:sendExtendedOpcode(EXTENDED_OPCODES.SEND_TASKS, playerId .. ";" .. jsonString)
end

function TaskManager.updateMaxAmount(player, taskId)
    if not player or not taskId then
        return false
    end

    TaskManager.sendAvailableTaskList(player)

    return true
end

function TaskManager.getPlayerTaskPoints(player)
    local resultId = db.storeQuery(string.format("SELECT TaskPoints FROM Players WHERE id = %d", player:getGuid()))
    if not resultId then
        return 0
    end

    local points = result.getNumber(resultId, "TaskPoints") or 0
    result.free(resultId)

    return points
end

function TaskManager.calculateTaskPointsReward(amount, experience, category)
    if amount > 1000 then
        amount = 1000
    end

    local categoryMultiplier = 1

    if category == 1 then
        categoryMultiplier = 0.1
    elseif category == 2 then
        categoryMultiplier = 0.5
    elseif category == 3 then
        categoryMultiplier = 1
    elseif category == 4 then
        categoryMultiplier = 1.5
    end

    local basePointsPerKill = (experience / 10000) * categoryMultiplier

    local totalTP = math.floor(basePointsPerKill * amount)

    totalTP = math.floor(totalTP / 2)

    return totalTP
end

function TaskManager.calculateGoldReward(amount, experience, category)

    if amount > 1000 then
        amount = 1000
    end
    local baseRewardPerKill = experience / 5

    if category >= 3 then
        baseRewardPerKill = baseRewardPerKill / 3
    end

    local totalGold = math.floor(baseRewardPerKill * amount)

    return totalGold
end

function TaskManager.calculateExperienceReward(amount, experience)
    if amount > 1000 then
        amount = 1000
    end

    local totalExp = math.floor(amount * experience * 0.55)

    return totalExp
end