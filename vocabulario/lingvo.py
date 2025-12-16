#!/usr/bin/env python3
"""
lingvo.py - Generador de audio RU + ES

Entrada:
  archivo.txt  (líneas: ruso@español)

Salida:
  archivo.mp3
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# ---------- CONFIGURACIÓN ----------

RUSSIAN_VOICE = "Aleksandr-hq"

PIPER_CMD = "piper"
PIPER_DATA_DIR = Path.home() / ".local/share/piper"

ES_MODEL = PIPER_DATA_DIR / "es/es_ES-sharvard-medium.onnx"

LENGTH_SCALE = "1.05"
NOISE_SCALE = "0.4"
NOISE_W_SCALE = "0.8"

SAMPLE_RATE = "22050"
CHANNELS = "1"
BIT_DEPTH = "16"

# ---------- UTILIDADES ----------


def die(msg: str):
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)


def check_cmd(cmd: str):
    if shutil.which(cmd) is None:
        die(f"'{cmd}' no está en el PATH")


def run(cmd, *, input_text=None):
    subprocess.run(cmd, input=input_text, text=True, check=True)


# ---------- MAIN ----------


def main():
    if len(sys.argv) != 2:
        die("Uso: lingvo.py <archivo_vocabulario.txt>")

    input_file = Path(sys.argv[1])
    if not input_file.is_file():
        die(f"No existe el archivo '{input_file}'")

    # Dependencias
    for cmd in ("sox", "ffmpeg", PIPER_CMD):
        check_cmd(cmd)

    # RHVoice
    rhvoice = shutil.which("RHVoice-test") or shutil.which("rhvoice.test")
    if not rhvoice:
        die("RHVoice-test / rhvoice.test no encontrado")

    # Modelo Piper (solo español)
    if not ES_MODEL.exists() or not ES_MODEL.with_suffix(".onnx.json").exists():
        die(f"Falta el modelo Piper de español:\n  {ES_MODEL}")

    base_name = input_file.stem

    with tempfile.TemporaryDirectory(prefix="lingvo_") as tmp:
        tmpdir = Path(tmp)
        index = 1000
        caf_files = []

        # -------- PROGRESO --------
        lines = [
            line
            for line in input_file.read_text(encoding="utf-8").splitlines()
            if "@" in line and line.strip()
        ]
        total_steps = len(lines) * 2
        current_step = 0

        for line in lines:
            ru, es = (s.strip() for s in line.split("@", 1))
            if not ru or not es:
                continue

            # ---------- RUSO (RHVoice) ----------
            current_step += 1
            print(f"[{current_step}/{total_steps}] RU: {ru}", flush=True)

            index += 1
            wav_ru = tmpdir / f"{index}.wav"
            caf_ru = tmpdir / f"{index}.caf"

            run([rhvoice, "-p", RUSSIAN_VOICE, "-o", str(wav_ru)], input_text=ru)

            run(
                [
                    "sox",
                    str(wav_ru),
                    "-r",
                    SAMPLE_RATE,
                    "-c",
                    CHANNELS,
                    "-b",
                    BIT_DEPTH,
                    str(caf_ru),
                ]
            )

            wav_ru.unlink()
            caf_files.append(caf_ru)

            # ---------- ESPAÑOL (Piper) ----------
            current_step += 1
            print(f"[{current_step}/{total_steps}] ES: {es}", flush=True)

            index += 1
            wav_es = tmpdir / f"{index}.wav"
            caf_es = tmpdir / f"{index}.caf"

            run(
                [
                    PIPER_CMD,
                    "-m",
                    str(ES_MODEL),
                    "--data-dir",
                    str(PIPER_DATA_DIR),
                    "--length-scale",
                    LENGTH_SCALE,
                    "--noise-scale",
                    NOISE_SCALE,
                    "--noise-w-scale",
                    NOISE_W_SCALE,
                    "-f",
                    str(wav_es),
                ],
                input_text=es,
            )

            run(
                [
                    "sox",
                    str(wav_es),
                    "-r",
                    SAMPLE_RATE,
                    "-c",
                    CHANNELS,
                    "-b",
                    BIT_DEPTH,
                    str(caf_es),
                ]
            )

            wav_es.unlink()
            caf_files.append(caf_es)

        if not caf_files:
            die("No se generó audio")

        caf_out = Path(f"{base_name}.caf")
        run(["sox", *map(str, caf_files), str(caf_out)])

        # ---------- MP3 ----------
        ffmpeg_cmd = ["ffmpeg", "-y", "-i", str(caf_out)]

        if Path("cover.jpg").exists():
            ffmpeg_cmd += ["-i", "cover.jpg", "-map", "1"]

        ffmpeg_cmd += [
            "-map",
            "0",
            "-c:a",
            "libmp3lame",
            "-q:a",
            "2",
            "-metadata",
            f"title={base_name}",
            "-metadata",
            "artist=Lingvo",
            "-metadata",
            "album=Vocabulario",
            "-metadata",
            f"comment=Archivo: {base_name}",
            f"{base_name}.mp3",
        ]

        run(ffmpeg_cmd)
        caf_out.unlink()

    print(f"✔ Proceso completado: {base_name}.mp3")


# ---------- ENTRY ----------

if __name__ == "__main__":
    main()
