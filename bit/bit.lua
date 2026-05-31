#!/usr/bin/env luajit
-- bit.lua — bitácoras en bits/Grupo/evento.md

-- ===== CONFIG =====
local BASE   = "~/Documentos/Filen/Obsidian/bits"
local EDITOR = "micro"

-- ===== ANSI =====
local _is_tty = io.open("/dev/tty", "r") ~= nil and os.execute("test -t 1") == 0

local function ansi(code)
    return _is_tty and ("\27["..code.."m") or ""
end

local RST  = ansi("0")
local BOLD = ansi("1")
local B    = BOLD
local R    = RST

local C = {
    abbrev = ansi("38;5;99"),   -- púrpura: abreviatura de grupo
    header = ansi("38;5;99"),   -- púrpura: encabezado ## Grupo / evento
    plus   = ansi("38;5;99"),   -- púrpura: signo + en add
    event  = ansi("38;5;35"),   -- teal: nombre de evento
    route  = ansi("38;5;35"),   -- teal: ruta Grupo/evento
    inicio = ansi("38;5;35"),   -- teal: "inicio" en transcurrido
    long   = ansi("38;5;166"),  -- coral: tiempo >= 1 día
    minus  = ansi("38;5;166"),  -- coral: signo - en rm/pop
    tree   = ansi("38;5;102"),  -- gris: ramas del árbol
    count  = ansi("38;5;102"),  -- gris: conteo (N)
    sep    = ansi("38;5;102"),  -- gris: separadores |
    date   = ansi("38;5;102"),  -- gris: fechas
}

-- ===== UTILS =====
local function expand(path)
    if path:sub(1,1) == "~" then
        return (os.getenv("HOME") or "") .. path:sub(2)
    end
    return path
end

BASE = expand(BASE)

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function leer()
    local line = io.read()
    if line == nil then print("\nCancelado"); os.exit(0) end
    return trim(line)
end

local function titulo(s)
    if not s or s == "" then return s end
    return s:sub(1,1):upper() .. s:sub(2)
end

local function normalize(str)
    local result = str:gsub("[^%w%s%páéíóúüñÁÉÍÓÚÜÑ]", "")
    local accents = {
        ['á']='a',['é']='e',['í']='i',['ó']='o',['ú']='u',['ü']='u',['ñ']='n',
        ['Á']='A',['É']='E',['Í']='I',['Ó']='O',['Ú']='U',['Ü']='U',['Ñ']='N',
    }
    for acc, asc in pairs(accents) do result = result:gsub(acc, asc) end
    return trim(result:lower():gsub("%s+", " "))
end

local function now_ts()
    return os.date("%Y-%m-%d %H:%M")
end

local function mkdirs(path)
    os.execute('mkdir -p "' .. path .. '"')
end

