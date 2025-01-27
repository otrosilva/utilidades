#!/usr/bin/env lua

-- Obtiene la ruta del script
local current_dir = ((debug.getinfo(1, "S").source:match("@(.*)/") or "./") .. "/"):gsub("//", "/")
local config_file = current_dir .. "bot.config"

-- Función para leer el archivo de configuración
function read_toml(file_path)
    local config = {}
    local current_section = nil

    for line in io.lines(file_path) do
        line = line:match("^%s*(.-)%s*$") -- Eliminar espacios en blanco al inicio y al final

        if line:sub(1, 1) == "[" and line:sub(-1) == "]" then
            -- Nueva sección
            current_section = line:sub(2, -2) -- Obtener el nombre de la sección
            config[current_section] = {}
        elseif current_section and line ~= "" then
            -- Procesar clave-valor
            local key, value = line:match("^(%S+)%s*=%s*(.+)$")
            if key and value then
                -- Eliminar comillas del valor
                value = value:gsub('^"%s*(.-)%s*"$', '%1')
                config[current_section][key] = value
            end
        end
    end

    return config
end

-- Leer configuración
local config = read_toml(config_file)

-- Acceder a la configuración de Telegram

if not config["telegram"] then
    print("No se encontró la sección [telegram].")
end


-- Función para enviar mensaje a Telegram
local function send_telegram_message(chat_id, msg)
    local telegram_url = config["telegram"]["url"] -- incluye api token en la url

    -- Usar el formato adecuado para enviar los datos con POST
    local msg_os = string.format(
        'curl -s -X POST "%s" -d "chat_id=%s" -d "text=%s"',
        telegram_url,
        chat_id, -- Asumiendo que el chat_id es pasado como argumento
        msg:gsub(" ", "%%20") -- Codificar espacios en URL
    )

    local result = os.execute(msg_os)

    if result then
        print("Mensaje enviado.")
    else
        print("Error al enviar mensaje.")
    end

    return result
end

local function run_command(command)
	local handle = io.popen(command) -- Ejecutar el comando
	local result = handle:read("*a") -- Leer la salida
	handle:close() -- Cerrar el manejador
	return result
end

local function clean_text(text)
	-- Extraer el contenido entre las etiquetas <body> y </body>
	local body_content = text:match("<body[^>]*>(.-)</body>")
	if body_content then
		text = body_content
	else
		text = "" -- Si no hay contenido en <body>, establecer texto vacío
	end

	text = text:gsub("<[^>]*>", "") -- Eliminar etiquetas HTML
	text = text:gsub("&[a-zA-Z0-9]+;", " ") -- Reemplazar entidades HTML
	text = text:gsub("^%s*(.-)%s*$", "%1") -- Eliminar espacios al inicio y al final
	text = text:gsub("%s+", " ") -- Eliminar espacios múltiples
	return text
end

local function read_file(filename)
	local file = io.open(filename, "r")
	if file then
		local content = file:read("*a")
		file:close()
		return content
	else
		return nil
	end
end

local function write_file(filename, cleaned_text)
	local file = io.open(filename, "w")
	if file then
		file:write(cleaned_text)
		file:close()
	else
		print("Error: No se pudo abrir el archivo para escritura: " .. filename)
	end
end

-- Modificar la función compare_content para enviar el mensaje solo si hay cambios
local function compare_content(url, new_content, filename)
    local old_content = read_file(filename) 
	if not old_content or (old_content ~= new_content) then
		write_file(filename, new_content)
		return true
    else
        return false
    end
end

function log_message(message, filename)
	if not message then
		return
	end
	local log_file = filename or (current_dir .. "bot.log")
    local file, err = io.open(log_file, "a")

    if not file then
        print("Error al abrir el archivo de log: " .. err)
        return
    end

    -- Obtener la fecha y hora actuales
    local date = os.date("%Y-%m-%d %H:%M:%S")

    -- Escribir el mensaje al archivo de log con la marca de tiempo
    file:write(string.format("[%s] %s\n", date, message))

    -- Cerrar el archivo de log
    file:close()
end

local chat_id = arg[1] -- Primer argumento como identificador de chat

-- Procesar sitios web
for i = 2, #arg do
	local URL = arg[i]

	local filename = current_dir .. URL:gsub("https?://", ""):gsub("www%.", ""):gsub("/", "_"):gsub("%.", "_") .. ".txt"

	-- Obtener el contenido de la URL usando curl
	local content = run_command("curl -s " .. URL)

	-- Limpiar el texto
	local cleaned_text = clean_text(content)

	-- Comparar contenido con el archivo existente
	local has_changed = compare_content(URL, cleaned_text, filename)

	-- Solo guardar el texto limpio en un archivo si ha cambiado
	if has_changed then
		log_message(URL .. " ha cambiado.")
		if config["telegram"] then
			if not send_telegram_message(chat_id,config["telegram"]["url"] .. " ha cambiado.") then
				log_message("Error enviando mensaje a telegram")
			end
		end
	end
end
