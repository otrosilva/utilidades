#!/usr/bin/env python3
# bit.py — bitácoras en tabla markdown (estilo Unix)

import sys
import os
import re
import subprocess
import tempfile
from datetime import datetime

# ===== CONFIG =====
RUTA = os.path.expanduser("~/Documentos/Filen/Obsidian/bits.md")
EDITOR = "micro"          # o "hx", "nano", "vim", etc.

# ===== UTILS =====
def trim(s: str) -> str:
    return s.strip()

def now_ts() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M")

def ts_to_epoch(ts: str) -> int | None:
    try:
        return int(datetime.strptime(ts, "%Y-%m-%d %H:%M").timestamp())
    except ValueError:
        return None

def fmt_diff(secs: int) -> str:
    if secs < 0:
        return "?"
    total_min = secs // 60
    if total_min == 0:
        return "0m"
    d = total_min // 1440
    h = (total_min % 1440) // 60
    m = total_min % 60
    parts = []
    if d: parts.append(f"{d}d")
    if h: parts.append(f"{h}h")
    if m: parts.append(f"{m}m")
    return "".join(parts) or "0m"

# ===== PARSE / SERIALIZE =====
HEADER = "| Fecha | Tipo | Evento | Comentario | Transcurrido |"
SEP    = "| --- | --- | --- | --- | --- |"

def parse_line(line: str) -> dict | None:
    line = line.strip()
    if not line.startswith("|"):
        return None
    # Dividir por pipes, ignorar primero y último vacíos
    fields = [trim(f) for f in line.split("|")[1:-1]]
    if len(fields) < 5:
        return None
    if not re.match(r"\d{4}-\d{2}-\d{2}", fields[0]):
        return None
    return {
        "fecha": fields[0],
        "tipo": fields[1],
        "evento": fields[2],
        "comentario": fields[3],
        "transcurrido": fields[4],
    }

def parse_md():
    entries = []
    try:
        with open(RUTA, "r", encoding="utf-8") as f:
            for line in f:
                e = parse_line(line)
                if e:
                    entries.append(e)
    except FileNotFoundError:
        pass
    return entries

def write_md(entries):
    # Asegurar directorio
    os.makedirs(os.path.dirname(RUTA), exist_ok=True)
    with open(RUTA, "w", encoding="utf-8") as f:
        f.write("# Registro\n\n")
        f.write(HEADER + "\n")
        f.write(SEP + "\n")
        for e in entries:
            f.write(f"| {e['fecha']} | {e['tipo']} | {e['evento']} | {e['comentario']} | {e['transcurrido']} |\n")

# ===== CATEGORÍAS =====
def categorias_existentes(entries):
    cats = set()
    for e in entries:
        if e["tipo"]:
            cats.add(e["tipo"])
    return sorted(cats)

# ===== BÚSQUEDA =====
def eventos_con_prefijo(entries, prefijo):
    pref = prefijo.lower()
    seen = set()
    result = []
    for e in entries:
        ev = e["evento"]
        if ev.lower().startswith(pref):
            if ev not in seen:
                seen.add(ev)
                result.append(ev)
    return sorted(result)

def ultima_entrada(entries, evento):
    last = None
    for e in entries:
        if e["evento"] == evento:
            last = e
    return last

# ===== FUNCIONES PRINCIPALES =====
def mostrar_ayuda():
    print("""\
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
""")

def listar(entries):
    if not entries:
        print("No hay entradas")
        return

    by_category = {}
    for e in entries:
        cat = e["tipo"]
        ev = e["evento"]
        if cat not in by_category:
            by_category[cat] = {}
        by_category[cat][ev] = by_category[cat].get(ev, 0) + 1

    for cat in sorted(by_category.keys()):
        print()
        print(f"| {cat} | #   |")
        print("| --- | --- |")
        for ev in sorted(by_category[cat].keys()):
            print(f"| {ev} | {by_category[cat][ev]} |")

def mostrar_evento(entries, evento):
    found = [e for e in entries if e["evento"] == evento]
    if not found:
        print(f"No hay entradas para el evento '{evento}'")
        return
    print("| Fecha | Tipo | Evento | Comentario | Transcurrido |")
    print("| --- | --- | --- | --- | --- |")
    for e in found:
        comentario = e["comentario"].replace("|", "\\|")
        print(f"| {e['fecha']} | {e['tipo']} | {e['evento']} | {comentario} | {e['transcurrido']} |")

