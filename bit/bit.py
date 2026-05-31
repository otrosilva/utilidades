#!/usr/bin/env python3
# bit.py — bitácoras en bits/Grupo/evento.md

# ===== CONFIG =====
BASE   = "~/Documentos/Filen/Obsidian/bits"
EDITOR = "micro"

# ===== STDLIB =====
import sys
import os
import re
import shutil
import unicodedata
from pathlib import Path
from datetime import datetime

# ===== ANSI =====
_is_tty = sys.stdout.isatty()

def ansi(code):
    return f"\033[{code}m" if _is_tty else ""

RST  = ansi("0")
BOLD = ansi("1")

C = {
    "abbrev": ansi("38;5;99"),   # púrpura: abreviatura de grupo
    "header": ansi("38;5;99"),   # púrpura: encabezado ## Grupo / evento
    "plus"  : ansi("38;5;99"),   # púrpura: signo + en add
    "event" : ansi("38;5;35"),   # teal: nombre de evento
    "route" : ansi("38;5;35"),   # teal: ruta Grupo/evento
    "inicio": ansi("38;5;35"),   # teal: "inicio" en transcurrido
    "long"  : ansi("38;5;166"),  # coral: tiempo >= 1 día
    "minus" : ansi("38;5;166"),  # coral: signo - en rm/pop
    "tree"  : ansi("38;5;102"),  # gris: ramas del árbol
    "count" : ansi("38;5;102"),  # gris: conteo (N)
    "sep"   : ansi("38;5;102"),  # gris: separadores |
    "date"  : ansi("38;5;102"),  # gris: fechas
}

# ===== UTILS =====
BASE = Path(BASE).expanduser()

def titulo(s):
    if not s:
        return s
    return s[0].upper() + s[1:]

def normalize(s):
    # descomponer unicode y quedarse solo con ASCII
    nfkd = unicodedata.normalize("NFKD", s)
    ascii_str = nfkd.encode("ascii", "ignore").decode("ascii")
    # quitar caracteres que no sean alfanuméricos ni espacios
    ascii_str = re.sub(r"[^\w\s]", "", ascii_str)
    return re.sub(r"\s+", " ", ascii_str).strip().lower()

def now_ts():
    return datetime.now().strftime("%Y-%m-%d %H:%M")

def leer(prompt=None):
    if prompt:
        print(prompt, end="", flush=True)
    try:
        line = input()
    except (EOFError, KeyboardInterrupt):
        print("\nCancelado")
        sys.exit(0)
    return line.strip()

# ===== TRASH =====
_trash_fn = None

def _find_trash_fn():
    global _trash_fn
    if _trash_fn is not None:
        return _trash_fn
    # 1. send2trash si está instalado (stdlib no incluye; omitimos)
    # 2. gio trash (GNOME)
    if shutil.which("gio"):
        def fn(p): os.system(f'gio trash "{p}"')
        _trash_fn = fn; return fn
    # 3. trash-put (trash-cli)
    if shutil.which("trash-put"):
        def fn(p): os.system(f'trash-put "{p}"')
        _trash_fn = fn; return fn
    # 4. trash (macOS homebrew)
    if shutil.which("trash"):
        def fn(p): os.system(f'trash "{p}"')
        _trash_fn = fn; return fn
    # 5. fallback: mover a ~/.Trash
    trash_dir = Path.home() / ".Trash"
    trash_dir.mkdir(exist_ok=True)
    def fn(p): shutil.move(str(p), str(trash_dir / Path(p).name))
    _trash_fn = fn; return fn

def trash(path):
    _find_trash_fn()(str(path))

# ===== TIEMPO =====
_TS_FMT = "%Y-%m-%d %H:%M"

def ts_to_dt(ts):
    try:
        return datetime.strptime(ts, _TS_FMT)
    except (ValueError, TypeError):
        return None

