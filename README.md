# Algunos scripts útiles

## AHK -- scripts para autohotkey en windows

### recordatorios_obsidian.ahk
Continuamente revisa el archivo con la fecha actual en formato YYYY-MM-DD.md compatible con Obsidian.md y muestra los recordatorios por línea en formato "HH:MM MENSAJE".
Ignora los recordatorios que ya han pasado, tachados (Ejemplo: ~~12:05 hola~)
Ignora todo lo que esté luego de la primera línea delimitadora "----"

## bit.lua -- una bitácora estilo log
Para registrar cualquier tipo de eventos al estilo log.
- Uso:
```
lua bit.lua [+][bitacora [texto]]
```

 - \+ abre el editor con la bitácora seleccionada.

## son.lua -- Si o No
Regresa 0 si se responde con OpciónSi o la primera letra, de lo contrario 1
- Uso:
```
> lua son.lua Yes; echo $?
Yes? y
0
```
## bot.lua/bot.sh
Un bot para avisar si hay cambios en sitios web.
 - Uso:
 ```
lua bot.lua chat_id url1 url2 ..
sh bot.sh chat_id url1 url2 ..
```
## status.sh
Envía un reporte diario del servidor por telegram.
- Uso:
```
 sh status.sh
```
## backup.sh
Se usa para respaldar servidores de forma sencilla. Si no existen, crea dos archivos en el servidor remoto: to_backup.txt, to_exclude.txt. Si existen, usa el contenido para saber que respaldar, y que excluir de los respaldos.
- Uso:
```
 sh backup.sh IP/hostname
```

## telegram.sh
Se usa para enviar mensajes usando la api de telegram, se debe usar el archivo de configuración telegram.config.
- Uso:
```
sh telegram.sh mensaje
```
