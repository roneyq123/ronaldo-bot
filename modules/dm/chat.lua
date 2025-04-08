-------------------------------------------------
---------------------- CHAT ---------------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local timer = require("timer")

local channel

---------------
-- FUNCTIONS --
---------------

local function SendMessage(message,client)
	-- Check if a channel is configured
	if not channel then
		local response = message.channel:send{content="No channel configured.",reference={message=message,mention=false}}
		timer.sleep(5000) response.delete(response)
		return
	end

	-- If is configured, send the message
	local chat = channel:send{content=message.content:sub(6)}
	local response = message.channel:send{content="Message sent: "..chat.link,reference={message=message,mention=false}}
	timer.sleep(5000) response.delete(response)
end

local function Configuration(message,client)
	-- Check if message has a valid URL
	local link = message.content:sub(7)
	if link:sub(1,29) ~= "https://discord.com/channels/" then
		local response = message.channel:send{content="Link not valid.",reference={message=message,mention=false}}
		channel = nil timer.sleep(5000) response.delete(response)
		return
	end

	-- Parse link to get guild ID and channel ID
	local tbl = {}
	for i in link:gmatch("([^/]+)") do table.insert(tbl,i) end

	if not tbl[4] or not tbl[5] then
		local response = message.channel:send{content="Couldn't parse URL.",reference={message=message,mention=false}}
		channel = nil timer.sleep(5000) response.delete(response)
		return
	end

	-- Get guild object
	channel = client:getGuild(tbl[4])
	if not channel then
		local response = message.channel:send{content="Couldn't get guild.",reference={message=message,mention=false}}
		channel = nil timer.sleep(5000) response.delete(response)
	end

	-- Get channel object
	channel = channel:getChannel(tbl[5])
	if not channel then
		local response = message.channel:send{content="Couldn't get channel.",reference={message=message,mention=false}}
		channel = nil timer.sleep(5000) response.delete(response)
	end

	-- Feedback that everything is good
	local response = message.channel:send{content="Current channel: "..channel.mentionString,reference={message=message,mention=false}}
	timer.sleep(5000) response.delete(response)
end

------------
-- EVENTS --
------------

local function Chat(message,client) -- messageCreate event
	if message.guild then return end
	if message.author.bot then return end

	if message.author.id ~= Config.OwnerID then return end

	if message.content:sub(1,5):lower() == "chat " then SendMessage(message,client) end
	if message.content:sub(1,6):lower() == "chatc " then Config(message,client) end
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	messageCreate = {Chat},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
