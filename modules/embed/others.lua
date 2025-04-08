-------------------------------------------------
------------------- EMBED FIX -------------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local timer = require('timer')

local Fixes,FixesRef = {},{}

--------------
-- INTERVAL --
--------------

local tbl1,tbl2,currentTime
timer.setInterval(1*3600*1000,function()
	tbl1,tbl2 = {},{}
	currentTime = os.time()

	for id,info in pairs(Fixes) do if currentTime > info.time then tbl1[info.fix.id],tbl2[id] = true,true end end
	for id in pairs(tbl1) do FixesRef[id] = nil end tbl1 = {}
	for id in pairs(tbl2) do Fixes[id] = nil end tbl2 = {}
end)

---------------
-- FUNCTIONS --
---------------

local function ExtractLinks(message)
	local links = {}
	for url in string.gmatch(message,"https?://[%w-_%.%?%.:/%+=&@]+") do links[#links+1] = url end
	return links
end

local function FixLink(message,link)
	message:hideEmbeds()
	local fix = message.channel:send{ content = link, reference = { message = message, mention = false }}
	if not fix then message:showEmbeds() return end
	Fixes[message.id] = { fix = fix, message = message, time = os.time() + (6*3600) }
	FixesRef[fix.id] = message.id
end

local Fix = {
	Instagram = function(message,link)
		if not (string.match(link,"://instagram%.com/") or string.match(link,"%.instagram%.com/")) then return 0 end
		if not string.match(link,"/reel/") and not string.match(link,"/p/") then return 1 end

		if link:match("?") then link = link:match("(.*?)"):gsub("?","") end
		link = link:gsub("instagram","ddinstagram") -- Alternatives: xnstagram.com

		FixLink(message,link) return 1
	end,

	TikTok = function(message,link)
		if not (string.match(link,"://tiktok%.com/") or string.match(link,"%.tiktok%.com/")) then return 0 end
		if not string.match(link,"/video/") and not string.match(link,"vm%.tiktok") then return 1 end

		if link:match("?") then link = link:match("(.*?)"):gsub("?","") end
		link = link:gsub("tiktok.com","tfxktok.com") -- Alternatives: vxtiktok.com, tiktxk.com

		FixLink(message,link) return 1
	end,

	Reddit = function(message,link)
		if not (string.match(link,"://reddit%.com/") or string.match(link,"%.reddit%.com/")) then return 0 end
		if not string.match(link,"/comments/") and not string.match(link,"/s/") then return 1 end

		if link:match("?") then link = link:match("(.*?)"):gsub("?","") end
		link = link:gsub("reddit.com","rxddit.com") -- Alternatives: rxyddit.com

		FixLink(message,link) return 1
	end,

	MinecraftWiki = function(message,link)
		if not (string.match(link,"://minecraft%.fandom%.com/")) then return 0 end
		if not string.match(link,"/wiki/") then return 1 end

		if link:match("?") then link = link:match("(.*?)"):gsub("?","") end
		link = link:gsub("/wiki/","/"):gsub("minecraft.fandom.com","minecraft.wiki")

		FixLink(message,link) return 1
	end
}

-------------------------------------------------
--------------------- EVENTS --------------------
-------------------------------------------------

local function Embed(message,client) -- messageCreate event
	if not message.guild then return end
	if message.author.bot then return end

	if message.content:match("<http") or message.content:match("||") then return end

	local links = ExtractLinks(message.content)
	if #links == 0 then return end

	for _,link in pairs(links) do
		for _,Check in pairs(Fix) do
			if Check(message,link) == 1 then return end
		end
	end
end

local function UserMessageDeleted(message,client) -- messageDelete event
	if not message.guild then return end
	if message.author.bot then return end

	if not Fixes[message.id] then return end

	Fixes[message.id]._deleted = true

	Fixes[message.id].fix.delete(Fixes[message.id].fix)
	FixesRef[Fixes[message.id].fix.id] = nil

	Fixes[message.id] = nil
end

local function BotMessageDeleted(message,client) -- messageDelete event
	if not message.guild then return end

	if not message.author.bot then return end
	if message.author.id ~= client.user.id then return end

	if not FixesRef[message.id] then return end
	if not Fixes[FixesRef[message.id]] then return end
	if Fixes[FixesRef[message.id]]._deleted then return end

	local id = FixesRef[message.id]

	FixesRef[message.id] = nil

	Fixes[id].message:showEmbeds()
	Fixes[id] = nil
end

local function DeleteUsingReaction(reaction,userId,client) -- reactionAdd event
	if not reaction.message.guild then return end

	if reaction.emojiName ~= "❌" then return end

	local id
	
	if Fixes[reaction.message.id] and
	(userId == reaction.message.author.id or userId == Config.OwnerID)
	then id = reaction.message.id

	elseif FixesRef[reaction.message.id] and
	(userId == Fixes[FixesRef[reaction.message.id]].message.author.id or userId == Config.OwnerID)
	then id = FixesRef[reaction.message.id] end

	if not id then return end

	Fixes[id]._deleted = true

	Fixes[id].fix.delete(Fixes[id].fix)
	FixesRef[Fixes[id].fix.id] = nil

	if reaction.message.id == Fixes[id].message.id then reaction:delete(userId) end

	Fixes[id].message:showEmbeds()
	Fixes[id] = nil
end

-----------------------
---- MODULE CONFIG ----
-----------------------

local functions = {
	messageCreate = {Embed},
	messageDelete = {UserMessageDeleted,BotMessageDeleted},
	reactionAdd = {DeleteUsingReaction},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
