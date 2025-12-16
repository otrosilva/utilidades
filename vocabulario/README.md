# Vocabulario RU–ES

Esta carpeta contiene materiales y un script para generar audio de vocabulario ruso–español a partir de archivos `.txt` con líneas en formato `ruso@español`.

## Requisitos

Paquetes necesarios (ejemplo en Debian/Ubuntu/Pop!_OS):

- rhvoice
- sox
- ffmpeg
- pipx
- espeak-ng-data
- piper-tts (vía `pipx install piper-tts`)

## Uso básico

1. Crea un archivo `.txt` con tu vocabulario (`ruso@español`, una entrada por línea).
2. Ejecuta en esta carpeta:

./lingvo.sh archivo.txt

3. Se generará un archivo `.mp3` con el mismo nombre base (`archivo.mp3`) que contiene las frases en ruso y español en orden.
