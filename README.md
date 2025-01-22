# Algunos scripts útiles

## bit.lua -- una bitácora estilo log
 - se guardan en la ubicación seleccionada en el script.
 - Uso:
```
lua bit.lua [+][bitacora [texto]] 
```
 - \+ abre el editor con la bitácora seleccionada.

## son.lua -- Si o No 
```
❯ lua son.lua --help
Uso: ./son.lua [OpciónSi] [OpciónNo] [Mensaje]
Regresa 0 si se responde con OpciónSi o la primera letra, de lo contrario 1

> lua son.lua Yes; echo $?
Yes? y
0
```

