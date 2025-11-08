#!/usr/bin/env python3
import os
import subprocess
from datetime import datetime
from pathlib import Path

try:
    import tomllib
except Exception:
    tomllib = None


def cargar_config_tomllib(ruta: Path):
    with ruta.open("rb") as f:
        return tomllib.load(f)


def cargar_config_simple_toml(ruta: Path):
    """Parser mínimo: sólo admite líneas key = "value" o key = 'value' y comentarios."""
    cfg = {}
    try:
        text = ruta.read_text(encoding="utf-8")
    except Exception:
        return cfg
    for linea in text.splitlines():
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        if "=" not in linea:
            continue
        key, val = linea.split("=", 1)
        key = key.strip()
        val = val.strip()
        # quitar comillas si existen
        if (val.startswith('"') and val.endswith('"')) or (
            val.startswith("'") and val.endswith("'")
        ):
            val = val[1:-1]
        # expandir ~ en rutas
        if key in ("archivo", "path", "file", "archivo_path"):
            val = os.path.expanduser(val)
        cfg[key] = val
    return cfg


def cargar_config(ruta_proporcionada: str | None = None) -> dict:
    if ruta_proporcionada:
        ruta = Path(ruta_proporcionada).expanduser()
    else:
        ruta_env = os.getenv("BIT_CONFIG")
        if ruta_env:
            ruta = Path(ruta_env).expanduser()
        else:
            base = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config"))
            ruta = base / "bit" / "config.toml"
    if not ruta.exists():
        return {}
    if tomllib is not None:
        try:
            return cargar_config_tomllib(ruta)
        except Exception:
            return {}
    else:
        return cargar_config_simple_toml(ruta)