def fmt_diff(secs):
    if secs is None or secs < 0:
        return "?"
    total_min = int(secs // 60)
    if total_min == 0:
        return "0m"
    d = total_min // 1440
    h = (total_min % 1440) // 60
    m = total_min % 60
    s = ""
    if d: s += f"{d}d"
    if h: s += f"{h}h"
    if m: s += f"{m}m"
    return s or "0m"

def fmt_diff_colored(secs):
    s = fmt_diff(secs)
    if secs is None or secs < 0:
        return C["tree"] + s + RST
    if secs >= 86400:
        return C["long"] + s + RST
    return s

# ===== ABREVIATURAS =====
def calc_abreviaturas(nombres):
    abbrevs = {}
    taken   = {}
    for nombre in nombres:
        lower = nombre.lower()
        found = False
        for start in range(len(lower) - 1):
            ab = lower[start:start+2]
            if ab not in taken:
                taken[ab] = nombre
                abbrevs[nombre] = ab
                found = True
                break
        if not found:
            abbrevs[nombre] = lower[:2]
    return abbrevs

def fmt_grupo_con_abbrev(nombre, abbrev):
    resto = nombre[len(abbrev):]
    return C["abbrev"] + abbrev + RST + resto

# ===== PATHS =====
def grupo_path(grupo):
    return BASE / grupo

def evento_path(grupo, ev):
    return BASE / grupo / f"{ev}.md"

# ===== SCAN =====
def get_grupos():
    if not BASE.is_dir():
        return []
    result = [titulo(p.name) for p in sorted(BASE.iterdir()) if p.is_dir()]
    return sorted(result, key=lambda x: x.lower())

def get_eventos(grupo):
    gp = grupo_path(grupo)
    if not gp.is_dir():
        return []
    result = [p.stem for p in sorted(gp.iterdir()) if p.suffix == ".md"]
    return sorted(result, key=lambda x: x.lower())

def find_grupo(grupo_str):
    norm = normalize(grupo_str)
    grupos = get_grupos()
    for g in grupos:
        if normalize(g) == norm:
            return g
    abbrevs = calc_abreviaturas(grupos)
    for g in grupos:
        if abbrevs.get(g) == norm:
            return g
    return None

def find_evento(ev_str):
    norm = normalize(ev_str)
    found = []
    for grupo in get_grupos():
        for ev in get_eventos(grupo):
            if normalize(ev) == norm:
                found.append({"grupo": grupo, "evento": ev})
    return found

# ===== PARSE ARG =====
def parse_arg(arg):
    """'Grupo/evento' → (grupo, evento) | 'Grupo/' → (grupo, None) | 'evento' → (None, evento)"""
    if not arg:
        return None, None
    m = re.match(r"^([^/]+)/(.+)$", arg)
    if m:
        g, ev = m.group(1), m.group(2)
        return find_grupo(g) or titulo(g), ev
    m = re.match(r"^([^/]+)/$", arg)
    if m:
        g = m.group(1)
        return find_grupo(g) or titulo(g), None
    return None, arg

# ===== READ / WRITE =====
_LINE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(.+)$")

def read_evento(grupo, evento):
    path = evento_path(grupo, evento)
    lines = []
    if not path.is_file():
        return lines
    with path.open(encoding="utf-8") as f:
        for raw in f:
            raw = raw.rstrip("\n")
            m = _LINE_RE.match(raw)
            if m:
                lines.append({"fecha": m.group(1), "comentario": m.group(2), "raw": raw})
    return lines

def write_evento(grupo, evento, lines):
    path = evento_path(grupo, evento)
    try:
        with path.open("w", encoding="utf-8") as f:
            for l in lines:
                f.write(l["raw"] + "\n")
    except OSError as e:
        print(f"Error: no se pudo escribir {path}: {e}", file=sys.stderr)
        sys.exit(1)

def insert_sorted(lines, new_line):
    dt_new = ts_to_dt(new_line["fecha"])
    pos = len(lines)
    if dt_new:
        for i, l in enumerate(lines):
            dt = ts_to_dt(l["fecha"])
            if dt and dt > dt_new:
                pos = i
                break
    lines.insert(pos, new_line)
    return lines

# ===== DISPLAY =====
def print_evento_tabla(grupo, evento):
    lines = read_evento(grupo, evento)
    if not lines:
        print("  (sin entradas)")
        return
    print("| # | Fecha | Comentario | Transcurrido |")
    print("| --- | --- | --- | --- |")
    for i, l in enumerate(lines):
        if i == 0:
            trans_str = C["inicio"] + "inicio" + RST
        else:
            dt1 = ts_to_dt(lines[i-1]["fecha"])
            dt2 = ts_to_dt(l["fecha"])
            if dt1 and dt2:
                secs = (dt2 - dt1).total_seconds()
                trans_str = fmt_diff_colored(secs)
            else:
                trans_str = "?"
        comentario = l["comentario"].replace("|", "\\|")
        print(f"| {C['tree']}{i+1}{RST} | {C['date']}{l['fecha']}{RST} | {comentario} | {trans_str} |")

def _linea_grupo(branch, nombre, abbrev):
    """Línea de grupo: rama + abreviatura coloreada + resto + /"""
    resto = nombre[len(abbrev):]
    return (C["tree"] + branch + RST
            + C["abbrev"] + abbrev + RST
            + resto
            + C["tree"] + "/" + RST)

def _linea_evento(prefix, branch, ev, extra=""):
    """Línea de evento: prefijo + rama + nombre coloreado + extra ya formateado."""
    return C["tree"] + prefix + branch + RST + C["event"] + ev + RST + extra

def print_resumen():
    grupos = get_grupos()
    if not grupos:
        print("No hay entradas")
        return
    abbrevs = calc_abreviaturas(grupos)
    for gi, grupo in enumerate(grupos):
        evs       = get_eventos(grupo)
        is_last_g = gi == len(grupos) - 1
        branch_g  = "└── " if is_last_g else "├── "
        prefix_g  = "    " if is_last_g else "│   "
        abbrev    = abbrevs.get(grupo, grupo[:2].lower())
        print(_linea_grupo(branch_g, grupo, abbrev))
        for ei, ev in enumerate(evs):
            is_last_e = ei == len(evs) - 1
            branch_e  = "└── " if is_last_e else "├── "
            ev_lines  = read_evento(grupo, ev)
            count     = len(ev_lines)
            ultima    = ev_lines[-1]["fecha"] if ev_lines else "-"
            extra = (f"  {C['count']}({count}){RST}"
                     f"  {C['date']}{ultima}{RST}")
            print(_linea_evento(prefix_g, branch_e, ev, extra))

def print_arbol_compacto(grupos_filter=None):
    grupos = grupos_filter if grupos_filter is not None else get_grupos()
    if not grupos:
        print("  (vacío)")
        return
    abbrevs = calc_abreviaturas(grupos)
    for gi, grupo in enumerate(grupos):
        is_last_g = gi == len(grupos) - 1
        branch_g  = "└── " if is_last_g else "├── "
        prefix_g  = "    " if is_last_g else "│   "
        ab = abbrevs.get(grupo, grupo[:2].lower())
        print(_linea_grupo(branch_g, grupo, ab))
        evs = get_eventos(grupo)
        for ei, ev in enumerate(evs):
            is_last_e = ei == len(evs) - 1
            branch_e  = "└── " if is_last_e else "├── "
            print(_linea_evento(prefix_g, branch_e, ev))

# ===== INTERACTIVO =====
def pedir_grupo(prompt="Grupo"):
    grupos = get_grupos()
    while True:
        entrada = leer(f"{prompt} (? = listar): ")
        if entrada == "?":
            if not grupos:
                print("No hay grupos previos.")
            else:
                print_arbol_compacto(grupos)
        else:
            try:
                n = int(entrada)
                if 1 <= n <= len(grupos):
                    return grupos[n - 1]
            except ValueError:
                pass
            found = find_grupo(entrada)
            if found:
                return found
            if entrada:
                return titulo(entrada)

def pedir_evento_interactivo(grupo=None, prompt=None):
    evs = get_eventos(grupo) if grupo else []
    if prompt is None:
        prompt = "Evento" + (f" en {grupo}" if grupo else "")
    while True:
        entrada = leer(f"{prompt} (? = listar): ")
        if entrada == "?":
            if not evs:
                print("No hay eventos.")
            else:
                print_arbol_compacto([grupo] if grupo else None)
        else:
            try:
                n = int(entrada)
                if 1 <= n <= len(evs):
                    return evs[n - 1]
            except ValueError:
                pass
            if entrada:
                return entrada

def resolver_grupo(ev_str, found):
    if len(found) == 1:
        return found[0]["grupo"], found[0]["evento"]
    if len(found) > 1:
        grupos_found = [f["grupo"] for f in found]
        abbrevs = calc_abreviaturas(grupos_found)
        while True:
            print(f"'{ev_str}' existe en varios grupos:")
            print_arbol_compacto(grupos_found)
            entrada = leer("Elige número, nombre o abreviatura: ")
            try:
                n = int(entrada)
                if 1 <= n <= len(found):
                    return found[n-1]["grupo"], found[n-1]["evento"]
            except ValueError:
                pass
            if entrada:
                norm = normalize(entrada)
                for f in found:
                    ab = abbrevs.get(f["grupo"], f["grupo"][:2].lower())
                    if normalize(f["grupo"]) == norm or ab == norm:
                        return f["grupo"], f["evento"]
            print("Opción inválida, intenta de nuevo.")
    else:
        grupo = pedir_grupo(f"Grupo para '{ev_str}'")
        return grupo, ev_str

def resolver_arg(arg):
    g_arg, e_arg = parse_arg(arg)
    if g_arg and e_arg:
        return g_arg, e_arg
    if e_arg:
        found = find_evento(e_arg)
        return resolver_grupo(e_arg, found)
    return None, None

def resolver_grupo_destino(entrada, ev_orig=None):
    if not entrada:
        return None
    sin_slash = entrada.rstrip("/")
    g = find_grupo(sin_slash)
    if g:
        return g
    print(f"No se reconoce '{entrada}' como grupo.")
    return pedir_grupo("Grupo destino")

# ===== COMANDOS =====
def cmd_add(args):
    grupo = evento = comentario = None

    if not args:
        grupo      = pedir_grupo("Grupo")
        evento     = pedir_evento_interactivo(grupo)
        comentario = leer("Comentario: ")
    else:
        g_arg, e_arg = parse_arg(args[0])
        if g_arg and e_arg:
            grupo, evento = g_arg, e_arg
        elif e_arg:
            found = find_evento(e_arg)
            grupo, evento = resolver_grupo(e_arg, found)
        comentario = " ".join(args[1:]).strip() if len(args) > 1 else ""
        if not comentario:
            comentario = leer("Comentario: ")

    if not comentario:
        print("Comentario vacío, cancelado")
        return

    grupo_path(grupo).mkdir(parents=True, exist_ok=True)
    path  = evento_path(grupo, evento)
    lines = read_evento(grupo, evento)
    ts    = now_ts()

    transcurrido = "inicio"
    secs_diff    = None
    if lines:
        dt1 = ts_to_dt(lines[-1]["fecha"])
        dt2 = ts_to_dt(ts)
        if dt1 and dt2:
            secs_diff    = (dt2 - dt1).total_seconds()
            transcurrido = fmt_diff(secs_diff)

    if transcurrido == "inicio":
        trans_c = C["inicio"] + "inicio" + RST
    elif secs_diff is not None and secs_diff >= 86400:
        trans_c = C["long"] + transcurrido + RST
    else:
        trans_c = transcurrido

    with path.open("a", encoding="utf-8") as f:
        f.write(f"{ts} {comentario}\n")

    print(
        f"{C['plus']}+{RST} {C['date']}{ts}{RST} "
        f"{C['sep']}|{RST} {C['route']}{grupo}/{evento}{RST} "
        f"{C['sep']}|{RST} {trans_c} "
        f"{C['sep']}|{RST} {comentario}"
    )

def cmd_edit(args):
    if not args:
        grupo  = pedir_grupo("Grupo")
        evento = pedir_evento_interactivo(grupo)
    else:
        grupo, evento = resolver_arg(args[0])
    path = evento_path(grupo, evento)
    if not path.is_file():
        grupo_path(grupo).mkdir(parents=True, exist_ok=True)
        path.touch()
    os.system(f'{EDITOR} "{path}"')

def cmd_rm(args):
    n = None
    if not args:
        grupo  = pedir_grupo("Grupo")
        evento = pedir_evento_interactivo(grupo)
    else:
        grupo, evento = resolver_arg(args[0])
        if len(args) > 1:
            try:
                n = int(args[1])
            except ValueError:
                pass

    lines = read_evento(grupo, evento)
    if not lines:
        print(f"No hay entradas en {grupo}/{evento}")
        return

    while n is None or not (1 <= n <= len(lines)):
        print_evento_tabla(grupo, evento)
        entrada = leer("Número de línea a borrar: ")
        try:
            n = int(entrada)
            if not (1 <= n <= len(lines)):
                print(f"Número {n} fuera de rango (1-{len(lines)})")
                n = None
        except ValueError:
            n = None

    removed = lines.pop(n - 1)
    write_evento(grupo, evento, lines)
    print(f"{C['minus']}-{RST} {C['date']}{removed['fecha']}{RST} {C['sep']}|{RST} {removed['comentario']}")

def cmd_pop(args):
    if not args:
        grupo  = pedir_grupo("Grupo")
        evento = pedir_evento_interactivo(grupo)
    else:
        grupo, evento = resolver_arg(args[0])

    lines = read_evento(grupo, evento)
    if not lines:
        print(f"No hay entradas en {grupo}/{evento}")
        return
    removed = lines.pop()
    write_evento(grupo, evento, lines)
    print(f"{C['minus']}-{RST} {C['date']}{removed['fecha']}{RST} {C['sep']}|{RST} {removed['comentario']}")

def cmd_del(args):
    if not args:
        entrada = leer("Borrar Grupo/ o evento: ")
        if not entrada:
            print("Cancelado")
            return
        args = [entrada]

    g_arg, e_arg = parse_arg(args[0])

    if g_arg and not e_arg:
        # borrar grupo completo
        grupo = find_grupo(g_arg) or g_arg
        gp    = grupo_path(grupo)
        if not gp.is_dir():
            print(f"No existe el grupo '{grupo}'")
            return
        print_arbol_compacto([grupo])
        r = leer(f"Enviar al trash el grupo '{grupo}' y todo su contenido? (s/n): ")
        if r != "s":
            print("Cancelado")
            return
        trash(gp)
        print(f"Enviado al trash: {grupo}/")
    else:
        if g_arg and e_arg:
            grupo, evento = g_arg, e_arg
        else:
            found = find_evento(e_arg)
            if found:
                grupo, evento = resolver_grupo(e_arg, found)
            else:
                g = find_grupo(e_arg)
                if g:
                    gp = grupo_path(g)
                    print_arbol_compacto([g])
                    r = leer(f"Enviar al trash el grupo '{g}' y todo su contenido? (s/n): ")
                    if r != "s":
                        print("Cancelado")
                        return
                    trash(gp)
                    print(f"Enviado al trash: {g}/")
                    return
                else:
                    print(f"No existe evento ni grupo '{e_arg}'")
                    return

        path = evento_path(grupo, evento)
        if not path.is_file():
            print(f"No existe {path}")
            return
        r = leer(f"Enviar al trash '{grupo}/{evento}'? (s/n): ")
        if r != "s":
            print("Cancelado")
            return
        trash(path)
        print(f"Enviado al trash: {grupo}/{evento}")

def cmd_mv(args):
    grupo_orig = ev_orig = n = grupo_dest = None

    if not args:
        grupo_orig = pedir_grupo("Grupo origen")
        ev_orig    = pedir_evento_interactivo(grupo_orig, "Evento origen")
        lines = read_evento(grupo_orig, ev_orig)
        if not lines:
            print(f"No hay entradas en {grupo_orig}/{ev_orig}")
            return
        print_evento_tabla(grupo_orig, ev_orig)
        try:
            n = int(leer("Número de línea a mover: "))
        except ValueError:
            print("Número inválido"); return
        while True:
            entrada = leer("Grupo destino (nombre, abreviatura o ?, Grupo/): ")
            if entrada == "?":
                print_arbol_compacto()
            elif entrada:
                grupo_dest = resolver_grupo_destino(entrada, ev_orig)
                if grupo_dest:
                    break

    elif len(args) == 1:
        grupo_orig, ev_orig = resolver_arg(args[0])
        lines = read_evento(grupo_orig, ev_orig)
        if not lines:
            print(f"No hay entradas en {grupo_orig}/{ev_orig}")
            return
        print_evento_tabla(grupo_orig, ev_orig)
        entrada_n = leer("Número de línea a mover (enter = cancelar): ")
        if not entrada_n:
            return
        try:
            n = int(entrada_n)
        except ValueError:
            print("Número inválido"); return
        while True:
            entrada = leer("Grupo destino (nombre, abreviatura o ?, Grupo/): ")
            if entrada == "?":
                print_arbol_compacto()
            elif entrada:
                grupo_dest = resolver_grupo_destino(entrada, ev_orig)
                if grupo_dest:
                    break

    elif len(args) >= 3:
        grupo_orig, ev_orig = resolver_arg(args[0])
        try:
            n = int(args[1])
        except ValueError:
            print("Error: uso: bit mv [Grupo/]evento N Grupo_dest"); return
        grupo_dest = resolver_grupo_destino(args[2], ev_orig)
        if not grupo_dest:
            return
    else:
        print("Error: uso: bit mv [Grupo/]evento N Grupo_dest"); return

    if n is None:
        print("Número inválido"); return

    lines_orig = read_evento(grupo_orig, ev_orig)
    if not lines_orig:
        print(f"No hay entradas en {grupo_orig}/{ev_orig}"); return
    if not (1 <= n <= len(lines_orig)):
        print(f"Número {n} fuera de rango (1-{len(lines_orig)})"); return

    moved = lines_orig.pop(n - 1)
    write_evento(grupo_orig, ev_orig, lines_orig)
    grupo_path(grupo_dest).mkdir(parents=True, exist_ok=True)
    lines_dest = read_evento(grupo_dest, ev_orig)
    lines_dest = insert_sorted(lines_dest, moved)
    write_evento(grupo_dest, ev_orig, lines_dest)
    print(
        f"~ {C['route']}{grupo_orig}/{ev_orig}{RST} #{n} → "
        f"{C['route']}{grupo_dest}/{ev_orig}{RST} | {moved['comentario']}"
    )

def cmd_dir(args):
    grupo_orig = ev_orig = grupo_dest = ev_dest = None

    if not args:
        grupo_orig = pedir_grupo("Grupo origen")
        ev_orig    = pedir_evento_interactivo(grupo_orig, "Evento a mover")
        grupo_dest = pedir_grupo("Grupo destino")
        entrada    = leer("Nombre en destino (enter = mismo): ")
        ev_dest    = entrada if entrada else ev_orig

    elif len(args) == 1:
        grupo_orig, ev_orig = resolver_arg(args[0])
        grupo_dest = pedir_grupo("Grupo destino")
        ev_dest    = ev_orig

    else:
        grupo_orig, ev_orig = resolver_arg(args[0])
        g_arg, e_arg = parse_arg(args[1])
        if g_arg and e_arg:
            grupo_dest, ev_dest = g_arg, e_arg
        elif g_arg:
            grupo_dest, ev_dest = g_arg, ev_orig
        else:
            grupo_dest, ev_dest = e_arg, ev_orig

    src  = evento_path(grupo_orig, ev_orig)
    dest = evento_path(grupo_dest, ev_dest)
    if not src.is_file():
        print(f"No existe {src}"); return
    if src == dest:
        print("Origen y destino son iguales"); return
    if dest.is_file():
        r = leer(f"Ya existe {grupo_dest}/{ev_dest}, sobreescribir? (s/n): ")
        if r != "s":
            print("Cancelado"); return
    grupo_path(grupo_dest).mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dest))
    # limpiar grupo origen si quedó sin archivos .md
    gp_orig = grupo_path(grupo_orig)
    eliminado = gp_orig.is_dir() and not any(gp_orig.glob('*.md'))
    if eliminado:
        shutil.rmtree(str(gp_orig))
    sufijo = f"  {C['tree']}({grupo_orig}/ eliminado){RST}" if eliminado else ""
    print(
        f"dir: {C['route']}{grupo_orig}/{ev_orig}{RST} → "
        f"{C['route']}{grupo_dest}/{ev_dest}{RST}" + sufijo
    )

