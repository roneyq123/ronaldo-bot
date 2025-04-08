-------------------------------------------------
-------------- DOWNLOAD - TWITTER ---------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local http = require("coro-http")
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

local function Twitter(message,link)
	-- Check if its a tweet
	if not string.match(link,"/status/") then return end

	-- Getting the tweet ID
	local tbl = {}
	for i in link:gmatch("([^/]+)") do table.insert(tbl,i) end
	local id = tbl[5]
	if id:match("?") then id = id:match("(.*?)"):gsub("?","") end

	-- Get tweet info using ID
	local tweet

	if pcall(
		function()
			res,body = http.request(
				"GET",
				"https://api.fxtwitter.com/i/status/"..id,
				{{"User-Agent",Config.UserAgent}}
			)
		end
	) then 
		tweet = json.decode(body)
	end

	if not tweet then return end
	if tweet.code ~= 200 then return end

	tweet = tweet.tweet

	-- Get media of the tweet
	local media = {}
	local counter = { images = 0, videos = 0, gifs = 0 }

	if tweet.media then
		for _,m in pairs(tweet.media.all) do
			if m.type == "photo" then
				counter.images = counter.images + 1
				media[#media+1] = {text="Imagem "..counter.images,url=m.url}
			elseif m.type == "gif" then
				counter.gifs = counter.gifs + 1
				media[#media+1] = {text="GIF "..counter.gifs,url=m.url}
			elseif m.type == "video" then
				counter.videos = counter.videos + 1
				media[#media+1] = {text="Vídeo "..counter.videos}
				if m.url:match("?") then media[#media].url = m.url:match("(.*?)"):gsub("?","") 
				else media[#media].url = m.url end
			end
		end
	end

	-- Send warning message if no media was found
	if #media == 0 then
		local response = message.channel:send{content="Não foi encontrado nenhuma mídia nesse tweet <:thonk:356796622023294977>",reference={message=message,mention=false}}
		timer.sleep(10000)
		response.delete(response)
		return
	end

	-- If media was found, send it using a nice embed or only the media if it's only one
	local response

	if #media > 1 then
		local embed = {
			author = { name = "Mídia - Twitter" },
			title = "Aqui estão os links da mídia do tweet de @"..tweet.author.screen_name.." <:blobowo:357651849379315712>",
			description = "",
			color = 1942002, -- "#1da1f2"
			footer = { text = "Reaja com ❌ caso deseja deletar esta mensagem" }
		}

		for _,row in pairs(media) do
			embed.description = embed.description.."[`"..row.text.."`](<"..row.url..">)\n"
		end

		response = message.channel:send{ embed = embed, content = "**TwitterDL**", reference = { message = message, mention = false } }
	else
		response = message.channel:send{ content = "**TwitterDL**\n"..media[1].url, reference = { message = message, mention = false } }
	end

	response:addReaction("❌")
end

-------------------------------------------------
--------------------- EVENTS --------------------
-------------------------------------------------

local function Download(message,client) -- messageCreate event
	if message.guild then return end
	if message.author.bot then return end

	if not Cooldown(message.author.id,5) then return end

	link = message.content
	if not link then return end
	if link:sub(1,4) ~= "http" then return end

	if string.match(link,"://twitter%.com/")
	or string.match(link,"%.twitter%.com/")
	or string.match(link,"://x%.com/")
	or string.match(link,"%.x%.com/")
	then Twitter(message,link) end
end

local function DeleteViaReaction(reaction,userId,client) -- reactionAdd event
	if reaction.message.guild then return end

	if reaction.emojiName ~= "❌" then return end

	if userId == client.user.id then return end
	if userId == reaction.message.author.id then return end

	if reaction.message.content:sub(1,13) ~= "**TwitterDL**" then return end

	reaction.message.delete(reaction.message)
end

local function DeleteViaReactionUncached(channel,messageId,hash,userId,client) -- reactionAddUncached event
	if channel.parent:__tostring() ~= "Client" then return end

	if hash ~= "❌" then return end

	if userId == client.user.id then return end

	local message = channel:getMessage(messageId)

	if userId == message.author.id then return end

	if message.content:sub(1,13) ~= "**TwitterDL**" then return end

	message.delete(message)
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	messageCreate = {Download},
	reactionAdd = {DeleteViaReaction},
	reactionAddUncached = {DeleteViaReactionUncached},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
