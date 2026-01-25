TASK_MANAGER_EXTENDED_OPCODES = {
    START_TASK = 1,
    KILL_UPDATE = 2,
    SEND_TASKS = 3,
    REQUEST_TASK_LIST = 4,
    RESUME_TASK = 5,
    PAUSE_TASK = 6,
    CANCEL_TASK = 7,
    TASK_REWARD_REQUEST = 8,
    CONFIRM_CLAIM_REWARD = 9,
    CLAIM_REWARD_SUCCESS = 10,
    PAUSE_TASK_SUCCESS = 11,
    SEND_PLAYER_TASK_POINTS = 12
}

SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES = {

    SEND_SPELL_BOOST_DEFINITIONS = 28,
    OPEN_SPELL_BOOST_WINDOW = 29,
    SPELL_PRICE_REQUEST = 30,
    SEND_SPELL_PRICE = 31,
    BOOST_SPELL = 32,
    SEND_PAYER_SPELL_LEVELS = 33,
    UPGRADE_SUCCESSFUL = 34,
}

EXTENDED_ERROR_OPCODES = {
    RESUME_ERROR = 101,
    CLAIM_REWARD_ERROR_NO_FINISHED = 102,
    NO_ENOUGH_MONEY = 103,
    MISSING_TOME_OF_SPELL_MASTERY = 104,
    NO_PROTECT_ZONE = 105
}

local function handleStartTask(player, buffer)
    local split = buffer:split(";")
    local taskId = tonumber(split[1])
    local amount = tonumber(split[2])

    if not taskId or not amount then
        player:sendCancelMessage("Invalid task data received.")
        return
    end

    if TaskManager.startTask(player, taskId, amount) then
        player:sendExtendedOpcode(TASK_MANAGER_EXTENDED_OPCODES.START_TASK, "TASK_STARTED;" .. taskId .. ";" .. amount)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Task started!")
        TaskManager.sendPlayerTasksToClient(player)
    else
        player:sendCancelMessage("Failed to start task.")
    end
end

local function handleRequestTaskList(player, buffer)
    print("[ExtendedOpcode] Request: Available tasks")
    TaskManager.sendTaskList(player)
    TaskManager.sendPlayerTasksToClient(player)
end

local function handleResumeTask(player, buffer)
    local taskId = tonumber(buffer:split(";")[1])

    if not taskId then
        player:sendCancelMessage("Invalid task data received.")
        return
    end

    if TaskManager.resumeTask(player, taskId) then
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Task resumed")
        TaskManager.sendPlayerTasksToClient(player)
    else
        player:sendCancelMessage("Failed to resume task.")
    end
end

local function handlePauseTask(player, buffer)
    local taskId = tonumber(buffer:split(";")[1])

    if not taskId then
        player:sendCancelMessage("Invalid task data received.")
        return
    end

    if TaskManager.pauseTask(player, taskId) then
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Task paused")
        TaskManager.sendPlayerTasksToClient(player)
    else
        player:sendCancelMessage("Failed to pause task.")
    end
end

local function handleCancelTask(player, buffer)
    local taskId = tonumber(buffer:split(";")[1])

    if not taskId then
        player:sendCancelMessage("Invalid task data received.")
        return
    end

    if TaskManager.cancelTask(player, taskId) then
        player:sendTextMessage(MESSAGE_STATUS_WARNING, "Your task has been canceled")
        TaskManager.sendPlayerTasksToClient(player)
    else
        player:sendCancelMessage("Failed to cancel task.")
    end
end

local function handleTaskRewardRequest(player, buffer)
    local taskId = tonumber(buffer)

    if not taskId then
        player:sendCancelMessage("Invalid task data received.")
        return
    end

    TaskManager.taskRewardRequest(taskId, player)
end

local function handleConfirmClaimReward(player, buffer)
    local split = buffer:split(";")
    local taskId = tonumber(split[1])
    local rewardType = split[2]

    if not taskId then
        print('invalid taskId received', taskId)
        return
    end

    if not rewardType then
        print('invalid rewardType received', rewardType)
        return
    end

    TaskManager.claimReward(taskId, rewardType, player)
end

local function handleSpellPriceRequest(player, buffer)
    local spellName = buffer

    if not spellName then
        print('SpellName cannot be null')
        return
    end

    SpellBoostManager.sendSpellPrice(player, spellName)

end

local function handleBoostSpell(player, buffer)
    local spellName = buffer
    if not spellName then
        print('SpellName cannot be null')
        return
    end
    SpellBoostManager.boostSpell(spellName, player)

end

local opcodeHandlers = {
    [TASK_MANAGER_EXTENDED_OPCODES.START_TASK] = handleStartTask,
    [TASK_MANAGER_EXTENDED_OPCODES.REQUEST_TASK_LIST] = handleRequestTaskList,
    [TASK_MANAGER_EXTENDED_OPCODES.RESUME_TASK] = handleResumeTask,
    [TASK_MANAGER_EXTENDED_OPCODES.PAUSE_TASK] = handlePauseTask,
    [TASK_MANAGER_EXTENDED_OPCODES.CANCEL_TASK] = handleCancelTask,
    [TASK_MANAGER_EXTENDED_OPCODES.TASK_REWARD_REQUEST] = handleTaskRewardRequest,
    [TASK_MANAGER_EXTENDED_OPCODES.CONFIRM_CLAIM_REWARD] = handleConfirmClaimReward,
    [SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.SPELL_PRICE_REQUEST] = handleSpellPriceRequest,
    [SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.BOOST_SPELL] = handleBoostSpell,
}

function onExtendedOpcode(player, opcode, buffer)
    local handler = opcodeHandlers[opcode]

    if handler then
        handler(player, buffer)
    else
        print("[ExtendedOpcode] Unknown opcode:", opcode)
    end

    return true
end