local function ls(path)
    local result = {}
    local p = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
    if not p then return result end
    for line in p:lines() do result[#result+1] = line end
    p:close()
    return result
end

local function is_dir(path)
    local p = io.popen('[ -d "' .. path .. '" ] && echo yes 2>/dev/null')
    if not p then return false end
    local out = trim(p:read("*a")); p:close()
    return out == "yes"
end

local function is_file(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

-- ===== TRASH =====
local TRASH_CMD = nil
local function get_trash_cmd()
    if TRASH_CMD then return TRASH_CMD end
    for _, cmd in ipairs({"trash-put", "gio trash", "trash"}) do
        local p = io.popen('command -v ' .. cmd:match("^%S+") .. ' 2>/dev/null')
        if p then
            local out = trim(p:read("*a")); p:close()
            if out ~= "" then TRASH_CMD = cmd; return cmd end
        end
    end
    TRASH_CMD = 'mv -t ~/.Trash'
    return TRASH_CMD
end

local function trash(path)
    os.execute(get_trash_cmd() .. ' "' .. path .. '"')
end

-- ===== TIEMPO =====
local function ts_to_epoch(ts)
    if not ts then return nil end
    local y,mo,d,h,mi = ts:match("(%d%d%d%d)-(%d%d)-(%d%d)%s+(%d%d):(%d%d)")
    if not y then return nil end
    local cmd = string.format(
        'date -d "%s-%s-%s %s:%s:00" +%%s 2>/dev/null || '..
        'date -j -f "%%Y-%%m-%%d %%H:%%M:%%S" "%s-%s-%s %s:%s:00" +%%s 2>/dev/null',
        y,mo,d,h,mi, y,mo,d,h,mi)
    local p = io.popen(cmd)
    if not p then return nil end
    local out = trim(p:read("*a")); p:close()
    return tonumber(out)
end

local function fmt_diff(secs)
    if not secs or secs < 0 then return "?" end
    local total_min = math.floor(secs / 60)
    if total_min == 0 then return "0m" end
    local d = math.floor(total_min / 1440)
    local h = math.floor((total_min % 1440) / 60)
    local m = total_min % 60
    local s = ""
    if d > 0 then s = s..d.."d" end
    if h > 0 then s = s..h.."h" end
    if m > 0 then s = s..m.."m" end
    return s == "" and "0m" or s
end

local function fmt_diff_colored(secs)
    local s = fmt_diff(secs)
    if not secs or secs < 0 then return C.tree..s..RST end
    if secs >= 86400 then return C.long..s..RST end
    return s
end

-- ===== ABREVIATURAS =====
local function calc_abreviaturas(nombres)
    local abbrevs = {}
    local taken   = {}

    for _, nombre in ipairs(nombres) do
        local lower = nombre:lower()
        local found = false
        for start = 1, #lower - 1 do
            local ab = lower:sub(start, start+1)
            if not taken[ab] then
                taken[ab]      = nombre
                abbrevs[nombre] = ab
                found = true
                break
            end
        end
        if not found then
            abbrevs[nombre] = lower:sub(1,2)
        end
    end
    return abbrevs
end

local function fmt_grupo_con_abbrev(nombre, abbrev)
    local resto = nombre:sub(#abbrev+1)
    return C.abbrev .. abbrev .. RST .. resto
end

-- ===== PATHS =====
local function grupo_path(grupo)       return BASE.."/"..grupo end
local function evento_path(grupo, ev)  return BASE.."/"..grupo.."/"..ev..".md" end

local find_grupo

local function parse_arg(arg)
    if not arg then return nil, nil end
    local g, ev = arg:match("^([^/]+)/(.+)$")
    if g then
        local resuelto = find_grupo(g) or titulo(g)
        return resuelto, ev
    end
    local solo_g = arg:match("^([^/]+)/$")
    if solo_g then
        local resuelto = find_grupo(solo_g) or titulo(solo_g)
        return resuelto, nil
    end
    return nil, arg
end

-- ===== SCAN =====
local function get_grupos()
    local result = {}
    for _, name in ipairs(ls(BASE)) do
        if is_dir(grupo_path(name)) then result[#result+1] = titulo(name) end
    end
    table.sort(result, function(a,b) return a:lower() < b:lower() end)
    return result
end

local function get_eventos(grupo)
    local result = {}
    for _, name in ipairs(ls(grupo_path(grupo))) do
        if name:match("%.md$") then
            result[#result+1] = name:gsub("%.md$","")
        end
    end
    table.sort(result, function(a,b) return a:lower() < b:lower() end)
    return result
end

find_grupo = function(grupo_str)
    local norm = normalize(grupo_str)
    for _, g in ipairs(get_grupos()) do
        if normalize(g) == norm then return g end
    end
    local grupos = get_grupos()
    local abbrevs = calc_abreviaturas(grupos)
    for _, g in ipairs(grupos) do
        if abbrevs[g] == norm then return g end
    end
    return nil
end

local function find_evento(ev_str)
    local norm = normalize(ev_str)
    local found = {}
    for _, grupo in ipairs(get_grupos()) do
        for _, ev in ipairs(get_eventos(grupo)) do
            if normalize(ev) == norm then
                found[#found+1] = {grupo=grupo, evento=ev}
            end
        end
    end
    return found
end

-- ===== READ / WRITE =====
local function read_evento(grupo, evento)
    local lines = {}
    local f = io.open(evento_path(grupo, evento), "r")
    if not f then return lines end
    for line in f:lines() do
        local fecha, comentario = line:match("^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d)%s+(.+)$")
        if fecha then
            lines[#lines+1] = {fecha=fecha, comentario=comentario, raw=line}
        end
    end
    f:close()
    return lines
end

local function write_evento(grupo, evento, lines)
    local f = io.open(evento_path(grupo, evento), "w")
    if not f then
        io.stderr:write("Error: no se pudo escribir "..evento_path(grupo,evento).."\n")
        os.exit(1)
    end
    for _, l in ipairs(lines) do f:write(l.raw.."\n") end
    f:close()
end

local function insert_sorted(lines, new_line)
    local epoch_new = ts_to_epoch(new_line.fecha)
    local pos = #lines + 1
    if epoch_new then
        for i, l in ipairs(lines) do
            local e = ts_to_epoch(l.fecha)
            if e and e > epoch_new then pos = i; break end
        end
    end
    table.insert(lines, pos, new_line)
    return lines
end

-- ===== DISPLAY =====
local function print_evento_tabla(grupo, evento)
    local lines = read_evento(grupo, evento)
    if #lines == 0 then print("  (sin entradas)"); return end
    print("| # | Fecha | Comentario | Transcurrido |")
    print("| --- | --- | --- | --- |")
    for i, l in ipairs(lines) do
        local secs = nil
        local transcurrido_str
        if i == 1 then
            transcurrido_str = C.inicio.."inicio"..RST
        else
            local e1 = ts_to_epoch(lines[i-1].fecha)
            local e2 = ts_to_epoch(l.fecha)
            if e1 and e2 then
                secs = e2 - e1
                transcurrido_str = fmt_diff_colored(secs)
            else
                transcurrido_str = "?"
            end
        end
        local comentario = l.comentario:gsub("|", "\\|")
        print(string.format("| %s%d%s | %s%s%s | %s | %s |",
            C.tree, i, RST,
            C.date, l.fecha, RST,
            comentario,
            transcurrido_str))
    end
end

local function print_resumen()
    local grupos = get_grupos()
    if #grupos == 0 then print("No hay entradas"); return end
    local abbrevs = calc_abreviaturas(grupos)

    for gi, grupo in ipairs(grupos) do
        local evs    = get_eventos(grupo)
        local is_last_grupo = gi == #grupos
        local branch_grupo  = is_last_grupo and "└── " or "├── "
        local abbrev = abbrevs[grupo] or grupo:sub(1,2):lower()
        print(C.tree..branch_grupo..RST .. fmt_grupo_con_abbrev(grupo, abbrev) .. C.tree.."/"..RST)

        local prefix_grupo = is_last_grupo and "    " or "│   "
        for ei, ev in ipairs(evs) do
            local is_last_ev = ei == #evs
            local branch_ev  = is_last_ev and "└── " or "├── "
            local lines      = read_evento(grupo, ev)
            local count      = #lines
            local ultima     = count > 0 and lines[count].fecha or "-"
            -- construir sin mezclar ANSI con %s para no romper espacios
            local prefijo = C.tree..prefix_grupo..branch_ev..RST
            local ev_c    = C.event..ev..RST
            local cnt_c   = C.count..'('..count..')'..RST
            local ult_c   = C.date..ultima..RST
            print(prefijo..ev_c..'  '..cnt_c..'  '..ult_c)
        end
    end
end

local function print_arbol_compacto(grupos_filter)
    local grupos  = grupos_filter or get_grupos()
    if #grupos == 0 then print("  (vacío)"); return end
    local abbrevs = calc_abreviaturas(grupos)
    for gi, grupo in ipairs(grupos) do
        local is_last_g = gi == #grupos
        local branch_g  = is_last_g and "└── " or "├── "
        local prefix_g  = is_last_g and "    " or "│   "
        local ab        = abbrevs[grupo] or grupo:sub(1,2):lower()
        print(C.tree..branch_g..RST .. fmt_grupo_con_abbrev(grupo, ab) .. C.tree.."/"..RST)
        local evs = get_eventos(grupo)
        for ei, ev in ipairs(evs) do
            local is_last_e = ei == #evs
            local branch_e  = is_last_e and "└── " or "├── "
            print(C.tree..prefix_g..branch_e..RST .. C.event..ev..RST)
        end
    end
end

local function pedir_grupo(prompt)
    local grupos  = get_grupos()
    local abbrevs = calc_abreviaturas(grupos)
    while true do
        io.write((prompt or "Grupo").." (? = listar): ")
        io.flush()
        local input = leer()
        if input == "?" then
            if #grupos == 0 then print("No hay grupos previos.")
            else print_arbol_compacto(grupos) end
        else
            local n = tonumber(input)
            if n and grupos[n] then return grupos[n] end
            local found = find_grupo(input)
            if found then return found end
            if input ~= "" then return titulo(input) end
        end
    end
end

local function pedir_evento_interactivo(grupo, prompt)
    local evs = grupo and get_eventos(grupo) or {}
    while true do
        local p = prompt or ("Evento"..(grupo and " en "..grupo or ""))
        io.write(p.." (? = listar): ")
        io.flush()
        local input = leer()
        if input == "?" then
            if #evs == 0 then print("No hay eventos.")
            else print_arbol_compacto({grupo}) end
        else
            local n = tonumber(input)
            if n and evs[n] then return evs[n] end
            if input ~= "" then return input end
        end
    end
end

local function resolver_grupo(ev_str, found)
    if #found == 1 then
        return found[1].grupo, found[1].evento
    elseif #found > 1 then
        local grupos_found = {}
        for _, f in ipairs(found) do grupos_found[#grupos_found+1] = f.grupo end
        local abbrevs = calc_abreviaturas(grupos_found)
        while true do
            print("'"..ev_str.."' existe en varios grupos:")
            print_arbol_compacto(grupos_found)
            io.write("Elige número, nombre o abreviatura: "); io.flush()
            local input = leer()
            local n = tonumber(input)
            if n and found[n] then return found[n].grupo, found[n].evento end
            if input ~= "" then
                local norm = normalize(input)
                for _, f in ipairs(found) do
                    local ab = abbrevs[f.grupo] or f.grupo:sub(1,2):lower()
                    if normalize(f.grupo) == norm or ab == norm then
                        return f.grupo, f.evento
                    end
                end
            end
            print("Opción inválida, intenta de nuevo.")
        end
    else
        local grupo = pedir_grupo("Grupo para '"..ev_str.."'")
        return grupo, ev_str
    end
end

local function resolver_arg(arg)
    local g_arg, e_arg = parse_arg(arg)
    if g_arg and e_arg then
        return g_arg, e_arg
    elseif e_arg then
        local found = find_evento(e_arg)
        return resolver_grupo(e_arg, found)
    end
    return nil, nil
end

-- ===== COMANDOS =====
local function cmd_add(args)
    local grupo, evento, comentario

    if #args == 0 then
        grupo      = pedir_grupo("Grupo")
        evento     = pedir_evento_interactivo(grupo)
        io.write("Comentario: "); io.flush()
        comentario = leer()
    else
        local g_arg, e_arg = parse_arg(args[1])
        if g_arg and e_arg then
            grupo = g_arg; evento = e_arg
        elseif e_arg then
            local found = find_evento(e_arg)
            grupo, evento = resolver_grupo(e_arg, found)
        end
        comentario = #args > 1 and trim(table.concat(args, " ", 2)) or nil
        if not comentario or comentario == "" then
            io.write("Comentario: "); io.flush()
            comentario = leer()
        end
    end

    if comentario == "" then print("Comentario vacío, cancelado"); return end

    mkdirs(grupo_path(grupo))
    local path  = evento_path(grupo, evento)
    local lines = read_evento(grupo, evento)
    local ts    = now_ts()

    local transcurrido = "inicio"
    local secs_diff = nil
    if #lines > 0 then
        local e1 = ts_to_epoch(lines[#lines].fecha)
        local e2 = ts_to_epoch(ts)
        if e1 and e2 then
            secs_diff = e2 - e1
            transcurrido = fmt_diff(secs_diff)
        end
    end

    local trans_colored
    if transcurrido == "inicio" then
        trans_colored = C.inicio.."inicio"..RST
    elseif secs_diff and secs_diff >= 86400 then
        trans_colored = C.long..transcurrido..RST
    else
        trans_colored = transcurrido
    end

    local f = io.open(path, "a")
    if not f then io.stderr:write("Error: no se pudo abrir "..path.."\n"); os.exit(1) end
    f:write(ts.." "..comentario.."\n"); f:close()

    print(string.format("%s+%s %s%s%s %s|%s %s%s/%s%s %s|%s %s %s|%s %s",
        C.plus, RST,
        C.date, ts, RST,
        C.sep, RST,
        C.route, grupo, evento, RST,
        C.sep, RST,
        trans_colored,
        C.sep, RST,
        comentario))
end

local function cmd_edit(args)
    local grupo, evento
    if #args == 0 then
        grupo  = pedir_grupo("Grupo")
        evento = pedir_evento_interactivo(grupo)
    else
        grupo, evento = resolver_arg(args[1])
    end
    local path = evento_path(grupo, evento)
    if not is_file(path) then
        mkdirs(grupo_path(grupo))
        local f = io.open(path, "w"); if f then f:close() end
    end
    os.execute(EDITOR..' "'..path..'"')
end

local function cmd_rm(args)
    local grupo, evento, n
    if #args == 0 then
        grupo  = pedir_grupo("Grupo")
        evento = pedir_evento_interactivo(grupo)
    else
        grupo, evento = resolver_arg(args[1])
        n = tonumber(args[2])
    end

    local lines = read_evento(grupo, evento)
    if #lines == 0 then print("No hay entradas en "..grupo.."/"..evento); return end

    while not n or n < 1 or n > #lines do
        print_evento_tabla(grupo, evento)
        io.write("Número de línea a borrar: "); io.flush()
        n = tonumber(leer())
        if n and (n < 1 or n > #lines) then
            print(string.format("Número %d fuera de rango (1-%d)", n, #lines))
            n = nil
        end
    end

    local removed = table.remove(lines, n)
    write_evento(grupo, evento, lines)
    print(string.format("%s-%s %s%s%s %s|%s %s",
        C.minus, RST,
        C.date, removed.fecha, RST,
        C.sep, RST,
        removed.comentario))
end

local function cmd_pop(args)
    local grupo, evento
    if #args == 0 then
        grupo  = pedir_grupo("Grupo")
        evento = pedir_evento_interactivo(grupo)
    else
        grupo, evento = resolver_arg(args[1])
    end
    local lines = read_evento(grupo, evento)
    if #lines == 0 then print("No hay entradas en "..grupo.."/"..evento); return end
    local removed = table.remove(lines, #lines)
    write_evento(grupo, evento, lines)
    print(string.format("%s-%s %s%s%s %s|%s %s",
        C.minus, RST,
        C.date, removed.fecha, RST,
        C.sep, RST,
        removed.comentario))
end

local function cmd_del(args)
    if #args == 0 then
        io.write("Borrar Grupo/ o evento: "); io.flush()
        local input = leer()
        if input == "" then print("Cancelado"); return end
        args = {input}
    end

    local g_arg, e_arg = parse_arg(args[1])

    if g_arg and not e_arg then
        local grupo = find_grupo(g_arg) or g_arg
        local gp    = grupo_path(grupo)
        if not is_dir(gp) then print("No existe el grupo '"..grupo.."'"); return end
        print_arbol_compacto({grupo})
        io.write("Enviar al trash el grupo '"..grupo.."' y todo su contenido? (s/n): ")
        io.flush()
        if leer() ~= "s" then print("Cancelado"); return end
        trash(gp)
        print("Enviado al trash: "..grupo.."/")
    else
        local grupo, evento
        if g_arg and e_arg then
            grupo  = g_arg
            evento = e_arg
        else
            local found = find_evento(e_arg)
            if #found > 0 then
                grupo, evento = resolver_grupo(e_arg, found)
            else
                local g = find_grupo(e_arg)
                if g then
                    local gp = grupo_path(g)
                    print_arbol_compacto({g})
                    io.write("Enviar al trash el grupo '"..g.."' y todo su contenido? (s/n): ")
                    io.flush()
                    if leer() ~= "s" then print("Cancelado"); return end
                    trash(gp)
                    print("Enviado al trash: "..g.."/")
                    return
                else
                    print("No existe evento ni grupo '"..e_arg.."'"); return
                end
            end
        end
        local path = evento_path(grupo, evento)
        if not is_file(path) then print("No existe "..path); return end
        io.write("Enviar al trash '"..grupo.."/"..evento.."'? (s/n): ")
        io.flush()
        if leer() ~= "s" then print("Cancelado"); return end
        trash(path)
        print("Enviado al trash: "..grupo.."/"..evento)
    end
end

local function resolver_grupo_destino(input, ev_orig)
    if input == "" then return nil end
    local sin_slash = input:gsub("/$", "")
    local g = find_grupo(sin_slash)
    if g then return g end
    print("No se reconoce '"..input.."' como grupo.")
    return pedir_grupo("Grupo destino")
end

local function cmd_mv(args)
    local grupo_orig, ev_orig, n, grupo_dest

    if #args == 0 then
        grupo_orig = pedir_grupo("Grupo origen")
        ev_orig    = pedir_evento_interactivo(grupo_orig, "Evento origen")
        local lines = read_evento(grupo_orig, ev_orig)
        if #lines == 0 then print("No hay entradas en "..grupo_orig.."/"..ev_orig); return end
        print_evento_tabla(grupo_orig, ev_orig)
        io.write("Número de línea a mover: "); io.flush()
        n = tonumber(leer())
        while true do
            io.write("Grupo destino (nombre, abreviatura o ?, Grupo/): "); io.flush()
            local input = leer()
            if input == "?" then
                print_arbol_compacto()
            elseif input ~= "" then
                grupo_dest = resolver_grupo_destino(input, ev_orig)
                if grupo_dest then break end
            end
        end
    elseif #args == 1 then
        grupo_orig, ev_orig = resolver_arg(args[1])
        local lines = read_evento(grupo_orig, ev_orig)
        if #lines == 0 then print("No hay entradas en "..grupo_orig.."/"..ev_orig); return end
        print_evento_tabla(grupo_orig, ev_orig)
        io.write("Número de línea a mover (enter = cancelar): "); io.flush()
        local input_n = leer()
        if input_n == "" then return end
        n = tonumber(input_n)
        if not n then print("Número inválido"); return end
        while true do
            io.write("Grupo destino (nombre, abreviatura o ?, Grupo/): "); io.flush()
            local input = leer()
            if input == "?" then
                print_arbol_compacto()
            elseif input ~= "" then
                grupo_dest = resolver_grupo_destino(input, ev_orig)
                if grupo_dest then break end
            end
        end
    elseif #args >= 3 then
        grupo_orig, ev_orig = resolver_arg(args[1])
        n = tonumber(args[2])
        if not n then print("Error: uso: bit mv [Grupo/]evento N Grupo_dest"); return end
        grupo_dest = resolver_grupo_destino(args[3], ev_orig)
        if not grupo_dest then return end
    else
        print("Error: uso: bit mv [Grupo/]evento N Grupo_dest"); return
    end

    if not n then print("Número inválido"); return end
    local lines_orig = read_evento(grupo_orig, ev_orig)
    if #lines_orig == 0 then print("No hay entradas en "..grupo_orig.."/"..ev_orig); return end
    if n < 1 or n > #lines_orig then
        print(string.format("Número %d fuera de rango (1-%d)", n, #lines_orig)); return
    end

    local moved = table.remove(lines_orig, n)
    write_evento(grupo_orig, ev_orig, lines_orig)
    mkdirs(grupo_path(grupo_dest))
    local lines_dest = read_evento(grupo_dest, ev_orig)
    lines_dest = insert_sorted(lines_dest, moved)
    write_evento(grupo_dest, ev_orig, lines_dest)
    print(string.format("~ %s%s/%s%s #%d → %s%s/%s%s | %s",
        C.route, grupo_orig, ev_orig, RST,
        n,
        C.route, grupo_dest, ev_orig, RST,
        moved.comentario))
end

local function cmd_dir(args)
    local grupo_orig, ev_orig, grupo_dest, ev_dest

    if #args == 0 then
        grupo_orig = pedir_grupo("Grupo origen")
        ev_orig    = pedir_evento_interactivo(grupo_orig, "Evento a mover")
        grupo_dest = pedir_grupo("Grupo destino")
        io.write("Nombre en destino (enter = mismo): "); io.flush()
        local input = leer()
        ev_dest = input ~= "" and input or ev_orig
    elseif #args == 1 then
        grupo_orig, ev_orig = resolver_arg(args[1])
        grupo_dest = pedir_grupo("Grupo destino")
        ev_dest    = ev_orig
    elseif #args >= 2 then
        grupo_orig, ev_orig = resolver_arg(args[1])
        local g_arg, e_arg = parse_arg(args[2])
        if g_arg and e_arg then
            grupo_dest = g_arg; ev_dest = e_arg
        elseif g_arg then
            grupo_dest = g_arg; ev_dest = ev_orig
        elseif e_arg then
            grupo_dest = e_arg; ev_dest = ev_orig
        end
    end

    local src  = evento_path(grupo_orig, ev_orig)
    local dest = evento_path(grupo_dest, ev_dest)
    if not is_file(src) then print("No existe "..src); return end
    if src == dest then print("Origen y destino son iguales"); return end
    if is_file(dest) then
        io.write("Ya existe "..grupo_dest.."/"..ev_dest..", sobreescribir? (s/n): ")
        io.flush()
        if leer() ~= "s" then print("Cancelado"); return end
    end
    mkdirs(grupo_path(grupo_dest))
    os.execute('mv "'..src..'" "'..dest..'"')
    -- limpiar grupo origen si quedó sin archivos .md
    local gp_orig = grupo_path(grupo_orig)
    local tiene_md = false
    local p = io.popen('ls -1 "'..gp_orig..'"/*.md 2>/dev/null | head -1')
    if p then local out = trim(p:read('*a')); p:close(); tiene_md = out ~= '' end
    local sufijo = ''
    if not tiene_md and is_dir(gp_orig) then
        os.execute('rmdir "'..gp_orig..'"')
        sufijo = '  '..C.tree..'('..grupo_orig..'/ eliminado)'..RST
    end
    print(string.format('dir: %s%s/%s%s → %s%s/%s%s',
        C.route, grupo_orig, ev_orig, RST,
        C.route, grupo_dest, ev_dest, RST)..sufijo)
end

local function cmd_listar_evento(ev_str)
    local g_arg, e_arg = parse_arg(ev_str)
    if g_arg and e_arg then
        print("\n"..C.header.."## "..g_arg.." / "..e_arg..RST.."\n")
        print_evento_tabla(g_arg, e_arg)
        return
    end
    local found = find_evento(ev_str)
    if #found == 0 then
        print("No existe ninguna bitácora con el evento '"..ev_str.."'")
        return
    end
    for _, f in ipairs(found) do
        print("\n"..C.header.."## "..f.grupo.." / "..f.evento..RST.."\n")
        print_evento_tabla(f.grupo, f.evento)
    end
end

local function cmd_import(archivo)
    local f = io.open(expand(archivo), "r")
    if not f then
        io.stderr:write("Error: no se puede abrir "..archivo.."\n"); os.exit(1)
    end
    local count = 0
    for line in f:lines() do
        if line:match("^|") then
            local fields = {}
            for field in (line.."|"):gmatch("([^|]*)|") do
                fields[#fields+1] = trim(field)
            end
            if #fields >= 7 and fields[2]:match("^%d%d%d%d%-%d%d%-%d%d") then
                local fecha      = fields[2]
                local grupo_str  = titulo(fields[3])
                local ev_str     = fields[4]
                local comentario = fields[5]
                if grupo_str ~= "Tipo" and grupo_str ~= "Grupo" and ev_str ~= "Evento" then
                    mkdirs(grupo_path(grupo_str))
                    local path = evento_path(grupo_str, ev_str)
                    local ef = io.open(path, "a")
                    if ef then ef:write(fecha.." "..comentario.."\n"); ef:close() end
                    count = count + 1
                end
            end
        end
    end
    f:close()
    print(string.format("Importadas %d entradas desde %s", count, archivo))
end

local function mostrar_ayuda()
    print(
        C.header.."bit"..RST.." — bitácoras en bits/Grupo/evento.md\n"..
        "\n"..
        "  bit                            resumen en árbol\n"..
        "  bit <evento>                   listar entradas\n"..
        "  bit <evento> <comentario>      añadir entrada (atajo de add)\n"..
        "\n"..
        "  "..C.plus.."add"..RST.." [Grupo/][evento] [comentario]       añadir entrada\n"..
        "  a                                       alias de add\n"..
        "  edit [Grupo/][evento]                   abrir archivo en "..EDITOR.."\n"..
        "  e                                       alias de edit\n"..
        "  "..C.minus.."rm"..RST.."  [Grupo/]evento [N]                   borrar línea N\n"..
        "  pop [Grupo/]evento                      borrar última línea\n"..
        "  del Grupo/                              enviar grupo al trash (confirma)\n"..
        "  del [Grupo/]evento                      enviar evento al trash (confirma)\n"..
        "  mv  [Grupo/]evento N [Grupo/]ev_dest    mover línea N a otro evento\n"..
        "  mv  [Grupo/]evento                      listar líneas numeradas\n"..
        "  dir [Grupo/]evento [Grupo/][evento]     mover archivo completo a otro grupo\n"..
        "  import <archivo.md>                     importar desde bits.md anterior\n"..
        "  help, h                                 esta ayuda\n"..
        "\n"..
        C.tree.."Grupo/evento"..RST..": si se omite Grupo/ se busca automáticamente.\n"..
        C.tree.."Grupos"..RST..": referenciables por nombre, número o "..C.abbrev.."ab"..RST.."reviatura (2 letras).\n"..
        "Sin argumentos en cualquier comando: modo interactivo."
    )
end

-- ===== MAIN =====
local function main(...)
    local args = {...}
    mkdirs(BASE)

    if #args == 0 then print_resumen(); return end

    local cmd  = args[1]
    local rest = {}
    for i = 2, #args do rest[#rest+1] = args[i] end

    if     cmd == "a"    or cmd == "add"  then cmd_add(rest)
    elseif cmd == "e"    or cmd == "edit" then cmd_edit(rest)
    elseif cmd == "rm"                    then cmd_rm(rest)
    elseif cmd == "pop"                   then cmd_pop(rest)
    elseif cmd == "del"                   then cmd_del(rest)
    elseif cmd == "mv"                    then cmd_mv(rest)
    elseif cmd == "dir"                   then cmd_dir(rest)
    elseif cmd == "import"                then
        if #rest < 1 then print("Error: uso: bit import <archivo.md>"); os.exit(1) end
        cmd_import(rest[1])
    elseif cmd == "h"    or cmd == "help" then mostrar_ayuda()
    elseif #args == 1                     then cmd_listar_evento(cmd)
    else                                       cmd_add(args)
    end
end

local ok, err = pcall(main, ...)
if not ok then
    if err and err:match("interrupted") then
        print("\nCancelado")
        os.exit(0)
    else
        io.stderr:write(tostring(err).."\n")
        os.exit(1)
    end
end
