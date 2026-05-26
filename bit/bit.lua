#!/usr/bin/env luajit
-- bit.lua — bitácoras en tabla markdown (estilo Unix + atajo rápido)

-- ===== CONFIG =====
local RUTA   = "~/Documentos/Filen/Obsidian/bits.md"
local EDITOR = "micro"

-- ===== UTILS =====
local function expand(path)
    if path:sub(1, 1) == "~" then
        return (os.getenv("HOME") or "") .. path:sub(2)
    end
    return path
end

RUTA = expand(RUTA)

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function tmpfile(name)
    local base = os.getenv("TMPDIR") or "/tmp"
    return string.format("%s/bit_%s.tmp", base, name)
end

-- ===== TIEMPO =====
local function ts_to_epoch(ts)
    local y, mo, d, h, mi = ts:match("(%d%d%d%d)-(%d%d)-(%d%d)%s+(%d%d):(%d%d)")
    if not y then return nil end
    local cmd = string.format(
        'date -d "%s-%s-%s %s:%s:00" +%%s 2>/dev/null || date -j -f "%%Y-%%m-%%d %%H:%%M:%%S" "%s-%s-%s %s:%s:00" +%%s 2>/dev/null',
        y, mo, d, h, mi, y, mo, d, h, mi
    )
    local p = io.popen(cmd)
    if not p then return nil end
    local out = trim(p:read("*a"))
    p:close()
    local n = tonumber(out)
    return n
end

local function fmt_diff(secs)
    if not secs or secs < 0 then return "?" end
    local total_min = math.floor(secs / 60)
    if total_min == 0 then return "0m" end
    local d = math.floor(total_min / 1440)
    local h = math.floor((total_min % 1440) / 60)
    local m = total_min % 60
    local s = ""
    if d > 0 then s = s .. d .. "d" end
    if h > 0 then s = s .. h .. "h" end
    if m > 0 then s = s .. m .. "m" end
    if s == "" then s = "0m" end
    return s
end

local function now_ts()
    return os.date("%Y-%m-%d %H:%M")
end

-- ===== PARSE / SERIALIZE =====
local HEADER = "| Fecha | Tipo | Evento | Comentario | Transcurrido |"
local SEP    = "| --- | --- | --- | --- | --- |"

