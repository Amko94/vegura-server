local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)
    npcHandler:onCreatureAppear(cid)
end
function onCreatureDisappear(cid)
    npcHandler:onCreatureDisappear(cid)
end
function onCreatureSay(cid, type, msg)
    npcHandler:onCreatureSay(cid, type, msg)
end
function onThink()
    npcHandler:onThink()
end

local voices = { { text = 'Spell Tomes and Rune Enchanters! Finest craftsmanship in town!' } }
npcHandler:addModule(VoiceModule:new(voices))

local function creatureSayCallback(cid, type, msg)
    if not npcHandler:isFocused(cid) then
        return false
    end

    local player = Player(cid)

    if msgcontains(msg, "tome of spell mastery") then
        npcHandler:say("Ah, a tome of spell mastery! That is quite difficult to craft. Do you have 6 fragments of spell mastery with you?", cid)
        npcHandler.topic[cid] = 1
        return true
    end

    if npcHandler.topic[cid] == 1 then
        if msgcontains(msg, 'yes') then
            if player:getItemCount(7501) < 6 then
                npcHandler:say("Nice try, but I don't see 6 fragments of spell mastery.", cid)
                npcHandler.topic[cid] = 0
            else
                npcHandler:say("Excellent! To craft this tome, I will also need 40000 gold coins. Plus, there is a 50% chance that the crafting will fail. Should I try?", cid)
                npcHandler.topic[cid] = 2
            end
        else
            npcHandler:say("Maybe another time.", cid)
            npcHandler.topic[cid] = 0
        end
        return true
    end

    if npcHandler.topic[cid] == 2 then
        if msgcontains(msg, 'yes') then
            if player:getMoney() + player:getBankBalance() < 40000 then
                npcHandler:say("Unfortunately, you don't have enough gold coins with you.", cid)
                npcHandler.topic[cid] = 0
            else
                player:removeItem(7501, 6)
                player:removeMoney(40000)

                local success = math.random(1, 100) <= 50

                if success then
                    npcHandler:say("Here it is! The tome of spell mastery has been successfully crafted!", cid)
                    local item = player:addItem(7503, 1)
                    if not item then
                        player:addItem(7503, 1, player:getPosition())
                    end
                else
                    npcHandler:say("I'm sorry, the crafting formula has failed. These things happen sometimes.", cid)
                end
                npcHandler.topic[cid] = 0
            end
        else
            npcHandler:say("Maybe another time.", cid)
            npcHandler.topic[cid] = 0
        end
        return true
    end

    return true
end

keywordHandler:addKeyword({ 'job' }, StdModule.say, { npcHandler = npcHandler, text = 'I am a master crafter of spell tomes and rune enchanters.' })
keywordHandler:addKeyword({ 'name' }, StdModule.say, { npcHandler = npcHandler, text = 'I am Ezra.' })
keywordHandler:addKeyword({ 'view' }, StdModule.say, { npcHandler = npcHandler, text = 'Yes, the view from here is absolutely wonderful.' })

npcHandler:setMessage(MESSAGE_GREET, 'Greetings, |PLAYERNAME|! Don\'t we have a wonderful view from here? How can I help you?')
npcHandler:setMessage(MESSAGE_FAREWELL, 'Good bye.')
npcHandler:setMessage(MESSAGE_WALKAWAY, 'Good bye.')

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())