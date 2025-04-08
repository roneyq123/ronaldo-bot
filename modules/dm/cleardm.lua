-------------------------------------------------
-------------------- CLEAR DM -------------------
-------------------------------------------------

local timer = require("timer")

local cooldown = {}

---------------
-- FUNCTIONS --
---------------

local function Cooldown(id,time)
	if cooldown[id] then return false end
	cooldown[id] = true
	timer.setTimeout((time or 10)*1000,function() cooldown[id] = nil end)
	return true
end

------------
-- EVENTS --
------------

local function ClearDM(message,client) -- messageCreate event
	if message.guild then return end
	if message.author.bot then return end

	if not Cooldown(message.author.id,5) then return end

	if message.content:lower() ~= "clear" then return end

	for message in message.channel:getMessages(100):findAll(function(msg) return msg.author.id == client.user.id end) do message.delete(message) end
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	messageCreate = {ClearDM},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
