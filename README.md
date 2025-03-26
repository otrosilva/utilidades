# Algunos scripts útiles

## bit.lua -- una bitácora estilo log
 - se guardan en la ubicación seleccionada en el script.
 - Uso:
```
lua bit.lua [+][bitacora [texto]]
```
 - \+ abre el editor con la bitácora seleccionada.

## son.lua -- Si o No
❯ lua son.lua --help
- Regresa 0 si se responde con OpciónSi o la primera letra, de lo contrario 1
- Uso: ./son.lua [OpciónSi] [OpciónNo] [Mensaje]
```
> lua son.lua Yes; echo $?
Yes? y
0
```
## bot.lua/bot.sh
 - Avisa por telegram si ha cambiado alguna de las urls.
- usa bot.config para la configuración del token de telegram.
 - Uso:
 ```
lua bot.lua chat_id url1 url2 ..
sh bot.sh chat_id url1 url2 ..
```
## server-status.sh
- envía un reporte diario del servidor por telegram.
- usa bot.config para la configuración del token de telegram.
- Uso:
```
 sh server-status.sh
```
## backup.sh
- para respaldar servidores de forma sencilla.
- Uso:
```
 sh backup.sh IP/hostname
```
