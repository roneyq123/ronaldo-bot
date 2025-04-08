-------------------------------------------------
--------------- YOUTUBE EMBED FIX ---------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local EmbedURL = "https://yfxtube.com/watch?v="
local EmbedURL_n = string.len(EmbedURL)

---------------
-- FUNCTIONS --
---------------


local function ExtractLinks(message)
	local links = {}
	for url in string.gmatch(message,"https?://[%w-_%.%?%.:/%+=&@]+") do links[#links+1] = url end
	return links
end

local function YouTube(message,link)
	local urlType = 0

	if string.match(link,"://youtube%.com/") or string.match(link,"%.youtube%.com/") then urlType = 1 end
	if string.match(link,"://youtu%.be/") or string.match(link,"%.youtu%.be/") then urlType = 2 end
	if urlType == 0 then return 0 end

	if urlType == 1 and not string.match(link,"/watch%?v=") then return 1 end

	local videoID
	if urlType == 1 then videoID = string.match(link.."&","%?v=(.-)&")
	else videoID = string.match(link.."?","youtu%.be/(.-)%?") end
	if not videoID then return 1 end

	message.channel:send{ content = EmbedURL..videoID, reference = { message = message.referencedMessage, mention = false }}
	return 1
end

-------------------------------------------------
--------------------- EVENTS --------------------
-------------------------------------------------

local function Embed(message,client) -- messageCreate event
	if not message.guild then return end
	if message.author.bot then return end

	if message.content ~= "<@"..client.user.id..">" then return end
	if not message.referencedMessage then return end

	local links = ExtractLinks(message.referencedMessage.content)
	if #links == 0 then return end

	for _,link in pairs(links) do
		if YouTube(message,link) == 1 then return end
	end
end

local function DeleteUsingReaction(reaction,userId,client) -- reactionAdd event
	if not reaction.message.guild then return end

	if reaction.emojiName ~= "❌" then return end

	if reaction.message.author.id ~= client.user.id then return end

	if not reaction.message.content then return end
	if reaction.message.content:sub(1,EmbedURL_n) ~= EmbedURL then return end

	if not reaction.message.referencedMessage then return end
	if reaction.message.referencedMessage.author.id ~= userId
	and reaction.message.referencedMessage.author.id ~= Config.OwnerID
	then return end

	reaction.message.delete(reaction.message)
end

-----------------------
---- MODULE CONFIG ----
-----------------------

local functions = {
	--[[
	messageCreate = {Embed},
	reactionAdd = {DeleteUsingReaction},
	]] -- Nobody is using it, so it's disabled
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
