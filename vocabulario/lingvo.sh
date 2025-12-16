#!/bin/zsh
#
# lingvo.sh - Generador de audio RU + ES
# Lee líneas "ruso@español" y genera un MP3 final
#

set -euo pipefail

# -------- CONFIGURACIÓN --------

RUSSIAN_VOICE="Aleksandr-hq"

PIPER_CMD="piper"
PIPER_DATA_DIR="$HOME/.local/share/piper"

RU_MODEL="$PIPER_DATA_DIR/ru/ru_RU-ruslan-medium.onnx"
ES_MODEL="$PIPER_DATA_DIR/es/es_ES-sharvard-medium.onnx"

LENGTH_SCALE=1.05
NOISE_SCALE=0.4
NOISE_W_SCALE=0.8

SAMPLE_RATE=22050
CHANNELS=1
BIT_DEPTH=16

# -------- USO --------

if [[ $# -ne 1 ]]; then
  echo "Uso: $0 <archivo_vocabulario.txt>"
  exit 1
fi

input_file="$1"

if [[ ! -f "$input_file" ]]; then
  echo "Error: '$input_file' no existe."
  exit 1
fi

# -------- COMPROBACIONES --------

for cmd in "$PIPER_CMD" sox ffmpeg; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' no está en el PATH."
    exit 1
  fi
done

# RHVoice (detección correcta)
if command -v RHVoice-test &>/dev/null; then
  RHVOICE_CMD="RHVoice-test"
elif command -v rhvoice.test &>/dev/null; then
  RHVOICE_CMD="rhvoice.test"
else
  echo "Error: RHVoice no encontrado (RHVoice-test / rhvoice.test)."
  exit 1
fi

# Modelos Piper
if [[ ! -f "$ES_MODEL" || ! -f "$ES_MODEL.json" ]]; then
  echo "Error: falta el modelo Piper de español o su .json:"
  echo "  $ES_MODEL"
  exit 1
fi


# -------- SETUP --------

base_name="$(basename "$input_file" .txt)"

TMP_DIR="$(mktemp -d ./tmp_lingvo_XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

x=1000

# -------- PROCESO --------

while IFS="@" read -r ru es; do
  [[ -z "${ru// }" || -z "${es// }" ]] && continue

  # --- RUSO (RHVoice) ---
  x=$((x+1))
  echo "$ru" | "$RHVOICE_CMD" \
    -p "$RUSSIAN_VOICE" \
    -o "$TMP_DIR/$x.wav"

  sox "$TMP_DIR/$x.wav" \
    -r "$SAMPLE_RATE" \
    -c "$CHANNELS" \
    -b "$BIT_DEPTH" \
    "$TMP_DIR/$x.caf"

  rm "$TMP_DIR/$x.wav"

  # --- ESPAÑOL (Piper) ---
  x=$((x+1))
  echo "$es" | "$PIPER_CMD" \
    -m "$ES_MODEL" \
    --data-dir "$PIPER_DATA_DIR" \
    --length-scale "$LENGTH_SCALE" \
    --noise-scale "$NOISE_SCALE" \
    --noise-w-scale "$NOISE_W_SCALE" \
    -f "$TMP_DIR/$x.wav"

  sox "$TMP_DIR/$x.wav" \
    -r "$SAMPLE_RATE" \
    -c "$CHANNELS" \
    -b "$BIT_DEPTH" \
    "$TMP_DIR/$x.caf"

  rm "$TMP_DIR/$x.wav"

done < "$input_file"

# -------- COMBINAR --------

caf_files=("$TMP_DIR"/*.caf(N))
if [[ ${#caf_files[@]} -eq 0 ]]; then
  echo "Error: no se generó audio."
  exit 1
fi

sox $(printf '%s\n' "$TMP_DIR"/*.caf | sort -n) "$base_name.caf"

# -------- MP3 FINAL --------

ffmpeg_cmd=(
  ffmpeg -y
  -i "$base_name.caf"
)

if [[ -f cover.jpg ]]; then
  ffmpeg_cmd+=(-i cover.jpg -map 1)
fi

ffmpeg_cmd+=(
  -map 0
  -c:a libmp3lame
  -q:a 2
  -metadata "title=$base_name"
  -metadata "artist=Lingvo"
  -metadata "album=Vocabulario"
  -metadata "comment=Archivo: $base_name"
  "$base_name.mp3"
)

"${ffmpeg_cmd[@]}"

rm -f "$base_name.caf"

echo "✔ Proceso completado: '$base_name.mp3'"