def agregar(entries, evento, comentario):
    last = ultima_entrada(entries, evento)
    tipo = last["tipo"] if last else None

    if not tipo:
        while True:
            inp = input(f"Categoría para '{evento}' (escribe '?' para ver las existentes): ").strip()
            if inp == "?":
                cats = categorias_existentes(entries)
                if not cats:
                    print("No hay categorías previas. Puedes escribir una nueva.")
                else:
                    print("Categorías existentes:")
                    for c in cats:
                        print(f"  - {c}")
            elif inp:
                tipo = inp
                break
        if not tipo:
            tipo = "Evento"

    transcurrido = "inicio"
    if last:
        last_epoch = ts_to_epoch(last["fecha"])
        now_epoch = ts_to_epoch(now_ts())
        if last_epoch and now_epoch:
            transcurrido = fmt_diff(now_epoch - last_epoch)

    entries.append({
        "fecha": now_ts(),
        "tipo": tipo,
        "evento": evento,
        "comentario": comentario,
        "transcurrido": transcurrido,
    })
    write_md(entries)
    print(f"+ {now_ts()} | {tipo} | {evento} | {transcurrido}")

def borrar_ultima(entries, evento):
    idx = None
    for i in range(len(entries)-1, -1, -1):
        if entries[i]["evento"] == evento:
            idx = i
            break
    if idx is None:
        print(f"No hay entradas para el evento '{evento}'")
        return
    removed = entries.pop(idx)
    write_md(entries)
    print(f"- {removed['fecha']} | {removed['evento']} | {removed['comentario']}")

def borrar_todo(entries, evento):
    resp = input(f"¿Borrar TODAS las entradas de '{evento}'? (s/n): ").strip().lower()
    if resp != "s":
        return
    new_entries = [e for e in entries if e["evento"] != evento]
    write_md(new_entries)
    print(f"Borradas todas las entradas de '{evento}'")

def editar_evento(entries, evento):
    # Filtrar entradas del evento
    event_entries = [e for e in entries if e["evento"] == evento]
    if not event_entries:
        print(f"No hay entradas para el evento '{evento}'")
        return

    # Crear archivo temporal con las entradas
    with tempfile.NamedTemporaryFile(mode="w+", suffix=".md", delete=False) as tf:
        temp_name = tf.name
        tf.write(f"# Editando: {evento}\n")
        tf.write("# Formato: | fecha | tipo | evento | comentario | transcurrido |\n\n")
        for e in event_entries:
            tf.write(f"| {e['fecha']} | {e['tipo']} | {e['evento']} | {e['comentario']} | {e['transcurrido']} |\n")
    # Abrir editor
    subprocess.call([EDITOR, temp_name])

    # Leer resultado
    new_entries = []
    with open(temp_name, "r", encoding="utf-8") as tf:
        for line in tf:
            e = parse_line(line)
            if e:
                new_entries.append(e)
    os.unlink(temp_name)

    # Reemplazar en la lista original
    result = []
    replaced = False
    for e in entries:
        if e["evento"] != evento:
            result.append(e)
        elif not replaced:
            result.extend(new_entries)
            replaced = True
    if not replaced:
        result.extend(new_entries)

    # Reordenar por fecha
    result.sort(key=lambda x: x["fecha"])
    write_md(result)
    print(f"Editado: {evento}")

# ===== MAIN =====
def main():
    # Verificar/crear archivo si no existe
    if not os.path.exists(RUTA):
        write_md([])

    args = sys.argv[1:]
    if not args:
        entries = parse_md()
        listar(entries)
        return

    # Expandir opciones largas
    def expand_option(arg):
        if arg in ("--help",): return "-h"
        if arg in ("--list",): return "-l"
        if arg in ("--edit",): return "-e"
        if arg in ("--add",): return "-a"
        if arg in ("--delete",): return "-d"
        if arg in ("--delete-all",): return "-D"
        return arg

    first = expand_option(args[0])
    entries = parse_md()

    if first == "-h":
        mostrar_ayuda()
    elif first == "-l":
        listar(entries)
    elif first == "-e":
        if len(args) < 2:
            print("Error: falta el nombre del evento")
            mostrar_ayuda()
            sys.exit(1)
        editar_evento(entries, args[1])
    elif first == "-a":
        if len(args) < 3:
            print("Error: uso: bit -a <evento> <comentario>")
            sys.exit(1)
        agregar(entries, args[1], " ".join(args[2:]))
    elif first == "-d":
        if len(args) < 2:
            print("Error: falta el nombre del evento")
            sys.exit(1)
        borrar_ultima(entries, args[1])
    elif first == "-D":
        if len(args) < 2:
            print("Error: falta el nombre del evento")
            sys.exit(1)
        borrar_todo(entries, args[1])
    else:
        # Sin opción: puede ser "bit evento" o "bit evento comentario"
        evento = args[0]
        if len(args) == 1:
            # Mostrar evento
            matching = eventos_con_prefijo(entries, evento)
            if not matching:
                print(f"No existe ninguna bitácora que empiece por '{evento}'")
                sys.exit(1)
            elif len(matching) > 1:
                print(f"Bitácoras que coinciden con '{evento}':")
                for ev in matching:
                    print(f"  - {ev}")
            else:
                mostrar_evento(entries, matching[0])
        else:
            # Añadir rápido
            comentario = " ".join(args[1:])
            agregar(entries, evento, comentario)

if __name__ == "__main__":
    main()
