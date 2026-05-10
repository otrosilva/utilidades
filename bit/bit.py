#!/usr/bin/env python3
"""
bit.py — bitácoras en markdown con opción de importación
python bit.py                        # listar
python bit.py nombre                 # mostrar
python bit.py nombre texto aquí      # agregar
python bit.py +nombre                # editar en editor
python bit.py -nombre                # borrar última entrada
python bit.py @nombre                # borrar sección entera
python bit.py ++                     # abrir archivo completo
python bit.py --migrar ruta.txt
python bit.py --importar nota.txt
python bit.py --importar -           # desde stdin
"""
import re
import sys
import subprocess
import tempfile
import os
from datetime import datetime
from pathlib import Path

# ===== CONFIG =====
RUTA   = Path("~/Documentos/Filen/Obsidian/bits.md").expanduser()
EDITOR = "hx +9999"

# Patrón de timestamp: YYYY-MM-DD HH:MM:SS
RE_TS    = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")
# Patrón para normalizar fechas iOS: "2026:05:06 19:41" o "2026-05-06 19:41"
RE_FECHA = re.compile(r"(\d{4})[:\-](\d{2})[:\-](\d{2})\s+(\d{2}):(\d{2})")


# ===== TIPOS =====
def entrada(ts: str, text: str) -> dict:
    return {"ts": ts, "text": text}

def ahora() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# ===== MARKDOWN PARSE / SERIALIZE =====
# Formato en disco:
#   # nombre
#   - YYYY-MM-DD HH:MM:SS: texto

def _parse_linea_entrada(line: str) -> dict | None:
    """Parsea '- YYYY-MM-DD HH:MM:SS: texto' → entrada, o None si no encaja."""
    if not line.startswith("- "):
        return None
    rest = line[2:]
    # timestamp fijo de 19 chars, seguido de ": "
    if len(rest) > 21 and rest[19] == ":" and rest[20] == " ":
        ts, text = rest[:19], rest[21:]
        if RE_TS.match(ts):
            return entrada(ts, text)
    return None


def parse_md() -> tuple[dict, list, dict]:
    """Lee RUTA y devuelve (data, order, lower).
    data  : { name: [entrada, ...] }
    order : nombres en orden de aparición
    lower : { name.lower(): name_canonical }
    """
    data, order, lower = {}, [], {}
    cur = None

    try:
        with RUTA.open(encoding="utf-8") as f:
            for raw in f:
                line = raw.rstrip("\n")
                if line.startswith("# "):
                    name = line[2:].strip()
                    if name and " " not in name:
                        cur = name
                        if cur not in data:
                            data[cur] = []
                            order.append(cur)
                            lower[cur.lower()] = cur
                elif cur:
                    e = _parse_linea_entrada(line)
                    if e:
                        data[cur].append(e)
    except FileNotFoundError:
        pass

    return data, order, lower


def write_md(data: dict, order: list) -> None:
    try:
        with RUTA.open("w", encoding="utf-8") as f:
            for i, name in enumerate(sorted(n for n in order if n in data)):
                if i > 0:
                    f.write("\n")
                f.write(f"# {name}\n")
                for e in sorted(data[name], key=lambda e: e["ts"]):
                    f.write(f"- {e['ts']}: {e['text']}\n")
    except OSError as err:
        sys.exit(f"Error: no se pudo escribir en {RUTA}: {err}")


# ===== RESOLUCIÓN DE NOMBRES =====
def resolver(name: str, data: dict, order: list, lower: dict) -> tuple[str | None, list]:
    """Resuelve nombre canónico: exacto → case-insensitive → prefijo.
    Devuelve (canon, sugerencias).
    """
    if name in data:
        return name, []
    canon = lower.get(name.lower())
    if canon:
        return canon, []
    sugg = [n for n in order if n.lower().startswith(name.lower())]
    return None, sugg


def _no_encontrado(name: str, sugg: list) -> None:
    """Imprime sugerencias o mensaje de no encontrado."""
    if sugg:
        print(f"¿Quisiste decir: {', '.join(sugg)}?")
    else:
        print(f"No hay entradas para {name}")


def _quitar_seccion(data: dict, order: list, name: str) -> None:
    """Elimina una sección de data y order."""
    del data[name]
    order[:] = [n for n in order if n != name]


# ===== COMANDOS =====
def listar() -> None:
    data, order, _ = parse_md()
    if not order:
        print("No hay bitácoras")
        return
    for name in sorted(order):
        print(f"{name:<20} {len(data[name])} entradas")


def mostrar(name: str) -> None:
    data, order, lower = parse_md()
    canon, sugg = resolver(name, data, order, lower)
    if canon:
        for e in data[canon]:
            print(f"{e['ts']}: {e['text']}")
    else:
        _no_encontrado(name, sugg)


def agregar(name: str, text: str) -> None:
    data, order, lower = parse_md()
    canon, sugg = resolver(name, data, order, lower)
    name = canon or (sugg[0] if len(sugg) == 1 else name)

    if name not in data:
        data[name] = []
        order.append(name)

    data[name].append(entrada(ahora(), text))
    write_md(data, order)


