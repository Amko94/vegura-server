TaskManager = {}

local taskDefinitionsCache = nil
local taskCacheExpiry = 0
local CACHE_DURATION = 300000

function TaskManager.getAllTaskMonsters()
    local now = os.time() * 1000

    if taskDefinitionsCache and now < taskCacheExpiry then
        return taskDefinitionsCache
    end

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
            maxAmount = result.getNumber(resultId, "MaxAmount")
        }
        table.insert(fullList, task)
    until not result.next(resultId)
    result.free(resultId)

    -- Cache speichern
    taskDefinitionsCache = fullList
    taskCacheExpiry = now + CACHE_DURATION

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

    local fullList = TaskManager.getAllTaskMonsters()

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

    return true
end

function TaskManager.sendAvailableTaskListDirect(player)
    if not player then
        return false
    end

    local fullList = TaskManager.getAllTaskMonsters()

    local compactList = {}
    for _, task in ipairs(fullList) do
        table.insert(compactList, {
            id = task.id,
            taskName = task.taskName,
            lookTypeIds = task.lookTypeIds,
            category = task.category,
            maxAmount = task.maxAmount
        })
    end

    local payload = json.encode(compactList)
    print("[TaskManager] Payload size: " .. #payload .. " bytes")

    if #payload > 65000 then
        print("[TaskManager] Payload too large, using chunked method")
        return TaskManager.sendAvailableTaskList(player)
    else
        player:sendExtendedOpcode(4, "TASKLIST_COMPLETE;" .. payload)
        print("[TaskManager] All tasks sent directly - Total: " .. #fullList)
        return true
    end
end

function TaskManager.checkPlayerHasActiveTask(player)
    local resultId = db.storeQuery(string.format("SELECT Id FROM PlayerTasks WHERE PlayerId = %d AND Paused = 0 AND Active = 1", player:getGuid()))

    if resultId ~= false then
        player:sendTextMessage(MESSAGE_STATUS_WARNING, "Start task failed. You already have an active task.")
        result.free(resultId)
        return true
    end
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

    TaskManager.checkPlayerHasActiveTask(player)

    local success = db.query(string.format(
            "INSERT INTO PlayerTasks (PlayerId, TaskId, Amount, Progress, Paused, Finished, Active, StartTime, EndTime) VALUES (%d, %d, %d, 0, 0, 0, 1, NOW(), NULL)",
            player:getGuid(),
            taskId,
            amount
    ))

    if success then
        print("[TaskManager] Task started with TaskId:", taskId)
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
    return true
end

function TaskManager.pauseTask(player, taskId)
    if not player or not taskId then
        return false
    end

    local resultId = db.storeQuery(string.format(
            "SELECT Id FROM PlayerTasks WHERE PlayerId = %d AND TaskId = %d AND Finished = 0 AND Paused = 0",
            player:getGuid(), taskId))
    if not resultId then
        return false
    end

    local playerTaskId = result.getNumber(resultId, "Id")
    result.free(resultId)

    db.query(string.format("UPDATE PlayerTasks SET Paused = 1 WHERE Id = %d", playerTaskId))
    return true
end

function TaskManager.resumeTask(player, taskId)
    if not player or not taskId then
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
    return true
end

function TaskManager.cancelTask(player, taskId)
    if not player or not taskId then
        return false
    end

    local success = db.query(string.format(
            "DELETE FROM PlayerTasks WHERE PlayerId = %d AND TaskId = %d",
            player:getGuid(), taskId))

    return success
end

function TaskManager.getActiveTasks(player)
    if not player then
        return {}
    end

    local resultId = db.storeQuery(string.format("SELECT * FROM PlayerTasks WHERE PlayerId = %d AND Finished = 0", player:getGuid()))
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
        maxAmount = result.getNumber(resultId, "MaxAmount")
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

    local jsonString = json.encode(array)
    player:sendExtendedOpcode(EXTENDED_OPCODES.SEND_TASKS, jsonString)
end

function TaskManager.updateMaxAmount(player, taskId)
    if not player or not taskId then
        return false
    end

    TaskManager.sendAvailableTaskList(player)
    TaskManager.sendTasksToClient(player)

    return true
end