local function parse_line(line)
    if not line:match("^|") then return nil end
    local fields = {}
    for field in (line .. "|"):gmatch("([^|]*)|") do
        fields[#fields + 1] = trim(field)
    end
    if #fields < 7 then return nil end
    local f1 = fields[2]
    if not f1:match("^%d%d%d%d%-%d%d%-%d%d") then return nil end
    return {
        fecha        = f1,
        tipo         = fields[3],
        evento       = fields[4],
        comentario   = fields[5],
        transcurrido = fields[6],
    }
end

local function parse_md()
    local entries = {}
    local f = io.open(RUTA, "r")
    if not f then return entries end
    for line in f:lines() do
        local e = parse_line(line)
        if e then entries[#entries + 1] = e end
    end
    f:close()
    return entries
end

local function write_md(entries)
    local f = io.open(RUTA, "w")
    if not f then
        io.stderr:write("Error: no se pudo escribir en " .. RUTA .. "\n")
        os.exit(1)
    end
    f:write("# Registro\n\n")
    f:write(HEADER .. "\n")
    f:write(SEP .. "\n")
    for _, e in ipairs(entries) do
        f:write(string.format("| %s | %s | %s | %s | %s |\n",
            e.fecha, e.tipo, e.evento, e.comentario, e.transcurrido))
    end
    f:close()
end

-- ===== CATEGORÍAS =====
local function categorias_existentes(entries)
    local cats = {}
    for _, e in ipairs(entries) do
        if e.tipo and e.tipo ~= "" then
            cats[e.tipo] = true
        end
    end
    local result = {}
    for k, _ in pairs(cats) do
        result[#result + 1] = k
    end
    table.sort(result)
    return result
end

-- ===== BÚSQUEDA =====
local function eventos_con_prefijo(entries, prefijo)
    local pref_low = prefijo:lower()
    local seen = {}
    local result = {}
    for _, e in ipairs(entries) do
        local ev = e.evento
        if ev:lower():sub(1, #pref_low) == pref_low then
            if not seen[ev] then
                seen[ev] = true
                result[#result + 1] = ev
            end
        end
    end
    table.sort(result)
    return result
end

local function ultima_entrada(entries, evento)
    local last = nil
    for _, e in ipairs(entries) do
        if e.evento == evento then
            last = e
        end
    end
    return last
end

-- ===== FUNCIONES PRINCIPALES =====
local function mostrar_ayuda()
    print([[
Uso: bit [opciones] [evento] [comentario]

Opciones:
  -h, --help          Muestra esta ayuda.
  -l, --list          Lista todas las bitácoras agrupadas por categoría.
  <evento>            Muestra todas las entradas del evento especificado.
  <evento> <comentario>   Añade una nueva entrada al evento (atajo rápido).
  -e, --edit <evento>   Edita todas las entradas del evento.
  -a, --add <evento> <comentario>   Añade una entrada (igual que el atajo).
  -d, --delete <evento>   Borra la última entrada del evento.
  -D, --delete-all <evento>  Borra TODAS las entradas del evento (pide confirmación).

Ejemplos:
  bit                          # Muestra resumen por categorías
  bit gato                     # Muestra todas las entradas de "gato"
  bit gato "duerme en la silla"  # Añade una entrada rápida
  bit -a gato "duerme"         # Mismo que arriba
  bit -e gato                  # Edita las entradas de "gato"
  bit -d gato                  # Borra la última entrada de "gato"
  bit -D gato                  # Borra todas las entradas de "gato"
]])
end

local function listar(entries)
    if #entries == 0 then
        print("No hay entradas")
        return
    end

    local by_category = {}
    for _, e in ipairs(entries) do
        local cat = e.tipo
        if not by_category[cat] then
            by_category[cat] = {}
        end
        local ev = e.evento
        if not by_category[cat][ev] then
            by_category[cat][ev] = 0
        end
        by_category[cat][ev] = by_category[cat][ev] + 1
    end

    local cats = {}
    for cat, _ in pairs(by_category) do
        cats[#cats + 1] = cat
    end
    table.sort(cats)

    for _, cat in ipairs(cats) do
        print("")
        print(string.format("| %s | #   |", cat))
        print("| --- | --- |")
        local event_counts = by_category[cat]
        local events = {}
        for ev, _ in pairs(event_counts) do
            events[#events + 1] = ev
        end
        table.sort(events)
        for _, ev in ipairs(events) do
            local count = event_counts[ev]
            print(string.format("| %s | %d |", ev, count))
        end
    end
end

local function mostrar_evento(entries, evento)
    local found = {}
    for _, e in ipairs(entries) do
        if e.evento == evento then
            found[#found + 1] = e
        end
    end
    if #found == 0 then
        print("No hay entradas para el evento '" .. evento .. "'")
        return
    end
    print("| Fecha | Tipo | Evento | Comentario | Transcurrido |")
    print("| --- | --- | --- | --- | --- |")
    for _, e in ipairs(found) do
        local comentario = e.comentario:gsub("|", "\\|")
        print(string.format("| %s | %s | %s | %s | %s |",
            e.fecha, e.tipo, e.evento, comentario, e.transcurrido))
    end
end

local function agregar(entries, evento, comentario)
    local last = ultima_entrada(entries, evento)
    local tipo = last and last.tipo or nil

    if not tipo then
        while true do
            io.write("Categoría para '" .. evento .. "' (escribe '?' para ver las existentes): ")
            io.flush()
            local input_cat = trim(io.read() or "")
            if input_cat == "?" then
                local cats = categorias_existentes(entries)
                if #cats == 0 then
                    print("No hay categorías previas. Puedes escribir una nueva.")
                else
                    print("Categorías existentes:")
                    for _, c in ipairs(cats) do
                        print("  - " .. c)
                    end
                end
            elseif input_cat ~= "" then
                tipo = input_cat
                break
            end
        end
        if tipo == "" then tipo = "Evento" end
    end

    local transcurrido = "inicio"
    if last then
        local epoch_last = ts_to_epoch(last.fecha)
        local epoch_now  = ts_to_epoch(now_ts())
        if epoch_last and epoch_now then
            transcurrido = fmt_diff(epoch_now - epoch_last)
        end
    end

    table.insert(entries, {
        fecha        = now_ts(),
        tipo         = tipo,
        evento       = evento,
        comentario   = comentario,
        transcurrido = transcurrido,
    })
    write_md(entries)
    print(string.format("+ %s | %s | %s | %s", now_ts(), tipo, evento, transcurrido))
end

local function borrar_ultima(entries, evento)
    local last_idx = nil
    for i = #entries, 1, -1 do
        if entries[i].evento == evento then
            last_idx = i
            break
        end
    end
    if not last_idx then
        print("No hay entradas para el evento '" .. evento .. "'")
        return
    end
    local removed = table.remove(entries, last_idx)
    write_md(entries)
    print(string.format("- %s | %s | %s", removed.fecha, removed.evento, removed.comentario))
end

local function borrar_todo(entries, evento)
    io.write("¿Borrar TODAS las entradas de '" .. evento .. "'? (s/n): ")
    io.flush()
    if io.read() ~= "s" then return end
    local new = {}
    for _, e in ipairs(entries) do
        if e.evento ~= evento then
            new[#new + 1] = e
        end
    end
    write_md(new)
    print("Borradas todas las entradas de '" .. evento .. "'")
end

local function editar_evento(entries, evento)
    local tmp = tmpfile(evento)
    local tf = io.open(tmp, "w")
    if not tf then
        io.stderr:write("No se pudo crear archivo temporal\n")
        os.exit(1)
    end
    tf:write("# Editando: " .. evento .. "\n")
    tf:write("# Formato: | fecha | tipo | evento | comentario | transcurrido |\n\n")
    for _, e in ipairs(entries) do
        if e.evento == evento then
            tf:write(string.format("| %s | %s | %s | %s | %s |\n",
                e.fecha, e.tipo, e.evento, e.comentario, e.transcurrido))
        end
    end
    tf:close()
    os.execute(EDITOR .. " " .. tmp)

    local new_entries = {}
    tf = io.open(tmp, "r")
    if tf then
        for line in tf:lines() do
            if line:match("^|") and not line:match("^| #") and not line:match("^| %-%-%-") and not line:match("^| Editando") and not line:match("^| Formato") then
                local fields = {}
                for field in (line .. "|"):gmatch("([^|]*)|") do
                    fields[#fields + 1] = trim(field)
                end
                if #fields >= 7 and fields[2] ~= "" then
                    new_entries[#new_entries + 1] = {
                        fecha        = fields[2],
                        tipo         = fields[3],
                        evento       = fields[4],
                        comentario   = fields[5],
                        transcurrido = fields[6],
                    }
                end
            end
        end
        tf:close()
    end

    local result = {}
    local replaced = false
    for _, e in ipairs(entries) do
        if e.evento ~= evento then
            result[#result + 1] = e
        elseif not replaced then
            for _, ne in ipairs(new_entries) do
                result[#result + 1] = ne
            end
            replaced = true
        end
    end
    if not replaced then
        for _, ne in ipairs(new_entries) do
            result[#result + 1] = ne
        end
    end
    table.sort(result, function(a, b) return a.fecha < b.fecha end)
    write_md(result)
    print("Editado: " .. evento)
end

-- ===== MAIN con argumentos estilo Unix + atajo rápido (CORREGIDO) =====
local function main(...)
    local args = {...}
    local f = io.open(RUTA, "r")
    if not f then
        io.stderr:write("Error: no se puede abrir: " .. RUTA .. "\n")
        io.stderr:write("HOME=" .. (os.getenv("HOME") or "(nil)") .. "\n")
        os.exit(1)
    end
    f:close()

    if #args == 0 then
        local entries = parse_md()
        listar(entries)
        return
    end

    -- Expandir opciones largas
    local function expand_option(arg)
        if arg == "--help" then return "-h" end
        if arg == "--list" then return "-l" end
        if arg == "--edit" then return "-e" end
        if arg == "--add" then return "-a" end
        if arg == "--delete" then return "-d" end
        if arg == "--delete-all" then return "-D" end
        return arg
    end

    local first = expand_option(args[1])
    local entries = parse_md()

    -- Opciones con guión
    if first == "-h" then
        mostrar_ayuda()
    elseif first == "-l" then
        listar(entries)
    elseif first == "-e" then
        if #args < 2 then
            print("Error: falta el nombre del evento")
            mostrar_ayuda()
            os.exit(1)
        end
        editar_evento(entries, args[2])
    elseif first == "-a" then
        if #args < 3 then
            print("Error: uso: bit -a <evento> <comentario>")
            os.exit(1)
        end
        agregar(entries, args[2], table.concat(args, " ", 3))
    elseif first == "-d" then
        if #args < 2 then
            print("Error: falta el nombre del evento")
            os.exit(1)
        end
        borrar_ultima(entries, args[2])
    elseif first == "-D" then
        if #args < 2 then
            print("Error: falta el nombre del evento")
            os.exit(1)
        end
        borrar_todo(entries, args[2])
    else
        -- Sin opción: puede ser "bit evento" (mostrar) o "bit evento comentario" (añadir rápido)
        local evento = args[1]
        if #args == 1 then
            -- Mostrar evento
            local matching = eventos_con_prefijo(entries, evento)
            if #matching == 0 then
                print("No existe ninguna bitácora que empiece por '" .. evento .. "'")
                os.exit(1)
            elseif #matching > 1 then
                print("Bitácoras que coinciden con '" .. evento .. "':")
                for _, ev in ipairs(matching) do
                    print("  - " .. ev)
                end
            else
                mostrar_evento(entries, matching[1])
            end
        else
            -- Añadir rápido: bit evento comentario...
            local comentario = table.concat(args, " ", 2)
            agregar(entries, evento, comentario)
        end
    end
end

-- Ejecutar
main(...)
