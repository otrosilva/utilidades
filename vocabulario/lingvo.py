#!/bin/env python3
"""
lingvo.py - Generador de audio RU + ES con detección de idioma y carátula optimizada
Entrada: archivo.txt (líneas: ruso@español, o líneas de un solo idioma)
Salida: archivo.mp3
"""

import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# ---------- CONFIGURACIÓN ----------
PIPER_CMD = "piper"
PIPER_DATA_DIR = Path.home() / ".local/share/piper"

# Modelos y sus URLs oficiales en Hugging Face
RU_MODEL = PIPER_DATA_DIR / "ru/ru_RU-denis-medium.onnx"
RU_URL = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/denis/medium/ru_RU-denis-medium.onnx"

ES_MODEL = PIPER_DATA_DIR / "es/es_ES-sharvard-medium.onnx"
ES_URL = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx"

# Parámetros de voz Piper
LENGTH_SCALE = "1.05"
NOISE_SCALE = "0.4"
NOISE_W_SCALE = "0.8"

# Estándar unificado para SoX
SAMPLE_RATE = "22050"
CHANNELS = "1"
BIT_DEPTH = "16"

# ---------- UTILIDADES ----------

def die(msg: str):
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)


def check_cmd(cmd: str):
    if shutil.which(cmd) is None:
        die(f"'{cmd}' no está instalado o no se encuentra en el PATH")


def asegurar_modelo(modelo_path: Path, url_base: str):
    """Verifica si el modelo y su json existen; si no, los descarga."""
    for ext in ("", ".json"):
        archivo = Path(str(modelo_path) + ext)
        url = url_base + ext
        
        if not archivo.exists():
            archivo.parent.mkdir(parents=True, exist_ok=True)
            print(f"Descargando componente necesario: {archivo.name}...", flush=True)
            try:
                urllib.request.urlretrieve(url, archivo)
            except Exception as e:
                if archivo.exists():
                    archivo.unlink()
                die(f"No se pudo descargar {url}.\nDetalle: {e}")


def es_ruso(texto: str) -> bool:
    """Detecta si el texto contiene caracteres del alfabeto cirílico."""
    return any('\u0400' <= char <= '\u04FF' for char in texto)


def generar_audio_piper(texto: str, modelo: Path, output_wav: Path):
    """Ejecuta Piper enviando el texto por stdin y guardando el WAV."""
    cmd = [
        PIPER_CMD,
        "-m", str(modelo),
        "--data-dir", str(PIPER_DATA_DIR),
        "--length-scale", LENGTH_SCALE,
        "--noise-scale", NOISE_SCALE,
        "--noise-w-scale", NOISE_W_SCALE,
        "-f", str(output_wav)
    ]
    subprocess.run(cmd, input=texto, text=True, check=True, stderr=subprocess.DEVNULL)

# ---------- MAIN ----------

def main():
    if len(sys.argv) != 2:
        die("Uso: lingvo.py <archivo_vocabulario.txt>")

    input_file = Path(sys.argv[1])
    if not input_file.is_file():
        die(f"No existe el archivo '{input_file}'")

    # Verificar que las herramientas del sistema estén instaladas
    for cmd in ("sox", "ffmpeg", PIPER_CMD):
        check_cmd(cmd)

    # Validar o autodescargar los modelos de voz necesarios
    asegurar_modelo(RU_MODEL, RU_URL)
    asegurar_modelo(ES_MODEL, ES_URL)

    base_name = input_file.stem

    # Leer todas las líneas no vacías
    raw_lines = [
        line.strip() for line in input_file.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    
    if not raw_lines:
        die("El archivo de vocabulario está vacío")

    # Analizar qué bloques de audio necesitamos generar por cada línea
    tareas = []
    for line in raw_lines:
        if "@" in line:
            ru, es = (s.strip() for s in line.split("@", 1))
            if ru: tareas.append(("RU", ru))
            if es: tareas.append(("ES", es))
        else:
            if es_ruso(line):
                tareas.append(("RU", line))
            else:
                tareas.append(("ES", line))

    total_steps = len(tareas)
    if total_steps == 0:
        die("No se encontraron frases válidas para procesar")

    current_step = 0

    with tempfile.TemporaryDirectory(prefix="lingvo_") as tmp:
        tmpdir = Path(tmp)
        audio_files = []
        index = 1000

        for idioma, texto in tareas:
            current_step += 1
            print(f"[{current_step}/{total_steps}] {idioma}: {texto}", flush=True)
            
            index += 1
            wav_out = tmpdir / f"{index}.wav"
            
            modelo = RU_MODEL if idioma == "RU" else ES_MODEL
            generar_audio_piper(texto, modelo, wav_out)
            audio_files.append(str(wav_out))

        # ---------- CONCATENACIÓN TOTAL ----------
        print("Unificando pistas de audio...", flush=True)
        wav_master = tmpdir / "master.wav"
        
        subprocess.run([
            "sox", *audio_files, 
            "-r", SAMPLE_RATE, 
            "-c", CHANNELS, 
            "-b", BIT_DEPTH, 
            str(wav_master)
        ], check=True)

        # ---------- COMPRESIÓN A MP3 FINAL ----------
        print("Compilando archivo MP3 con metadatos...", flush=True)
        ffmpeg_cmd = ["ffmpeg", "-y", "-v", "error", "-i", str(wav_master)]

        # Buscar cover en formatos comunes dentro del directorio actual
        cover_path = None
        for ext in (".jpg", ".jpeg", ".png"):
            img_test = Path(f"cover{ext}")
            if img_test.exists():
                cover_path = img_test
                break

        if cover_path:
            # -vf redimensiona a 300x300, mantiene aspecto y añade fondo negro si no era cuadrada
            ffmpeg_cmd += [
                "-i", str(cover_path), 
                "-map", "1",
                "-vf", "scale=300:300:force_original_aspect_ratio=decrease,pad=300:300:(ow-iw)/2:(oh-ih)/2:black"
            ]

        ffmpeg_cmd += [
            "-map", "0",
            "-c:a", "libmp3lame",
            "-q:a", "2",
            "-metadata", f"title={base_name}",
            "-metadata", "artist=Lingvo",
            "-metadata", "album=Vocabulario",
            "-metadata", f"comment=Generado desde: {input_file.name}",
            f"{base_name}.mp3"
        ]

        subprocess.run(ffmpeg_cmd, check=True)

    print(f"✔ Proceso completado con éxito: {base_name}.mp3")

if __name__ == "__main__":
    main()
