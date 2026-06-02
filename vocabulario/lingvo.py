#!/bin/env python3
"""
lingvo.py - Generador de audio RU + ES con descarga automática de voces
Entrada: archivo.txt (líneas: ruso@español)
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
                # Descarga directa vía HTTP
                urllib.request.urlretrieve(url, archivo)
            except Exception as e:
                if archivo.exists():
                    archivo.unlink()
                die(f"No se pudo descargar {url}.\nDetalle: {e}")


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

    # Validar o autodescargar los modelos de voz necesarios de forma segura
    asegurar_modelo(RU_MODEL, RU_URL)
    asegurar_modelo(ES_MODEL, ES_URL)

    base_name = input_file.stem

    # Filtrar y preparar líneas válidas
    lines = [
        line for line in input_file.read_text(encoding="utf-8").splitlines()
        if "@" in line and line.strip()
    ]
    
    if not lines:
        die("El archivo de vocabulario está vacío o no contiene el separador '@'")

    total_steps = len(lines) * 2
    current_step = 0

    with tempfile.TemporaryDirectory(prefix="lingvo_") as tmp:
        tmpdir = Path(tmp)
        audio_files = []
        index = 1000

        for line in lines:
            ru, es = (s.strip() for s in line.split("@", 1))
            if not ru or not es:
                continue

            # ---------- GENERAR RUSO ----------
            current_step += 1
            print(f"[{current_step}/{total_steps}] RU: {ru}", flush=True)
            
            index += 1
            wav_ru = tmpdir / f"{index}.wav"
            generar_audio_piper(ru, RU_MODEL, wav_ru)
            audio_files.append(str(wav_ru))

            # ---------- GENERAR ESPAÑOL ----------
            current_step += 1
            print(f"[{current_step}/{total_steps}] ES: {es}", flush=True)
            
            index += 1
            wav_es = tmpdir / f"{index}.wav"
            generar_audio_piper(es, ES_MODEL, wav_es)
            audio_files.append(str(wav_es))

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

        if Path("cover.jpg").exists():
            ffmpeg_cmd += ["-i", "cover.jpg", "-map", "1"]

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