def cmd_listar_evento(ev_str):
    g_arg, e_arg = parse_arg(ev_str)
    if g_arg and e_arg:
        print(f"\n{C['header']}## {g_arg} / {e_arg}{RST}\n")
        print_evento_tabla(g_arg, e_arg)
        return
    found = find_evento(ev_str)
    if not found:
        print(f"No existe ninguna bitácora con el evento '{ev_str}'")
        return
    for f in found:
        print(f"\n{C['header']}## {f['grupo']} / {f['evento']}{RST}\n")
        print_evento_tabla(f["grupo"], f["evento"])

def cmd_import(archivo):
    path = Path(archivo).expanduser()
    if not path.is_file():
        print(f"Error: no se puede abrir {archivo}", file=sys.stderr)
        sys.exit(1)
    count = 0
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("|"):
                continue
            fields = [x.strip() for x in line.split("|")]
            # quitar strings vacíos de los extremos
            fields = [x for x in fields if x != ""] if fields[0] == "" else fields
            # esperamos al menos: fecha, grupo, evento, comentario en posiciones 1,2,3,4
            if len(fields) < 4:
                continue
            fecha = fields[1] if len(fields) > 1 else ""
            if not re.match(r"^\d{4}-\d{2}-\d{2}", fecha):
                continue
            grupo_str  = titulo(fields[2]) if len(fields) > 2 else ""
            ev_str     = fields[3] if len(fields) > 3 else ""
            comentario = fields[4] if len(fields) > 4 else ""
            if grupo_str in ("Tipo", "Grupo") or ev_str == "Evento":
                continue
            if not grupo_str or not ev_str or not comentario:
                continue
            grupo_path(grupo_str).mkdir(parents=True, exist_ok=True)
            ep = evento_path(grupo_str, ev_str)
            with ep.open("a", encoding="utf-8") as ef:
                ef.write(f"{fecha} {comentario}\n")
            count += 1
    print(f"Importadas {count} entradas desde {archivo}")

