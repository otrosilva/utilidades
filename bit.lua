#!/usr/bin/env lua
local os = require("os")
local io = require("io")
local arg = { ... } -- Argumentos de la línea de comandos

-- Configuración
local base_path = os.getenv("HOME") .. "/iCloud/Docs/Registros"
local show_command = "cat" -- Comando para mostrar el registro
local editor = os.getenv("EDITOR") or "hx" -- Define tu editor aquí
local editor_args = "+99999" -- Argumentos pasados al editor

-- Función para comprobar si existe un directorio
local function dir_exists(path)
	local file = io.open(path, "r")
	if file then
		local _, _, code = file:read(1)
		file:close()
		return code == 21 -- 21 es el código de error para "Es un directorio"
	else
		return false
	end
end

-- Función para mostrar ayuda
local function show_help()
	print([[
Uso: bit.lua [opciones] [titulo] [contenido]

Descripción:
Este script gestiona entradas de registro en archivos de texto ubicados en el directorio iCloud/Docs/Registros del usuario.

Opciones:
  titulo        El título de la entrada de registro (se usa como nombre de archivo sin la extensión .txt).
  contenido     El contenido del registro. Si se proporciona, se añade una entrada con la marca de tiempo al archivo de registro.
               Si no se proporciona contenido, muestra las últimas 5 líneas del archivo de registro.
               Si el título comienza con '+', abre el archivo de registro en el editor especificado.

Comandos:
  - Si no se proporcionan argumentos, lista todos los archivos .txt (títulos) en el directorio.
  - Si se proporciona solo el título sin contenido, muestra las últimas 5 líneas del archivo de registro correspondiente.
  - Si el título empieza con '+', abre el archivo de registro en el editor especificado.
  - Si se proporciona contenido, lo añade al archivo de registro con una marca de tiempo.

Variables de Entorno:
  HOME          El directorio base para los archivos de registro.
  EDITOR        El editor de texto predeterminado a utilizar (por defecto es 'hx' si no está configurado).
]])
	os.exit(0)
end

-- Comprobar el argumento --help
if arg[1] == "--help" then
	show_help()
end

-- Comprobar si existe el directorio base
if not dir_exists(base_path) then
	print("El directorio " .. base_path .. " no existe.")
	os.exit(1)
end

-- Función para listar archivos .txt en un directorio dado
local function list_txt_files(directory)
	local txt_files = {}

	-- Ejecutar el comando para listar archivos .txt
	local command = "ls " .. directory .. "/*.txt 2>/dev/null" -- Suprimir salida de error
	local handle = io.popen(command)
	local result = handle:read("*a") -- Leer toda la salida
	handle:close()

	-- Procesar la salida
	for file in result:gmatch("[^\n]+") do
		-- Eliminar la ruta del directorio y la extensión .txt
		local filename = file:match("([^/]+)%.txt$")
		if filename then
			table.insert(txt_files, filename)
		end
	end

	return txt_files
end

-- Si no se proporcionan argumentos, listar los archivos .txt sin la extensión
if #arg == 0 then
	print("Archivos de registro:")
	local files = list_txt_files(base_path)
	if #files > 0 then
		for _, file in ipairs(files) do
			io.write(file, "\n") -- Usar io.write para controlar la salida
		end
	else
		print("No se encontraron archivos de registro.")
	end
	os.exit(0)
end

-- Comprobar si el primer argumento empieza con '+'
local has_plus = arg[1]:sub(1, 1) == "+"
local title = has_plus and arg[1]:sub(2) or arg[1]
local file_name = title .. ".txt"
local file_path = base_path .. "/" .. file_name

-- Si no hay contenido después del nombre del archivo
if #arg == 1 then
	if has_plus then
		-- Si tiene un '+', abrir el editor
		os.execute(editor .. " " .. editor_args .. " " .. file_path)
	else
		-- Si no tiene un '+', mostrar las últimas 5 líneas
		-- Usar show_command para mostrar el archivo de registro
		os.execute(show_command .. " " .. file_path)
	end
	os.exit(0)
end

-- Si hay contenido, crear la entrada en el registro con la fecha y hora actual
local timestamp = os.date("%Y-%m-%d %H:%M:%S")
local log_entry = string.format("%s [%s]: %s", timestamp, title, table.concat(arg, " ", 2))

-- Crear el directorio si no existe
os.execute('mkdir -p "' .. base_path .. '"')

-- Añadir la entrada al final del archivo
local file = io.open(file_path, "a")
file:write(log_entry .. "\n")
file:close()
print("Añadido a [" .. title .. "]")

-- Abrir el archivo con el editor predeterminado si el primer argumento tenía un '+'
if has_plus then
	os.execute(editor .. " " .. editor_args .. " " .. file_path)
end
