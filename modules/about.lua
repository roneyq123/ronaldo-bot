-------------------------------------------------
--------------------- ABOUT ---------------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local timer = require("timer")

local cooldown = {}

---------------
-- FUNCTIONS --
---------------

local function Cooldown(id,time)
	if cooldown[id] then return false end
	cooldown[id] = true
	timer.setTimeout((time or 5)*1000,function() cooldown[id] = nil end)
	return true
end

------------
-- EVENTS --
------------

local function About(message,client) -- messageCreate event
	if not message.guild then return end
	if message.author.bot then return end

	if message.content ~= "<@"..client.user.id..">" then return end
	if message.referencedMessage then return end

	if not Cooldown(message.guild.id,60) then return end

	message.channel:send{
		content = Config.AboutMessage:gsub("|guild|",message.guild.name),
		reference = {message=message,mention=false}
	}
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	messageCreate = {About},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
