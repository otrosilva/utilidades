#!/usr/bin/env python3
import os
import subprocess
from datetime import datetime
from pathlib import Path


class Bitacora:
    def __init__(self, ruta="~/bits/", editor="nano", show="cat"):
        self.ruta = Path(ruta).expanduser()
        if not self.ruta.is_dir():
            print(f"Error: La ruta {self.ruta} no existe o no es un directorio.")
            return
        self.editor = editor or os.getenv("EDITOR")
        self.show = show or "tail"

    def config(self):
        print("--- Atributos de la instancia ---")
        for attr, val in self.__dict__.items():
            print(f"{attr}: {val}")
        print("--- Métodos de la clase ---")
        methods = [
            m
            for m in dir(self)
            if callable(getattr(self, m)) and not m.startswith("__")
        ]
        for m in methods:
            print(f"{m}: method")
        print("--- Fin de la Configuración ---")

    def listar(self):
        txt_files = list(self.ruta.glob("*.txt"))
        if txt_files:
            for file in txt_files:
                print(file.stem)
        else:
            print("No hay bitácoras")

    def mostrar(self, bitacora):
        ruta_completa = self.ruta / f"{bitacora}.txt"
        if not ruta_completa.exists():
            print(f"Archivo {bitacora}.txt no existe.")
            return
        try:
            _ = subprocess.run([self.show, str(ruta_completa)], check=False)
        except Exception as e:
            print(f"Error al ejecutar el comando {self.show}: {e}")

    def directorio(self, bitacora):
        ruta_completa = self.ruta / f"{bitacora}.txt"
        if ruta_completa.exists():
            print(ruta_completa)
        else:
            print(f"Archivo {bitacora}.txt no existe.")
        return

    def editar(self, bitacora):
        ruta_completa = self.ruta / f"{bitacora}.txt"
        try:
            ruta_completa.touch(exist_ok=True)
            resultado = subprocess.run([self.editor, str(ruta_completa)], check=False)
            if resultado.returncode == 0:
                print(f"Archivo {bitacora}.txt editado exitosamente.")
            else:
                print(f"Error al ejecutar el editor: código {resultado.returncode}")
        except Exception as e:
            print(f"Error al ejecutar el editor: {e}")

    def agregar(self, bitacora, texto):
        ruta_completa = self.ruta / f"{bitacora}.txt"
        try:
            with open(ruta_completa, "a", encoding="utf-8") as archivo:
                prefijo = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                log_entry = f"{bitacora} {prefijo}: {texto}\n"
                _ = archivo.write(log_entry)
            print(f"Nueva entrada agregada exitosamente al archivo {bitacora}.txt")
        except Exception as e:
            print(f"Error al abrir o escribir el archivo: {e}")

    def borrar(self, bitacora, todo=False):
        ruta_completa = self.ruta / f"{bitacora}.txt"
        if not ruta_completa.exists():
            print(f"Error: El archivo {bitacora}.txt no existe.")
            return

        if todo:
            confirmacion = input(
                f"¿Está seguro de que desea borrar el archivo {bitacora}.txt? (s/n): "
            )
            if confirmacion.lower() == "s":
                try:
                    ruta_completa.unlink()
                    print(f"Archivo {bitacora}.txt borrado exitosamente.")
                except Exception as e:
                    print(f"Error al borrar el archivo: {e}")
            else:
                print("Operación de borrado cancelada.")
        else:
            try:
                with open(ruta_completa, "r", encoding="utf-8") as archivo:
                    lineas = archivo.readlines()
                if lineas:
                    lineas = lineas[:-1]
                    with open(ruta_completa, "w", encoding="utf-8") as archivo:
                        archivo.writelines(lineas)
                    print(f"Última línea borrada de {bitacora}.txt")
                else:
                    print(f"El archivo {bitacora}.txt está vacío.")
            except Exception as e:
                print(f"Error al modificar el archivo: {e}")


if __name__ == "__main__":
    import sys

    bit = Bitacora("~/Documentos/Nube/bit/", editor="micro", show="cat")

    args = sys.argv[1:]

    if len(args) == 0:
        print("Bitácoras:")
        bit.listar()
        sys.exit(0)

    extra = None
    bitacora = args[0]

    if bitacora.startswith(("+", "-", "/")):
        extra = bitacora[0]
        bitacora = bitacora[1:]

    if len(args) == 1:
        if extra == "+":
            bit.editar(bitacora)
        elif extra == "-":
            bit.borrar(bitacora, True)
        elif extra == "/":
            bit.directorio(bitacora)
        else:
            bit.mostrar(bitacora)
        sys.exit(0)

    if len(args) > 1:
        texto = " ".join(args[1:])
        bit.agregar(bitacora, texto)
        if extra == "+":
            bit.editar(bitacora)
        sys.exit(0)
