local ltask = require "ltask"

local S = {}
local lables = {}
local command = {}
local tasks = {}

local function querylabel(id)
	if not id then
		return "unknown"
	end
	if id == 0 then
		return "system"
	end
	if lables[id] then
		return lables[id]
	end
	return "unknown"
end

local function service(id)
	return ("(%s:%d)"):format(querylabel(id), id)
end

function command.startup(id, label)
	lables[id] = label
	return service(id) .. " startup."
end

function command.quit(id)
	tasks[#tasks+1] = function ()
		lables[id] = nil
	end
	return service(id) .. " quit."
end

function command.service(_, id)
	id = tonumber(id)
	return service(id)
end

local function parse(id, s)
	local name, args = s:match "^([^:]*):(.*)$"
	if not name then
		name = s
		args = nil
	end
	local f = command[name]
	if f then
		return f(id, args)
	end
	return s
end

local function runtask()
	if #tasks > 0 then
		for i = 1, #tasks do
			tasks[i]()
		end
		tasks = {}
	end
end

local function writelog()
	local flush
	while true do
		local ti, id, msg, sz = ltask.poplog()
		if ti == nil then
			if flush then
				io.flush()
			end
			break
		end
		local tsec = ti // 100
		local msec = ti % 100
		local level, message = ltask.unpack_remove(msg, sz)
		message = string.gsub(message, "%$%{([^}]*)%}", function (s)
			return parse(id, s)
		end)
		io.write(string.format("[%s.%02d : %-10s][%-5s]\t%s\n", os.date("%c", tsec), msec, querylabel(id), level:upper(), message))
		flush = true
	end
	runtask()
end

ltask.fork(function()
	while true do
		writelog()
		ltask.sleep(100)
	end
end)

function S.quit()
	writelog()
end

function S.labels()
	return lables
end

return S
