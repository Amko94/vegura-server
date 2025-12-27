-- slot_machine‑wins-listener.lua
-- prüft offene Gewinne, bucht Geld + Spezial‑Item (Boots of Haste 2195)

local QUERY_WINS = [[
SELECT  `Id`, `PlayerId`, `Amount`, `SpecialWin`
FROM    `slotmachinewins`
WHERE   `Delivered` = 0
]]

-- ──────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────

local function getPlayerNameById(pid)
    local r = db.storeQuery("SELECT `name` FROM `players` WHERE `id` = " .. pid)
    if not r then
        return nil
    end
    local name = result.getString(r, "name")
    result.free(r)
    return name
end

local function markWinDelivered(id)
    return db.query(string.format(
            "UPDATE `slotmachinewins` SET `Delivered` = 1 WHERE `Id` = %s",
            db.escapeString(id)
    ))
end

local function creditBalance(pid, amount)
    if amount <= 0 then
        return false, "invalid‑amount"
    end

    local r = db.storeQuery("SELECT `balance` FROM `players` WHERE `id` = " .. pid)
    if not r then
        return false, "no‑balance"
    end
    local cur = result.getNumber(r, "balance")
    result.free(r)

    local newBal = cur + amount
    if not db.query(string.format(
            "UPDATE `players` SET `balance` = %d WHERE `id` = %d",
            newBal, pid)) then
        return false, "db‑update‑failed"
    end

    local name = getPlayerNameById(pid)
    local pl = name and Player(name)
    if pl then
        pl:setBankBalance(newBal)
    end
    return true
end

-- nächste freie pid im Depot bestimmen ------------------------
local function getNextDepotPid(pid, sid)
    local r = db.storeQuery(string.format(
            "SELECT MAX(`pid`) AS m FROM `player_depotitems` WHERE `player_id`=%d AND `sid`=%d",
            pid, sid))
    local max = 0
    if r then
        max = result.getNumber(r, "m") or 0
        result.free(r)
    end
    return max + 1
end

local function getNextSid(pid, townId)
    local r = db.storeQuery(string.format(
            "SELECT MAX(`sid`) AS m FROM `player_depotitems` WHERE `player_id`=%d AND pid = %d",
            pid, townId))
    local max = 100
    if r then
        local value = result.getNumber(r, "m")
        if value and value > 0 then
            max = value
        end
        result.free(r)
    end
    return max + 1
end


-- Item ins Depot (online ODER offline) ------------------------
local function addItemToDepot(pid, itemId)
    local name = getPlayerNameById(pid)
    local pl = name and Player(name)

    local townId

    if pl then
        townId = pl:getTown():getId()
        local depot = pl:getDepotChest(townId, true)
        if depot then
            local it = Game.createItem(itemId, 1)
            if it and depot:addItemEx(it) == RETURNVALUE_NOERROR then
                pl:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Congratulations on your special win! It was added to your depot.")
                return true
            end
        end

    else
        return false
    end
end

-- Spezial‑Gewinn (Boots) --------------------------------------
local ITEM_ID = 2195
local function giveSpecialReward(pid)
    local name = getPlayerNameById(pid)
    if not name then
        return false
    end

    local pl = Player(name)
    if pl then

        local it = Game.createItem(ITEM_ID, 1)
        if it and pl:addItemEx(it, false, CONST_SLOT_WHEREEVER) == RETURNVALUE_NOERROR then
            pl:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Congratulations on your special win! It was added to your inventory.")
            return true
        end
    end
    print(string.format("[SLOTMACHINE] Delivery not possible at the moment: player is not online."))
    return addItemToDepot(pid, 2195)
end

-- ──────────────────────────────────────────────────────────────
-- onThink: Gewinne abarbeiten
-- ──────────────────────────────────────────────────────────────
function onThink()
    local res = db.storeQuery(QUERY_WINS)
    if not res then
        return true
    end

    repeat
        local winId = result.getString(res, "Id")
        local pid = result.getNumber(res, "PlayerId")
        local amount = result.getNumber(res, "Amount")
        local spec = result.getNumber(res, "SpecialWin") == 1

        local ok, why = creditBalance(pid, amount)
        if not ok then
            print(string.format("[SlotMachine] ERROR crediting (%s) for PID %d.", why, pid))
        else
            local rewardOK = true
            if spec then
                rewardOK = giveSpecialReward(pid)
                if not rewardOK then
                    print(string.format("[SlotMachine] ERROR delivering special reward to PID %d.", pid))
                end
            end

            if rewardOK then
                markWinDelivered(winId);
            end
        end
    until not result.next(res)

    result.free(res)
    db.query("DELETE FROM `slotmachinewins` WHERE `Delivered` = 1 AND `Created` < NOW() - INTERVAL 30 DAY")
    return true
end

