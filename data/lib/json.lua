json = {}

function json.encode(t)
    local function isArray(tbl)
        -- Prüft, ob die Tabelle ein Array ist (nur numerische Indizes ab 1 ohne Lücken)
        local i = 0
        for k in pairs(tbl) do
            i = i + 1
            if type(k) ~= "number" or k ~= i then
                return false
            end
        end
        return true
    end

    local function serialize(tbl)
        -- Wenn die Tabelle ein Array ist, als JSON-Array serialisieren
        if isArray(tbl) then
            local tmp = {}
            for i, v in ipairs(tbl) do
                local value
                if type(v) == "table" then
                    value = serialize(v)
                elseif type(v) == "string" then
                    value = '"' .. v:gsub('"', '\\"') .. '"'
                elseif type(v) == "number" then
                    value = tostring(v)
                elseif type(v) == "boolean" then
                    value = v and "true" or "false"
                elseif v == nil then
                    value = "null"
                else
                    value = '"' .. tostring(v) .. '"'
                end
                table.insert(tmp, value)
            end
            return "[" .. table.concat(tmp, ",") .. "]"
        else
            -- Sonst als JSON-Objekt serialisieren
            local tmp = {}
            for k, v in pairs(tbl) do
                local key = type(k) == "string" and '"' .. k .. '"' or tostring(k)
                local value
                if type(v) == "table" then
                    value = serialize(v)
                elseif type(v) == "string" then
                    value = '"' .. v:gsub('"', '\\"') .. '"'
                elseif type(v) == "number" then
                    value = tostring(v)
                elseif type(v) == "boolean" then
                    value = v and "true" or "false"
                elseif v == nil then
                    value = "null"
                else
                    value = '"' .. tostring(v) .. '"'
                end
                table.insert(tmp, key .. ":" .. value)
            end
            return "{" .. table.concat(tmp, ",") .. "}"
        end
    end

    return serialize(t)
end

function json.decode(str)
    error("json.decode not implemented")
end