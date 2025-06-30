; -----------------------------------------------------------------------------
; Script: Recordatorios para Obsidian
; Descripción:
;   Busca el archivo con la fecha actual y muestra los recordatorios si la hora corresponde.
; Archivo en Obsidian: WorkingDir/YYYY-MM-DD.md
; Contenido:
;   HH:MM MENSAJE
;   ~~HH:MM RECORDATORIO YA MOSTRADO~~
;
;   ----
;   CONTENIDO QUE NO SE CAMBIA.
; -----------------------------------------------------------------------------

﻿#Requires AutoHotkey v2.0
SetWorkingDir A_MyDocuments "\Ventas\"

miIcono := A_WinDir "\System32\shell32.dll"
TraySetIcon(miIcono, 44)

ultimaHoraMostrada := -1

SetTimer(ProcesarRecordatorios, 60 * 1000)
ProcesarRecordatorios()

ProcesarRecordatorios() {
    global ultimaHoraMostrada

    ahora_hora := A_Hour + 0
    ahora_min := A_Min + 0
    ahora_total := ahora_hora * 60 + ahora_min

    if (ahora_min = 0 && ahora_hora != ultimaHoraMostrada) {
        TrayTip("🕒", "Son las " Format("{:02}", ahora_hora) ":00")
        ultimaHoraMostrada := ahora_hora
    }

    archivo := FormatTime(, "yyyy-MM-dd") ".md"
    if !FileExist(archivo)
        return

    contenido := FileRead(archivo, "UTF-8")
    lineas := StrSplit(contenido, "`n")
    nuevaSeccion := []
    despuesDelimitador := ""
    encontrado := false

    for i, linea in lineas {
        texto := Trim(linea)

        if !encontrado {
            if texto = "----" {
                nuevaSeccion.Push(linea)
                encontrado := true
                despuesDelimitador := SubStr(contenido, InStr(contenido, linea) + StrLen(linea) + 1)
                break
            }

            if RegExMatch(texto, "^\s*~~(\d{1,2}):(\d{2})\s+(.+?)~~\s*$") {
                nuevaSeccion.Push(linea)
                continue
            }

            if RegExMatch(texto, "^\s*(\d{1,2}):(\d{2})\s+(.+)", &m) {
                totalMin := m[1] * 60 + m[2]
                if totalMin = ahora_total || totalMin = ahora_total - 1 {
                    TrayTip("⏰ Recordatorio", m[1] ":" m[2] " → " m[3])
                    nuevaSeccion.Push("~~" m[1] ":" m[2] " " m[3] "~~")
                    continue
                }
            }

            nuevaSeccion.Push(linea)
        }
    }

    if nuevaSeccion.Length > 0 {
        nuevoContenido := ""
        for _, l in nuevaSeccion
            nuevoContenido .= l "`n"

        if despuesDelimitador != ""
            nuevoContenido .= RTrim(despuesDelimitador, "`n")

        f := FileOpen(archivo, "w", "UTF-8")
        if f {
            f.Write(RTrim(nuevoContenido, "`n"))
            f.Close()
        }
    }
}