def borrar(name: str, todo=False) -> None:
    data, order, lower = parse_md()
    canon, sugg = resolver(name, data, order, lower)

    if not canon:
        _no_encontrado(name, sugg)
        return

    name = canon
    if todo:
        if input(f"¿Borrar TODAS las entradas de {name}? (s/n): ") != "s":
            return
        _quitar_seccion(data, order, name)
    else:
        entries = data[name]
        if not entries:
            print(f"No hay entradas en {name}")
            return
        last = entries.pop()
        print(f"{name} {last['ts']}: {last['text']}")
        if not entries:
            _quitar_seccion(data, order, name)

    write_md(data, order)


def editar(name: str) -> None:
    data, order, lower = parse_md()
    canon, sugg = resolver(name, data, order, lower)

    if not canon:
        _no_encontrado(name, sugg)
        sys.exit(1)

    name = canon
    tmp = Path(os.environ.get("TMPDIR", tempfile.gettempdir())) / f"bit_{name}.tmp"

    with tmp.open("w", encoding="utf-8") as f:
        for e in data[name]:
            f.write(f"- {e['ts']}: {e['text']}\n")

    subprocess.call(f"{EDITOR} {tmp}", shell=True)

    try:
        with tmp.open(encoding="utf-8") as f:
            data[name] = [e for line in f if (e := _parse_linea_entrada(line.rstrip("\n")))]
    except FileNotFoundError:
        pass

    write_md(data, order)


# ===== IMPORTAR / MIGRAR =====
def migrar(txt_path: str) -> None:
    path = Path(txt_path).expanduser()
    data, order = {}, []

    try:
        with path.open(encoding="utf-8") as f:
            for line in f:
                # formato: nombre YYYY-MM-DD HH:MM:SS: texto
                parts = line.strip().split(" ", 1)
                if len(parts) < 2:
                    continue
                name, rest = parts
                e = _parse_linea_entrada(f"- {rest}")
                if e:
                    if name not in data:
                        data[name] = []
                        order.append(name)
                    data[name].append(e)
    except FileNotFoundError:
        sys.exit(f"No se encontró: {path}")

    write_md(data, order)
    print(f"Migradas {len(order)} secciones a {RUTA}")


def _normalizar_fecha_ios(fecha_raw: str) -> str:
    """'2026:05:06 19:41' → '2026-05-06 19:41:00', o timestamp actual si no encaja."""
    m = RE_FECHA.match(fecha_raw)
    if m:
        anio, mes, dia, hora, minuto = m.groups()
        return f"{anio}-{mes}-{dia} {hora}:{minuto}:00"
    sys.stderr.write(f"  ⚠ fecha no reconocida '{fecha_raw}', usando ahora\n")
    return ahora()


def importar_ios(nota_path: str) -> None:
    """Importa entradas desde nota iOS con formato pipe:
       YYYY:MM:DD HH:MM | Categoría | subcategoría | texto
    """
    f = sys.stdin if nota_path == "-" else None
    if f is None:
        path = Path(nota_path).expanduser()
        try:
            f = path.open(encoding="utf-8")
        except FileNotFoundError:
            sys.exit(f"No se encontró: {path}")

    data, order, lower = parse_md()
    imported = skipped = 0
    primera = True

    with f:
        for raw in f:
            line = raw.strip()
            if not line:
                primera = False
                continue
            # ignorar cabecera sin pipes (p.ej. "Registro")
            if primera:
                primera = False
                if "|" not in line:
                    continue

            fields = [p.strip() for p in line.split("|")]
            if len(fields) < 4 or not fields[1]:
                skipped += 1
                continue

            fecha_raw, categoria, sub, texto = fields[:4]
            ts         = _normalizar_fecha_ios(fecha_raw)
            entry_text = f"{sub}: {texto}" if sub else texto

            canon, _ = resolver(categoria, data, order, lower)
            name = canon or categoria
            if name not in data:
                data[name] = []
                order.append(name)
                lower[name.lower()] = name

            e = entrada(ts, entry_text)
            if any(x["ts"] == ts and x["text"] == entry_text for x in data[name]):
                skipped += 1
            else:
                data[name].append(e)
                imported += 1

    write_md(data, order)
    print(f"Importadas {imported} entradas, {skipped} omitidas (duplicadas o inválidas)")


# ===== MAIN =====
def main() -> None:
    args = sys.argv[1:]

    if not args:
        listar(); return

    if args == ["++"]:
        subprocess.call(f"{EDITOR} {RUTA}", shell=True); return

    if len(args) == 2 and args[0] == "--migrar":
        migrar(args[1]); return

    if len(args) == 2 and args[0] == "--importar":
        importar_ios(args[1]); return

    # sigilo prefijo: +nombre, -nombre, @nombre
    raw  = args[0]
    flag = raw[0] if raw and raw[0] in ("+", "-", "@") else None
    name = raw[1:] if flag else raw

    if len(args) == 1:
        if flag == "+":   editar(name)
        elif flag == "-": borrar(name)
        elif flag == "@": borrar(name, todo=True)
        else:             mostrar(name)
    else:
        agregar(name, " ".join(args[1:]))
        if flag == "+":
            editar(name)


if __name__ == "__main__":
    main()
