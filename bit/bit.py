#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script para ver, guardar y editar bitácoras en un SOLO archivo txt.
"""

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


class Bitacora:
    def __init__(self, ruta, editor=None, show=None):
        self.ruta = Path(ruta).expanduser()
        self.editor = editor or os.getenv("EDITOR", "nano")
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
    def listar(self):
        vistos = set()
        lista = []

        with self.ruta.open("r", encoding="utf-8") as f:
            for linea in f:
                linea = linea.strip()
                if not linea:
                    continue
                nombre = linea.split(maxsplit=1)[0]
                if nombre not in vistos:
                    vistos.add(nombre)
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

    # --- Editar archivo único
    def editar(self):
        subprocess.run([*self.editor.split(), str(self.ruta)])

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
    # Archivo único (igual que en Lua)
    bit = Bitacora(
        "~/Documentos/@nube/bits.txt",
        editor="hx +9999",
        show="cat",
    )

    args = sys.argv[1:]

    # Sin argumentos → listar
    if not args:
        print("Bitácoras:")
        bit.listar()
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
            bit.editar()
        elif extra == "-":
            bit.borrar(nombre, todo=True)
        else:
            bit.mostrar(nombre)
        return

    # Más de un argumento → agregar
    texto = " ".join(args[1:])
    bit.agregar(nombre, texto)

    if extra == "+":
        bit.editar()


if __name__ == "__main__":
    main()