def mostrar_ayuda():
    print(
        f"{C['header']}bit{RST} — bitácoras en bits/Grupo/evento.md\n"
        f"\n"
        f"  bit                            resumen en árbol\n"
        f"  bit <evento>                   listar entradas\n"
        f"  bit <evento> <comentario>      añadir entrada (atajo de add)\n"
        f"\n"
        f"  {C['plus']}add{RST} [Grupo/][evento] [comentario]       añadir entrada\n"
        f"  a                                       alias de add\n"
        f"  edit [Grupo/][evento]                   abrir archivo en {EDITOR}\n"
        f"  e                                       alias de edit\n"
        f"  {C['minus']}rm{RST}  [Grupo/]evento [N]                   borrar línea N\n"
        f"  pop [Grupo/]evento                      borrar última línea\n"
        f"  del Grupo/                              enviar grupo al trash (confirma)\n"
        f"  del [Grupo/]evento                      enviar evento al trash (confirma)\n"
        f"  mv  [Grupo/]evento N [Grupo/]ev_dest    mover línea N a otro evento\n"
        f"  mv  [Grupo/]evento                      listar líneas numeradas\n"
        f"  dir [Grupo/]evento [Grupo/][evento]     mover archivo completo a otro grupo\n"
        f"  import <archivo.md>                     importar desde bits.md anterior\n"
        f"  help, h                                 esta ayuda\n"
        f"\n"
        f"{C['tree']}Grupo/evento{RST}: si se omite Grupo/ se busca automáticamente.\n"
        f"{C['tree']}Grupos{RST}: referenciables por nombre, número o {C['abbrev']}ab{RST}reviatura (2 letras).\n"
        f"Sin argumentos en cualquier comando: modo interactivo."
    )

# ===== MAIN =====
def main():
    BASE.mkdir(parents=True, exist_ok=True)
    args = sys.argv[1:]

    if not args:
        print_resumen()
        return

    cmd  = args[0]
    rest = args[1:]

    dispatch = {
        "a"     : cmd_add,
        "add"   : cmd_add,
        "e"     : cmd_edit,
        "edit"  : cmd_edit,
        "rm"    : cmd_rm,
        "pop"   : cmd_pop,
        "del"   : cmd_del,
        "mv"    : cmd_mv,
        "dir"   : cmd_dir,
        "h"     : lambda _: mostrar_ayuda(),
        "help"  : lambda _: mostrar_ayuda(),
    }

    if cmd in dispatch:
        dispatch[cmd](rest)
    elif len(args) == 1:
        cmd_listar_evento(cmd)
    else:
        cmd_add(args)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCancelado")
        sys.exit(0)
