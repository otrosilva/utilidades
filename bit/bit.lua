#!/usr/bin/env lua5.4

-- Script para ver, guardar y editar bitácoras en formato txt.
--
local Bitacora = {}
Bitacora.__index = Bitacora

--- Constructor de Bitacora.
function Bitacora.new(ruta, editor, show)
    -- Expandir la ruta si comienza con ~
    if string.sub(ruta, 1, 1) == "~" then
        local home = os.getenv("HOME")
        if home then
            ruta = home .. string.sub(ruta, 2)
        end
    end

    -- Revisar si la ruta existe sino, salir
    local command = "ls -d " .. ruta .. " 2>/dev/null"
    local file = io.popen(command, "r")

    if not file then
        print("Error al ejecutar el comando: " .. command)
        os.exit(1)
    end

    local result = file:read()
    file:close()

    if not result then
        print("Error: La ruta " .. ruta .. " no existe.")
        os.exit(1)
    end

    local self = setmetatable({}, Bitacora)
    self.ruta = ruta
    self.editor = editor or os.getenv("EDITOR")
    self.show = show or "tail"
    return self
end

--- Depuración: muestra todos los parámetros y funciones de Bitacora
function Bitacora:config()
    -- Mostrar atributos de la instancia (self)
    print("--- Atributos de la instancia ---")
    for key, value in pairs(self) do
        print(key .. ": " .. tostring(value))
    end
    -- Mostrar funciones de la clase (metatabla)
    local metatable = getmetatable(self)
    print("--- Funciones de la clase ---")
    for key, value in pairs(metatable) do
        if type(value) == "function" then
            print(key .. ": function")
        end
    end
    print("--- Fin de la Configuración ---")
end

-- muestra las bitácoras del directorio
function Bitacora:listar()
    local command = "ls " .. self.ruta .. "/*.txt 2>/dev/null" -- Suprimir salida de error
    local handle = io.popen(command)
    local result = handle:read("*a")                           -- Leer toda la salida
    handle:close()

    local txt_files = {} -- ¡Define la tabla txt_files aquí!

    -- Procesar la salida
    for file in result:gmatch("[^\n]+") do
        -- Eliminar la ruta del directorio y la extensión .txt
        local filename = file:match("([^/]+)%.txt$")
        if filename then
            table.insert(txt_files, filename)
        end
    end

    if #txt_files > 0 then
        for _, file in ipairs(txt_files) do
            io.write(file, "\n") -- Usar io.write para controlar la salida
        end
    else
        print("No hay bitácoras")
    end
    return txt_files
end

--- Muestra el contenido con self.show.
function Bitacora:mostrar(bitacora)
    local rutaCompleta = self.ruta .. bitacora .. ".txt"

    local command = self.show .. " " .. rutaCompleta

    local resultado = nil
    local handle = io.popen(command, "r")
    if handle then
        -- Leer la salida del comando e imprimirla
        resultado = handle:read("*a")
        handle:close()
        print(resultado)
    else
        print("Error al ejecutar el comando: " .. command)
    end
    return resultado
end

--- Edita la bitácora con self.editor.
function Bitacora:editar(bitacora)
    local rutaCompleta = self.ruta .. bitacora .. ".txt"
    local command = self.editor .. " " .. rutaCompleta
    local resultado = os.execute(command)
    if resultado == 0 or resultado == true then
        print("Archivo " .. bitacora .. ".txt editado exitosamente.")
    else
        print("Error al ejecutar el editor: " .. command)
        print("Código de salida: " .. tostring(resultado))
    end
end

function Bitacora:agregar(bitacora, texto)
    local rutaCompleta = self.ruta .. bitacora .. ".txt"
    local archivo, errorMensaje = io.open(rutaCompleta, "a") -- append
    if not archivo then
        print("Error al abrir el archivo: " .. errorMensaje)
        return
    end
    local prefijo = os.date("%Y-%m-%d %H:%M:%S") .. " [" .. bitacora .. "]"
    local log_entry = string.format("%s: %s", prefijo, texto)
    archivo:write(log_entry .. "\n")
    archivo:close()
    print("Nueva entrada agregada exitosamente al archivo " .. bitacora .. ".txt")
end

function Bitacora:borrar(bitacora, todo)
    todo = (todo == nil) and false or todo
    local rutaCompleta = self.ruta .. bitacora .. ".txt"
    if todo then
        io.write("¿Está seguro de que desea borrar el archivo " .. bitacora .. ".txt? (s/n): ")
        local confirmacion = io.read()
        if confirmacion == "s" then
            local command = "rm " .. rutaCompleta
            local resultado = os.execute(command)
            if resultado == 0 then
                print("Archivo " .. bitacora .. ".txt borrado exitosamente.")
            else
                print("Error al borrar el archivo: " .. command)
            end
        else
            print("Operación de borrado cancelada.")
        end
    else
        -- Borrar la última línea sin confirmación
        local lineas = {}
        local archivoLectura, errorLectura = io.open(rutaCompleta, "r")
        if not archivoLectura then
            print("Error al abrir el archivo para lectura: " .. errorLectura)
            return
        end
        for linea in archivoLectura:lines() do
            table.insert(lineas, linea)
        end
        archivoLectura:close()

        if #lineas > 0 then
            table.remove(lineas, #lineas) -- Elimina la última línea
        end
        local archivoEscritura, errorEscritura = io.open(rutaCompleta, "w")
        if not archivoEscritura then
            print("Error al abrir el archivo para escritura: " .. errorEscritura)
            return
        end

        for i, linea in ipairs(lineas) do
            archivoEscritura:write(linea .. "\n")
        end
        archivoEscritura:close()
        print("Última línea borrada de " .. bitacora)
    end
end

-- Ruta de la carpeta que contiene los registros
local Bit = Bitacora.new("~/Documentos/Nube/bit/", "hx +9999", "cat")
-- local Bit = Bitacora.new("~/bits/", "hx +9999", "cat")

-- arg == 0 -- Cero argumentos: mostrar los archivos en el directorio
if #arg == 0 then
    print("Bitácoras:")
    Bit:listar()
    os.exit(0)
end

-- #arg >= 0 --  Uno o más argumentos
-- extra - ejecuta más cosas
local extra = nil
local extras = "+-"
if string.find(extras, arg[1]:sub(1, 1)) then
    extra = arg[1]:sub(1, 1)
    bitacora = arg[1]:sub(2)
else
    bitacora = arg[1]
end

-- #arg == 1 -- Un argumento
if #arg == 1 then
    if extra == "+" then
        Bit:editar(bitacora)
    elseif extra == "-" then
        Bit:borrar(bitacora, true)
    else
        Bit:mostrar(bitacora)
    end
    os.exit(0)
end

-- #arg >=2 -- más de un argumento
if #arg > 1 then
    texto = table.concat(arg, " ", 2)
    Bit:agregar(bitacora, texto)
    if extra == "+" then
        Bit:editar(bitacora)
    end
    os.exit(0)
end
