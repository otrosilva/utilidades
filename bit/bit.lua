#!/usr/bin/env lua5.4
-- bit.lua — bitácoras en un solo archivo

-- ===== CONFIG =====
local RUTA   = "~/Documentos/@nube/bits.txt"
local EDITOR = "hx +9999"

-- ===== UTILS =====
local function expand(path)
    if path:sub(1, 1) == "~" then
        return (os.getenv("HOME") or "") .. path:sub(2)
    end
    return path
end

RUTA = expand(RUTA)

-- crear archivo si no existe
do
    local f = io.open(RUTA, "a")
    if f then f:close() end
end

-- ===== CORE =====
local function listar()
    local f = io.open(RUTA, "r")
    if not f then
        print("No hay bitácoras")
        return
    end

    local seen = {}
    for line in f:lines() do
        local name = line:match("^([%w_-]+)%s")
        if name and not seen[name] then
            seen[name] = true
            print(name)
        end
    end
    f:close()
end

local function mostrar(pref)
    local f = io.open(RUTA, "r")
    if not f then
        print("No hay entradas para " .. pref)
        return
    end

    local exact = {}
    local sugg = {}
    local seen = {}

    for line in f:lines() do
        local name = line:match("^([%w_-]+)%s")
        if name then
            if name == pref then
                exact[#exact + 1] = line
            end
            if name:sub(1, #pref) == pref and not seen[name] then
                seen[name] = true
                sugg[#sugg + 1] = name
            end
        end
    end
    f:close()

    if #exact > 0 then
        local offset = #pref + 2 -- nombre + espacio
        for _, l in ipairs(exact) do
            print(l:sub(offset))
        end
    elseif #sugg > 0 then
        print("Bitácoras:")
        for _, s in ipairs(sugg) do print(s) end
    else
        print("No hay entradas para " .. pref)
    end
end

local function agregar(name, text)
    local f = io.open(RUTA, "a")
    if not f then return end
    f:write(string.format(
        "%s %s: %s\n",
        name,
        os.date("%Y-%m-%d %H:%M:%S"),
        text
    ))
    f:close()
end

-- === NUEVO: comprobar existencia ===
local function existe(name)
    local f = io.open(RUTA, "r")
    if not f then return false end
    for line in f:lines() do
        if line:match("^" .. name .. "%s") then
            f:close()
            return true
        end
    end
    f:close()
    return false
end

local function borrar(name, all)
    if not existe(name) then
        print("No hay entradas para " .. name)
        return
    end

    local f = io.open(RUTA, "r")
    if not f then return end

    local lines = {}
    for l in f:lines() do lines[#lines + 1] = l end
    f:close()

    if all then
        io.write("¿Borrar TODAS las entradas de " .. name .. "? (s/n): ")
        if io.read() ~= "s" then return end
    end

    for i = #lines, 1, -1 do
        if lines[i]:match("^" .. name .. "%s") then
            table.remove(lines, i)
            if not all then break end
        end
    end

    f = io.open(RUTA, "w")
    for _, l in ipairs(lines) do f:write(l .. "\n") end
    f:close()
end

-- ===== MAIN =====
if #arg == 0 then
    print("Bitácoras:")
    listar()
    os.exit(0)
end

local extra
local name = arg[1]

if name:match("^[+-@]") then
    extra = name:sub(1, 1)
    name = name:sub(2)
end

if #arg == 1 then
    if extra == "+" then
        if not existe(name) then
            print("No existe " .. name)
            os.exit(1)
        else
            os.execute(EDITOR .. " " .. RUTA)
        end
    elseif extra == "-" then
        borrar(name, false)
    elseif extra == "@" then
        borrar(name, true)
    else
        mostrar(name)
    end
else
    agregar(name, table.concat(arg, " ", 2))
    if extra == "+" then
        os.execute(EDITOR .. " " .. RUTA)
    end
end
