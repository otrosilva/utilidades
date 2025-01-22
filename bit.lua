#!/usr/bin/env lua
local os = require("os")
local io = require("io")
local arg = { ... } -- Command line arguments

-- Configuration
local base_path = os.getenv("HOME") .. "/iCloud/Docs/Registros"
local show_command = "tail -n 5" -- Command to display the log
local editor = os.getenv("EDITOR") or "hx" -- Define your editor here
local editor_args = "+99999" -- Arguments passed to the editor

-- Function to check if a directory exists
local function dir_exists(path)
	local file = io.open(path, "r")
	if file then
		local _, _, code = file:read(1)
		file:close()
		return code == 21 -- 21 is the error code for "Is a directory"
	else
		return false
	end
end

-- Function to display help
local function show_help()
	print([[
Usage: bit.lua [options] [title] [content]

Description:
This script manages log entries in text files located in the user's iCloud/Docs/Registros directory.

Options:
  title        The title of the log entry (used as the filename without the .txt extension).
  content      The content to log. If provided, it appends a timestamped entry to the log file.
               If no content is provided, it displays the last 5 lines of the log file.
               If the title starts with '+', it opens the log file in the specified editor.

Commands:
  - If no arguments are provided, lists all .txt files (titles) in the directory.
  - If the title is provided without content, displays the last 5 lines of the corresponding log file.
  - If the title is prefixed with '+', opens the log file in the specified editor.
  - If content is provided, appends it to the log file with a timestamp.

Environment Variables:
  HOME         The base directory for log files.
  EDITOR       The default text editor to use (defaults to 'hx' if not set).
]])
	os.exit(0)
end

-- Check for --help argument
if arg[1] == "--help" then
	show_help()
end

-- Check if the base path exists
if not dir_exists(base_path) then
	print("Directory " .. base_path .. " does not exist.")
	os.exit(1)
end

-- Function to list .txt files in a given directory using standard libraries
-- Function to list .txt files in a given directory using standard Lua libraries
local function list_txt_files(directory)
	local txt_files = {}

	-- Execute the command to list .txt files
	local command = "ls " .. directory .. "/*.txt 2>/dev/null" -- Suppress error output
	local handle = io.popen(command)
	local result = handle:read("*a") -- Read all output
	handle:close()

	-- Process the output
	for file in result:gmatch("[^\n]+") do
		-- Remove the directory path and the .txt extension
		local filename = file:match("([^/]+)%.txt$")
		if filename then
			table.insert(txt_files, filename)
		end
	end

	return txt_files
end

-- If no arguments are provided, list the .txt files without the extension
if #arg == 0 then
	print("Bit files:")
	local files = list_txt_files(base_path)
	if #files > 0 then
		for _, file in ipairs(files) do
			io.write(file, "\n") -- Use io.write to control output
		end
	else
		print("No bit files found.")
	end
	os.exit(0)
end

-- Check if the first argument starts with '+'
local has_plus = arg[1]:sub(1, 1) == "+"
local title = has_plus and arg[1]:sub(2) or arg[1]
local file_name = title .. ".txt"
local file_path = base_path .. "/" .. file_name

-- If there is no content after the file name
if #arg == 1 then
	if has_plus then
		-- If it has a '+', open the editor
		os.execute(editor .. " " .. editor_args .. " " .. file_path)
	else
		-- If it does not have a '+', display the last 5 lines
		-- Use show_command to display the log file
		os.execute(show_command .. " " .. file_path)
	end
	os.exit(0)
end

-- If there is content, create the log entry with the current date and time
local timestamp = os.date("%Y-%m-%d %H:%M:%S")
local log_entry = string.format("%s [%s]: %s", timestamp, title, table.concat(arg, " ", 2))

-- Create the directory if it does not exist
os.execute('mkdir -p "' .. base_path .. '"')

-- Append the log entry to the end of the file
local file = io.open(file_path, "a")
file:write(log_entry .. "\n")
file:close()
print("Added to [" .. title .. "]")

-- Open the file with the default editor if the first argument had a '+'
if has_plus then
	os.execute(editor .. " " .. editor_args .. " " .. file_path)
end
