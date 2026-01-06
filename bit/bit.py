#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script para ver, guardar y editar bitácoras en un solo archivo txt.
"""

import os
import pathlib
import subprocess
import sys
from datetime import datetime


class Bitacora:
    def __init__(self, ruta="~/bits.txt", editor="micro", show="tail"):
        self.ruta = pathlib.Path(ruta).expanduser()
        self.editor = editor or os.getenv("EDITOR", "micro")
        self.show = show or "tail"

        # Crear el archivo si no existe
        self.ruta.parent.mkdir(parents=True, exist_ok=True)
        self.ruta.touch(exist_ok=True)

    # --- Depuración
    def config(self):
        print("--- Atributos de la instancia ---")
        for k, v in vars(self).items():
            print(f"{k}: {v}")
        print("--- Métodos de la clase ---")
        for m in dir(self):
            if callable(getattr(self, m)) and not m.startswith("_"):
                print(f"{m}: method")
        print("--- Fin de la Configuración ---")

    # --- Listar bitácoras únicas
    def listar(self, parcial=""):
        lista = []

        with self.ruta.open("r", encoding="utf-8") as f:
            for linea in f:
                linea = linea.strip()
                if not linea:
                    continue
                nombre = linea.split(maxsplit=1)[0]
                if nombre not in lista:
                    if parcial:
                        if nombre.startswith(parcial):
                            lista.append(nombre)
                    else:
                        lista.append(nombre)

        if lista:
            for b in lista:
                print(b)
        else:
            print("No hay bitácoras")

        return lista

    # --- Mostrar entradas o sugerencias
    def mostrar(self, bitacora):
        lineas = []
        sugerencias = set()

        with self.ruta.open("r", encoding="utf-8") as f:
            for linea in f:
                linea = linea.rstrip("\n")
                if not linea:
                    continue
                nombre = linea.split(maxsplit=1)[0]

                if nombre == bitacora:
                    lineas.append(linea)

                if nombre.startswith(bitacora):
                    sugerencias.add(nombre)

        if lineas:
            for l in lineas:
                print(l)
            return

        if sugerencias:
            print("Bitácoras:")
            for b in sorted(sugerencias):
                print(b)
        else:
            print(f"No hay entradas para {bitacora}")


    def editar(self):
        """
        Abrir el archivo completo bits.txt con el editor
        (equivalente al '++' de tu script Lua).
        """
        subprocess.run([*self.editor.split(), str(self.ruta)])

    # --- Editar archivo único
    def _tmpfile(self, name: str) -> pathlib.Path:
        base = pathlib.Path(os.getenv("TMPDIR") or "/tmp")
        return base / f"bit_{name}.tmp"

    def editar_bitacora(self, name: str):
        """
        Equivalente a editar_bitacora(name) de Lua:
        - Edita solo esa bitácora en un archivo temporal
        - Reconstruye bits.txt reinsertando lo editado
        - Ordena todo por fecha (segunda columna)
        """

        # 1) Comprobar que existe esa bitácora
        existe = False
        lineas_exactas = []
        with self.ruta.open("r", encoding="utf-8") as f:
            for linea in f:
                linea = linea.rstrip("\n")
                if not linea:
                    continue
                if linea.startswith(f"{name} "):
                    existe = True
                    lineas_exactas.append(linea)

        if not existe:
            print(f"No existe {name}")
            sys.exit(1)

        # 2) Volcar SOLO esa bitácora al temporal
        tmp = self._tmpfile(name)
        with tmp.open("w", encoding="utf-8") as tf:
            for l in lineas_exactas:
                tf.write(l + "\n")

        # 3) Abrir el editor sobre el temporal
        subprocess.run([*self.editor.split(), str(tmp)])

        # 4) Leer TODO bits.txt, excluyendo la bitácora editada
        with self.ruta.open("r", encoding="utf-8") as f:
            todas = [l.rstrip("\n") for l in f]

        restantes = [
            l for l in todas
            if not l.startswith(f"{name} ")
        ]

        # 5) Añadir las nuevas líneas desde el temporal
        nuevas = []
        if tmp.exists():
            with tmp.open("r", encoding="utf-8") as tf:
                for l in tf:
                    l = l.rstrip("\n")
                    if l:
                        nuevas.append(l)

        # 6) Combinar y ordenar por fecha (segunda columna)
        def extraer_fecha(linea: str):
            # formato: nombre YYYY-MM-DD HH:MM:SS: texto
            #          ^^^^^  ^^^^^^^^^^^^^^^^^^
            partes = linea.split(maxsplit=2)
            if len(partes) < 3:
                return datetime.min
            fecha_str = partes[1]  # "YYYY-MM-DD"
            # partes[2] empieza por "HH:MM:SS: ..."
            resto = partes[2]
            if len(resto) < 8:
                return datetime.min
            hora_str = resto[:8]   # "HH:MM:SS"
            try:
                return datetime.strptime(
                    f"{fecha_str} {hora_str}",
                    "%Y-%m-%d %H:%M:%S",
                )
            except ValueError:
                return datetime.min

        todas_lineas = restantes + nuevas
        todas_lineas.sort(key=extraer_fecha)

        # 7) Escribir de vuelta bits.txt
        with self.ruta.open("w", encoding="utf-8") as f:
            for l in todas_lineas:
                f.write(l + "\n")

    # --- Agregar entrada
    def agregar(self, bitacora, texto):
        prefijo = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        linea = f"{bitacora} {prefijo}: {texto}"

        with self.ruta.open("a", encoding="utf-8") as f:
            f.write(linea + "\n")

        print(f"Nueva entrada agregada exitosamente para {bitacora}")

    # --- Borrar entradas
    def borrar(self, bitacora, todo=False):
        with self.ruta.open("r", encoding="utf-8") as f:
            lineas = f.readlines()

        if todo:
            confirm = input(
                f"¿Borrar TODAS las entradas de {bitacora}? (s/n): "
            ).lower()
            if confirm != "s":
                return

            nuevas = [l for l in lineas if not l.startswith(f"{bitacora} ")]
        else:
            nuevas = lineas[:]
            for i in range(len(nuevas) - 1, -1, -1):
                if nuevas[i].startswith(f"{bitacora} "):
                    nuevas.pop(i)
                    break

        with self.ruta.open("w", encoding="utf-8") as f:
            f.writelines(nuevas)


# ===== MAIN =====


def main():
    bit = Bitacora(
        "~/Documentos/bits.txt",
        # editor="hx +9999",
        editor="micro",
        show="batcat",
    )

    args = sys.argv[1:]

    # Sin argumentos → listar
    if not args:
        print("Bitácoras:")
        bit.listar()
        return

    # Caso especial: solo "+"
    if len(args) == 1 and args[0] == "+":
        # abrir archivo completo, como en Lua con "++"
        bit.editar()  # este método abre self.ruta con el editor
        return

    # Prefijos
    extra = None
    nombre = args[0]

    if nombre.startswith(("+", "-")):
        extra = nombre[0]
        nombre = nombre[1:]

    # Un argumento
    if len(args) == 1:
        if extra == "+":
            # +bitacora -> editar solo esa bitácora
            bit.editar_bitacora(nombre)
        elif extra == "-":
            # -bitacora -> borrar solo la última entrada de esa bitácora (como en Lua)
            bit.borrar(nombre, todo=False)
        else:
            bit.mostrar(nombre)
        return

    # Más de un argumento → agregar
    texto = " ".join(args[1:])
    bit.agregar(nombre, texto)
    if extra == "+":
        # +bitacora texto -> añadir y luego editar solo esa bitácora
        bit.editar_bitacora(nombre)


if __name__ == "__main__":
    main()
