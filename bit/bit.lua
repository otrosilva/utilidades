#!/usr/bin/env lua5.4
-- bit.lua — bitácoras en un solo archivo (optimizado + regex)

-- ===== CONFIG =====
local RUTA   = "~/Documentos/Filen/bits.txt"
local EDITOR = "hx +9999"

-- ===== UTILS =====
local function expand(path)
    if path:sub(1, 1) == "~" then
        return (os.getenv("HOME") or "") .. path:sub(2)
    end
    return path
end

RUTA = expand(RUTA)

local function tmpfile(name)
    local base = os.getenv("TMPDIR") or "/tmp"
    return string.format("%s/bit_%s.tmp", base, name)
end

-- ===== CORE =====
local function procesar(pref)
    local f = io.open(RUTA, "r")
    if not f then return {}, {} end
    
    local exact = {}
    local names = {}
    for line in f:lines() do
        local name = line:match("^([%w_-]+)%s")
        if name then
            names[name] = true
            if name == pref then exact[#exact + 1] = line end
        end
    end
    f:close()
    return exact, names
end

local function listar()
    local _, names = procesar("")
    if next(names) == nil then
        print("No hay bitácoras")
        return
    end
    for name in pairs(names) do print(name) end
end

local function mostrar(pref)
    local exact, names = procesar(pref)
    
    if #exact > 0 then
        for _, line in ipairs(exact) do
            -- Captura DESDE fecha hasta comentario: "YYYY-MM-DD HH:MM:SS: comentario"
            local fecha_comentario = line:match("^[%w_-]+%s(%d%d%d%d%-%d%d%-%d%d%s%d%d:%d%d:%d%d:.*)$")
            if fecha_comentario then
                print(fecha_comentario)
            end
        end
    else
        local sugg = {}
        for name in pairs(names) do
            if name:sub(1, #pref) == pref then
                sugg[#sugg + 1] = name
            end
        end
        if #sugg > 0 then
            print("Bitácoras:")
            for _, s in ipairs(sugg) do print(s) end
        else
            print("No hay entradas para " .. pref)
        end
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

local function borrar(name, all)
    local f = io.open(RUTA, "r")
    if not f then return end

    local lines = {}
    local tiene_entradas = false
    for l in f:lines() do 
        lines[#lines + 1] = l 
        if l:match("^" .. name .. "%s") then tiene_entradas = true end
    end
    f:close()
    
    if not tiene_entradas then
        print("No hay entradas para " .. name)
        return
    end

    if all then
        io.write("¿Borrar TODAS las entradas de " .. name .. "? (s/n): ")
        if io.read() ~= "s" then return end
    end

    local borrada
    for i = #lines, 1, -1 do
        if lines[i]:match("^" .. name .. "%s") then
            borrada = lines[i]
            table.remove(lines, i)
            if not all then break end
        end
    end

    f = io.open(RUTA, "w")
    for _, l in ipairs(lines) do f:write(l .. "\n") end
    f:close()

    if borrada and not all then
        print(borrada)
    end
end

-- ===== EDITAR BITÁCORA EN TEMPORAL (y reordenar por fecha) =====
local function editar_bitacora(name)
    local exact, names = procesar(name)
    if not names[name] then
        print("No existe " .. name)
        os.exit(1)
    end

    local tmp = tmpfile(name)
    local tf = io.open(tmp, "w")
    if not tf then
        print("No se pudo crear archivo temporal: " .. tmp)
        os.exit(1)
    end
    for _, line in ipairs(exact) do
        tf:write(line .. "\n")
    end
    tf:close()

    os.execute(EDITOR .. " " .. tmp)

    -- 1) Leer TODO bits.txt, excluyendo la bitácora editada
    local f = io.open(RUTA, "r")
    if not f then
        print("No se pudo reabrir " .. RUTA)
        os.exit(1)
    end
    local lines = {}
    for l in f:lines() do
        if not l:match("^" .. name .. "%s") then
            lines[#lines + 1] = l
        end
    end
    f:close()

    -- 2) Añadir las nuevas líneas de la bitácora desde el temporal
    tf = io.open(tmp, "r")
    if tf then
        for l in tf:lines() do
            if l ~= "" then
                lines[#lines + 1] = l
            end
        end
        tf:close()
    end

    -- 3) Ordenar todas las líneas por fecha (segunda columna)
    table.sort(lines, function(a, b)
        local fa = a:match("^[^%s]+%s(%d%d%d%d%-%d%d%-%d%d%s%d%d:%d%d:%d%d)")
        local fb = b:match("^[^%s]+%s(%d%d%d%d%-%d%d%-%d%d%s%d%d:%d%d:%d%d)")
        if fa and fb then
            return fa < fb
        else
            -- si alguna línea no tiene fecha válida, cae a comparación simple
            return a < b
        end
    end)

    -- 4) Escribir de vuelta
    f = io.open(RUTA, "w")
    if not f then
        print("No se pudo escribir en " .. RUTA)
        os.exit(1)
    end
    for _, l in ipairs(lines) do
        f:write(l .. "\n")
    end
    f:close()
end

-- ===== MAIN =====
if #arg == 0 then
    listar()
    os.exit(0)
end

-- ./bit.lua ++  -> abrir archivo completo
if #arg == 1 and arg[1] == "++" then
    os.execute(EDITOR .. " " .. RUTA)
    os.exit(0)
end

local extra
local name = arg[1]

if name:match("^[+-@]") then
    extra = name:sub(1, 1)
    name  = name:sub(2)
end

local abrir_editor = extra == "+"

if #arg == 1 then
    if abrir_editor then
        -- +bitacora -> editar solo esa bitácora
        editar_bitacora(name)
    elseif extra == "-" then
        borrar(name, false)
    elseif extra == "@" then
        borrar(name, true)
    else
        mostrar(name)
    end
else
    -- hay texto: agregar entrada
    agregar(name, table.concat(arg, " ", 2))
    if abrir_editor then
        -- +bitacora texto -> añadir y luego editar solo esa bitácora
        editar_bitacora(name)
    end
end