class Bitacora:
    def __init__(
        self,
        archivo="~/Documents/bits.txt",
        editor="nano",
        show="cat",
    ):
        self.archivo = Path(archivo).expanduser()

        self.archivo.parent.mkdir(parents=True, exist_ok=True)

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
        """Lista todas las bitácoras únicas encontradas en el archivo"""
        if not self.archivo.exists():
            print("DEBUG: no existe archivo")
            print("No hay bitácoras")
            return

        bitacoras = set()
        try:
            with open(self.archivo, "r", encoding="utf-8") as f:
                for linea in f:
                    if linea.strip():
                        partes = linea.strip().split()
                        if partes:
                            bitacoras.add(partes[0])

            if bitacoras:
                for bitacora in sorted(bitacoras):
                    print(bitacora)
            else:
                print("No hay bitácoras")
        except Exception as e:
            print(f"Error al leer el archivo: {e}")

    def _obtener_bitacoras_con_patron(self, patron):
        """Obtiene todas las bitácoras que coinciden con un patrón"""
        if not self.archivo.exists():
            return []

        bitacoras = set()
        try:
            with open(self.archivo, "r", encoding="utf-8") as f:
                for linea in f:
                    if linea.strip():
                        partes = linea.strip().split()
                        if partes and partes[0].startswith(patron):
                            bitacoras.add(partes[0])
            return sorted(bitacoras)
        except Exception as e:
            print(f"Error al leer el archivo: {e}")
            return []

    def mostrar(self, bitacora):
        """Muestra todas las líneas que empiezan con el nombre de la bitácora o patrón"""
        if not self.archivo.exists():
            print(f"No hay entradas para {bitacora}")
            return

        try:
            with open(self.archivo, "r", encoding="utf-8") as f:
                lineas_exactas = [
                    linea.strip()
                    for linea in f
                    if linea.strip().startswith(f"{bitacora} ")
                ]

            if lineas_exactas:
                for linea in lineas_exactas:
                    print(linea)
            else:
                bitacoras_patron = self._obtener_bitacoras_con_patron(bitacora)

                if bitacoras_patron:
                    print("Bitácoras:")
                    for bitacora_patron in bitacoras_patron:
                        print(bitacora_patron)
                else:
                    print(f"No hay entradas para {bitacora}")

        except Exception as e:
            print(f"Error al leer el archivo: {e}")

    def directorio(self, bitacora):
        """Muestra la ruta del archivo único"""
        print(self.archivo)
        return

    def editar(self, bitacora):
        """Abre el editor para el archivo único"""
        try:
            self.archivo.touch(exist_ok=True)
            resultado = subprocess.run([self.editor, str(self.archivo)], check=False)
            if resultado.returncode == 0:
                print(f"Archivo {self.archivo.name} editado exitosamente.")
            else:
                print(f"Error al ejecutar el editor: código {resultado.returncode}")
        except Exception as e:
            print(f"Error al ejecutar el editor: {e}")

    def agregar(self, bitacora, texto):
        """Agrega una nueva entrada al archivo único"""
        try:
            with open(self.archivo, "a", encoding="utf-8") as archivo:
                prefijo = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                log_entry = f"{bitacora} {prefijo}: {texto}\n"
                _ = archivo.write(log_entry)
            print(f"Nueva entrada agregada exitosamente para {bitacora}")
        except Exception as e:
            print(f"Error al abrir o escribir el archivo: {e}")

    def borrar(self, bitacora, todo=False):
        """Borra líneas del archivo único"""
        if not self.archivo.exists():
            print(f"Error: El archivo {self.archivo.name} no existe.")
            return

        if todo:
            confirmacion = input(
                f"¿Está seguro de que desea borrar TODAS las entradas de {bitacora}? (s/n): "
            )
            if confirmacion.lower() == "s":
                try:
                    with open(self.archivo, "r", encoding="utf-8") as f:
                        lineas = [
                            linea
                            for linea in f
                            if not linea.strip().startswith(f"{bitacora} ")
                        ]

                    with open(self.archivo, "w", encoding="utf-8") as f:
                        f.writelines(lineas)

                    print(f"Todas las entradas de {bitacora} han sido borradas.")
                except Exception as e:
                    print(f"Error al borrar las entradas: {e}")
            else:
                print("Operación de borrado cancelada.")
        else:
            try:
                with open(self.archivo, "r", encoding="utf-8") as f:
                    lineas = f.readlines()

                ultima_linea_idx = -1
                for i in range(len(lineas) - 1, -1, -1):
                    if lineas[i].strip().startswith(f"{bitacora} "):
                        ultima_linea_idx = i
                        break

                if ultima_linea_idx != -1:
                    lineas.pop(ultima_linea_idx)
                    with open(self.archivo, "w", encoding="utf-8") as f:
                        f.writelines(lineas)

                    print(f"Última entrada de {bitacora} borrada.")
                else:
                    print(f"No hay entradas para {bitacora}")
            except Exception as e:
                print(f"Error al modificar el archivo: {e}")


if __name__ == "__main__":
    import sys

    cfg = cargar_config()

    archivo_cfg = cfg.get("archivo", "/mnt/c/Users/jfons/Documents/MEGA/@nube/bits.txt")
    editor_cfg = cfg.get("editor", "micro")
    show_cfg = cfg.get("show", "cat")

    bit = Bitacora(archivo=archivo_cfg, editor=editor_cfg, show=show_cfg)

    args = sys.argv[1:]

    if len(args) == 0:
        print("Bitácoras:")
        bit.listar()
        sys.exit(0)

    extra = None
    bitacora = args[0]

    if bitacora.startswith(("+", "_", "/", "-")):
        extra = bitacora[0]
        bitacora = bitacora[1:]

    if len(args) == 1:
        if extra == "+":
            bit.editar(bitacora)
        elif extra == "_":
            bit.borrar(bitacora, True)
        elif extra == "/":
            bit.directorio(bitacora)
        elif extra == "-":
            bit.borrar(bitacora, False)
        else:
            bit.mostrar(bitacora)
        sys.exit(0)

    if len(args) > 1:
        texto = " ".join(args[1:])
        bit.agregar(bitacora, texto)
        if extra == "+":
            bit.editar(bitacora)
        sys.exit(0)
