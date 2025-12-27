-- Including the Advanced NPC System
dofile('data/npc/lib/configuration.lua')
dofile('data/npc/lib/npcsystem/npcsystem.lua')
dofile('data/npc/lib/npcsystem/customModules.lua')

function msgcontains(message, keyword)
	local message, keyword = message:lower(), keyword:lower()
	if message == keyword then
		return true
	end

	return message:find(keyword) and not message:find('(%w+)' .. keyword)
end

function doNpcSellItem(cid, itemId, amount, subType, ignoreCap, inBackpacks, backpack)
	local amount = amount or 1
	local subType = subType or 0
	local item = 0
	local player = Player(cid)
	if ItemType(itemId):isStackable() then
		local stuff
		if inBackpacks then
			stuff = Game.createItem(backpack, 1)
			item = stuff:addItem(itemId, math.min(100, amount))
		else
			stuff = Game.createItem(itemId, math.min(100, amount))
		end

		return player:addItemEx(stuff, ignoreCap) ~= RETURNVALUE_NOERROR and 0 or amount, 0
	end

	local a = 0
	if inBackpacks then
		local container, itemType, b = Game.createItem(backpack, 1), ItemType(backpack), 1
		for i = 1, amount do
			local item = container:addItem(itemId, subType)
			if isInArray({(itemType:getCapacity() * b), amount}, i) then
				if player:addItemEx(container, ignoreCap) ~= RETURNVALUE_NOERROR then
					b = b - 1
					break
				end

				a = i
				if amount > i then
					container = Game.createItem(backpack, 1)
					b = b + 1
				end
			end
		end

		return a, b
	end

	for i = 1, amount do -- normal method for non-stackable items
		local item = Game.createItem(itemId, subType)
		if player:addItemEx(item, ignoreCap) ~= RETURNVALUE_NOERROR then
			break
		end
		a = i
	end
	return a, 0
end

local func = function(cid, text, type, e, pcid)
	local npc = Npc(cid)
	if not npc then
		return
	end

	local player = Player(pcid)
	if player then
		npc:say(text, type, false, player, npc:getPosition())
		e.done = true
	end
end

function doCreatureSayWithDelay(cid, text, type, delay, e, pcid)
	if Player(pcid) then
		e.done = false
		e.event = addEvent(func, delay < 1 and 1000 or delay, cid, text, type, e, pcid)
	end
end

function doPlayerTakeItem(cid, itemid, count)
	local player = Player(cid)
	if player:getItemCount(itemid) < count then
		return false
	end

	while count > 0 do
		local tempcount = 0
		if ItemType(itemid):isStackable() then
			tempcount = math.min (100, count)
		else
			tempcount = 1
		end

		local ret = player:removeItem(itemid, tempcount)
		if ret then
			count = count - tempcount
		else
			return false
		end
	end

	if count ~= 0 then
		return false
	end
	return true
end

function doPlayerSellItem(cid, itemid, count, cost)
	local player = Player(cid)
	if doPlayerTakeItem(cid, itemid, count) then
		if not player:addMoney(cost) then
			error('Could not add money to ' .. player:getName() .. '(' .. cost .. 'gp)')
		end
		return true
	end
	return false
end

function doPlayerBuyItemContainer(cid, containerid, itemid, count, cost, charges)
	local player = Player(cid)

	-- Check if player has enough money
	if not player:removeMoney(cost) then
		return false
	end

	if count >= 20 then
		-- Calculate number of outer backpacks needed (each outer backpack holds up to 20 inner backpacks)
		local maxItemsPerBackpack = 20
		local fullBackpacks = math.floor(count / maxItemsPerBackpack)
		local remainingItems = count % maxItemsPerBackpack
		local totalBackpacks = fullBackpacks + (remainingItems > 0 and 1 or 0)

		-- Create outer backpacks and pack inner backpacks with one item each
		for i = 1, totalBackpacks do
			local outerBackpack = Game.createItem(containerid, 1)
			if not outerBackpack then
				return false
			end

			-- Determine how many inner backpacks to add to this outer backpack
			local innerBackpacksToAdd = i <= fullBackpacks and maxItemsPerBackpack or remainingItems

			-- Create inner backpacks and add one item to each
			for j = 1, innerBackpacksToAdd do
				local innerBackpack = Game.createItem(containerid, 1)
				if not innerBackpack then
					return false
				end

				for i = 1, 20 do
					innerBackpack:addItem(itemid, charges)
				end

				outerBackpack:addItemEx(innerBackpack)
			end

			-- Add outer backpack to player's inventory
			if player:addItemEx(outerBackpack) ~= RETURNVALUE_NOERROR then
				return false
			end
		end
	else
		-- For counts < 20, give inner backpacks directly to the player
		for i = 1, count do
			local innerBackpack = Game.createItem(containerid, 1)
			if not innerBackpack then
				return false
			end
			for i = 1, 20 do
				innerBackpack:addItem(itemid, charges)
			end

			if player:addItemEx(innerBackpack) ~= RETURNVALUE_NOERROR then
				return false
			end
		end
	end

	return true
end

function getCount(string)
	local b, e = string:find("%d+")
	return b and e and tonumber(string:sub(b, e)) or -1
end
