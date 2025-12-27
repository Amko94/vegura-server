local EXTENDED_OPCODES = {
    START_TASK = 1,
    KILL_UPDATE = 2,
    SEND_TASKS = 3,
    REQUEST_TASK_LIST = 4,
    RESUME_TASK = 5,
    PAUSE_TASK = 6,
    CANCEL_TASK = 7
}

function onExtendedOpcode(player, opcode, buffer)
    print("[ExtendedOpcode] EINGANG: Player:", player and player:getName() or "NONE", "Opcode:", opcode, "Buffer:", buffer)

    if opcode == EXTENDED_OPCODES.START_TASK then
        local split = buffer:split(";")
        local taskId = tonumber(split[1])
        local amount = tonumber(split[2])

        if not taskId or not amount then
            player:sendCancelMessage("Invalid task data received.")
            return true
        end

        if TaskManager.startTask(player, taskId, amount) then
            player:sendExtendedOpcode(EXTENDED_OPCODES.START_TASK, "TASK_STARTED;" .. taskId .. ";" .. amount)
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Task started!")
            TaskManager.sendTasksToClient(player)
        else
            player:sendCancelMessage("Failed to start task.")
        end

    elseif opcode == EXTENDED_OPCODES.REQUEST_TASK_LIST then
        print("[ExtendedOpcode] Request: Available tasks")
        TaskManager.sendAvailableTaskList(player)
        TaskManager.sendTasksToClient(player)

    elseif opcode == EXTENDED_OPCODES.RESUME_TASK then
        local split = buffer:split(";")
        local taskId = tonumber(split[1])

        if not taskId then
            player:sendCancelMessage("Invalid task data received.")
            return true
        end

        if TaskManager.resumeTask(player, taskId) then
            player:sendTextMessage(MESSAGE_INFO_DESCR, "Task resumed")
            TaskManager.sendTasksToClient(player)
        else
            player:sendCancelMessage("Failed to resume task.")
        end

    elseif opcode == EXTENDED_OPCODES.PAUSE_TASK then
        local split = buffer:split(";")
        local taskId = tonumber(split[1])

        if not taskId then
            player:sendCancelMessage("Invalid task data received.")
            return true
        end

        if TaskManager.pauseTask(player, taskId) then
            player:sendTextMessage(MESSAGE_INFO_DESCR, "Task paused")
            TaskManager.sendTasksToClient(player)
        else
            player:sendCancelMessage("Failed to pause task.")
        end

    elseif opcode == EXTENDED_OPCODES.CANCEL_TASK then
        local split = buffer:split(";")
        local taskId = tonumber(split[1])

        if not taskId then
            player:sendCancelMessage("Invalid task data received.")
            return true
        end

        if TaskManager.cancelTask(player, taskId) then
            player:sendTextMessage(MESSAGE_STATUS_WARNING, "Your task has been canceled")
            TaskManager.sendTasksToClient(player)
        else
            player:sendCancelMessage("Failed to cancel task.")
        end

    else
        print("[ExtendedOpcode] Unknown opcode:", opcode)
    end

    return true
end