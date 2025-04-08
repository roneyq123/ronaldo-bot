-------------------------------------------------
---------------------- BOT ----------------------
-------------------------------------------------

local discordia = require("discordia")
local client = discordia.Client()

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("config.json"))

----------
-- INIT --
----------

client:on("ready",function()
	print(os.date("%H:%M:%S").." | \27[1;36m[START]\27[0m Logged in as "..client.user.username.." in "..client.guilds:count().." guilds")
end)

-------------
-- MODULES --
-------------

local dir = debug.getinfo(1).source:match("@?(.*/)")
for name in io.popen("find "..dir.."modules -type f -name '*.lua' -not -path '*/.*'"):lines() do
	local m = require("./modules/"..name:gsub(dir.."modules/",""))
	if type(m) == "table" then
		if m.ready then for _,funct in pairs(m.ready) do client:on("ready",function() funct(client) end) end end
		if m.messageCreate then for _,funct in pairs(m.messageCreate) do client:on("messageCreate",function(message) funct(message,client) end) end end
		if m.messageDelete then for _,funct in pairs(m.messageDelete) do client:on("messageDelete",function(message) funct(message,client) end) end end
		if m.reactionAdd then for _,funct in pairs(m.reactionAdd) do client:on("reactionAdd",function(reaction,userId) funct(reaction,userId,client) end) end end
		if m.reactionAddUncached then for _,funct in pairs(m.reactionAddUncached) do client:on("reactionAddUncached",function(channel,messageId,hash,userId) funct(channel,messageId,hash,userId,client) end) end end
	end
end

---------------
-- START BOT --
---------------

client:run("Bot "..Config.BotToken)