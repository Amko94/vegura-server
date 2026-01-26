local VEGURA_COIN = 7504

function onUse(player, item)
    if not player or not item then
        return true
    end

    if item:getId() ~= VEGURA_COIN then
        return true
    end

    if player:convertVeguraCoinsToPoints(item) then
        player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
        player:sendTextMessage(
                MESSAGE_STATUS_SMALL,
                "Converted 1 Vegura coin to 10 Vegura points"
        )

    else
        player:sendTextMessage(
                MESSAGE_STATUS_DEFAULT,
                "Conversion failed."
        )
    end

    return true
end
