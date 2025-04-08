-------------------------------------------------
---------------------- CHAT ---------------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local http = require("coro-http")
local timer = require("timer")

local channel

---------------
-- FUNCTIONS --
---------------

local function SendRequest(message,client)
	-- Check if message has a valid URL
	local link = message.content:sub(9)
	if link:sub(1,8) ~= "https://" then
		local response = message.channel:send{content="Link not valid.",reference={message=message,mention=false}}
		channel = nil timer.sleep(5000) response.delete(response)
		return
	end

	-- Send GET request
	local res,body
	pcall(function() res,body = http.request("GET",link,{{"User-Agent",Config.UserAgent}}) end)
	if type(res) == "table" then res = json.encode(res) end
	if type(body) == "table" then body = json.encode(body) end

	-- Parse result
	local result = "Unknown error."
	if res then result = "Status:\n"..res
		if body then result = result.."\n\nResponse:\n"..body
		end
	end

	-- Show result
	local response = message.channel:send{file={"result.txt",result},reference={message=message,mention=false}}
	timer.sleep(10000) response.delete(response)
end

------------
-- EVENTS --
------------

local function Request(message,client) -- messageCreate event
	if message.guild then return end
	if message.author.bot then return end

	if message.author.id ~= Config.OwnerID then return end

	if message.content:sub(1,8):lower() == "request " then SendRequest(message,client) end
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	messageCreate = {Request},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
