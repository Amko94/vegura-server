TRAVEL_DESTINATIONS = {
    ["thais"] = {x = 32369, y = 32241, z = 7, cost = 100},
    ["carlin"] = {x = 32387, y = 31820, z = 7, cost = 110},
    ["venore"] = {x = 32954, y = 32022, z = 7, cost = 130},
}

function tryInstantTravel(npcHandler, player, message)
    local msg = message:lower()

    if not msg:find("bring me to") then
        return false
    end

    local destination = msg:gsub("bring me to%s+", "")

    local dest = TRAVEL_DESTINATIONS[destination]
    if not dest then
        npcHandler:say("I don't know that place.", player)
        return true
    end

    if player:getMoney() < dest.cost then
        npcHandler:say("You don't have enough gold.", player)
        return true
    end

    player:removeMoney(dest.cost)
    player:teleportTo(Position(dest.x, dest.y, dest.z))
    player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)

    npcHandler:say("Hold tight!", player)
    return true
end
