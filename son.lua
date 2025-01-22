#!/usr/bin/env lua

function validar(si, respuesta)
	-- Validar respuesta a si, el resto no
	local si = string.lower(si)
	local respuesta = string.lower(respuesta)
	if si == respuesta then
		os.exit(0) -- respuesta es si
	elseif #respuesta == 1 and string.sub(si, 1, 1) == respuesta then -- respuesta es una sola letra
		os.exit(0) -- respuesta es una sóla letra e igual al inicio de la opción si
	end
	-- todo lo demás significa no
	os.exit(1)
end

function help()
	print("Uso: ./son.lua [OpciónSi] [OpciónNo] [Mensaje]")
	print("Regresa 0 si se responde con OpciónSi o la primera letra, de lo contrario 1")
end

function main(valor_si)
	-- mostrar si el primer argumento es --help
	if #arg == 1 and arg[1] == "--help" then
		help()
		return
	end

	-- el primer argumento o "si"
	local si = arg[1] or valor_si or "Si"
	-- el segundo argumento añadiendo "/" o nada
	local no = (arg[2] and "/" .. arg[2]) or ""
	-- el resto de los argumentos con un espacio
	local mensaje = #arg >= 3 and table.concat(arg, " ", 3) .. ", " or ""
	-- Muestra el mensaje al usuario
	io.write(mensaje .. si .. no .. "? ")
	-- Leer la entrada del usuario
	local respuesta = io.read()
	-- validar la respuesta y salir inmediatamente
	validar(si, respuesta)
end

-- main("Yes")
main()
