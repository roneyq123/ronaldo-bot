-------------------------------------------------
---------------- EMBED - BLUESKY ----------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local http = require("coro-http")
local timer = require("timer")

local Cache = { Posts = {}, Profiles = {} }
local Fixes,FixesRef = {},{}

--------------
-- INTERVAL --
--------------

local tbl1,tbl2,currentTime
timer.setInterval(0.2*3600*1000,function() -- Clear expired cache and fixes from the table
	tbl1,tbl2 = {},{}
	currentTime = os.time()

	-- Caches
	for id,info in pairs(Cache.Posts) do if currentTime > info.time then tbl1[id] = true end end
	for id in pairs(tbl1) do Cache.Posts[id] = nil end tbl1 = {}
	for id,info in pairs(Cache.Profiles) do if currentTime > info.time then tbl1[id] = true end end
	for id in pairs(tbl1) do Cache.Profiles[id] = nil end tbl1 = {}

	-- Fixes
	for id,info in pairs(Fixes) do if currentTime > info.time then tbl2[id] = true for _,fix in pairs(info.fix) do tbl1[fix.id] = true end end end
	for id in pairs(tbl1) do FixesRef[id] = nil end tbl1 = {}
	for id in pairs(tbl2) do Fixes[id] = nil end tbl2 = {}
end)

---------------
-- FUNCTIONS --
---------------

local function SeparateSlashes(str)
	local tbl = {}
	for i in str:gmatch("([^/]+)") do table.insert(tbl,i) end
	return tbl
end

local function IsFromBluesky(url)
	return (string.match(url,"[./]bsky%.app/")) ~= nil
end

local function RequestInfo(url)
	local tbl
	if pcall(function() res,body = http.request("GET",url,{{"User-Agent",Config.UserAgent}}) end)
	then tbl = json.decode(body) end
	return tbl
end

local function ExtractLinks(message)
	local links = {}
	for url in string.gmatch(message,"https?://[%w-_%.%?%.:/%+=&]+") do links[#links+1] = url end
	return links
end

local function FormatNumberSimple(number)
	number = tonumber(number)
	if not number then return "N/A" end
	return tostring(number):reverse():gsub("%d%d%d","%1."):reverse():gsub("^%.","")
end

local function FormatNumber(number)
	number = tonumber(number)
	if not number then return "N/A" end
	if number >= 10^9 then return string.format("%.1fb",number/10^9) -- Billion (b)
	elseif number >= 10^6 then return string.format("%.1fm",number/10^6) -- Million (m)
	elseif number >= 10^3 then return string.format("%.1fk",number/10^3) -- Thousands (k)
	else return tostring(number) end
end

local function FormatMessage(message,limit)
	message = tostring(message)
	if not message then return "N/A" end
	if #message > (limit or 1500) then message = message:sub(1,(limit or 1500)).."(...)" end -- Maximum X or 1500 chars
	while message:match("\n\n\n") do message = message:gsub("\n\n\n","\n\n") end -- Parse all unnecessary escapes
	while message:sub(#message) == "\n" do message = message:sub(1,#message-1) end -- Remove all escapes at the end
	return message
end

local function DateToTimestamp(dateString)
    local year,month,day,hour,min = dateString:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d)")
    return os.time({year=(year or 1970),month=(month or 1),day=(day or 1),hour=(hour or 0),min=(min or 0)})
end

-- TABLES --

local function ReverseTable(tbl)
	for i=1,#tbl/2,1 do tbl[i],tbl[#tbl-i+1] = tbl[#tbl-i+1],tbl[i] end
	return tbl
end


local function CopyTable(originalTable)
	local copiedTable = {}
	for key,value in pairs(originalTable) do
		if type(value) ~= "table" then copiedTable[key] = value
		else copiedTable[key] = CopyTable(value) end
	end
	return copiedTable
end

local function JoinTables(firstTable,secondTable)
	local finishedTable = CopyTable(firstTable)
	for key,value in pairs(secondTable) do
		finishedTable[#finishedTable+1] = CopyTable(value)
	end
	return finishedTable
end

-------------------
-- FIXING EMBEDS --
-------------------

local function Profile(message,link)
	-- Getting the profile handle
	local tbl = SeparateSlashes(link)

	local handle = tbl[4] or nil
	if not handle then return end

	-- Get profile info using handle (check in cache first)
	local profile

	if not Cache.Profiles[handle] then
		profile = RequestInfo("https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor="..handle)

		if not profile and profile.error then
			Cache.Profiles[handle] = { error = true, time = os.time() }
			message:addReaction("⚠")
			return
		end
	
		Cache.Profiles[handle] = { profile = CopyTable(profile), time = os.time() + (1*3600) }
	else
		if Cache.Profiles[handle].error then return end

		profile = CopyTable(Cache.Profiles[handle])
	end

	-- Building the message and filling the embed
	local embed = {}

	embed.color = 34303 -- "#0085ff"
	embed.thumbnail = { url = profile.avatar }
	embed.author = { name = "@"..profile.handle.. " • Bluesky" }
	embed.title,embed.url = profile.displayName,"https://bsky.app/profile/"..profile.did
	embed.description =	"🗣️ **Seguidores**: "..FormatNumberSimple(profile.followersCount).."\n"..
						"👥 **Seguindo**: "..FormatNumberSimple(profile.followsCount).."\n"..
						"📝 **Posts**: "..FormatNumberSimple(profile.postsCount)
	if (profile.description or "") ~= "" then embed.description = FormatMessage(profile.description,200).."\n\n"..embed.description end

	-- Hide original embed, send message and add message to tables to be manageable later
	message:hideEmbeds()

	local fix = message.channel:send{ embed = embed, reference = { message = message, mention = false } }
	if not fix then return end
	Fixes[message.id] = { fix = {fix}, message = message, time = os.time() + (6*3600) }
	FixesRef[fix.id] = message.id
end

local function Post(message,link)
	-- Getting the post ID and handle of the user
	local tbl = SeparateSlashes(link)

	local handle = tbl[4] or nil
	local id = tbl[6] or nil
	if not handle or not id then return end
	if id:match("?") then id = id:match("(.*?)"):gsub("?","") end

	-- Get post info using handle and ID (check in cache first)
	local post,parent

	if not Cache.Posts[handle.."_"..id] then
		post = RequestInfo("https://public.api.bsky.app/xrpc/app.bsky.feed.getPostThread?uri=at%3A%2F%2F"..handle.."%2Fapp.bsky.feed.post%2F"..id.."&depth=0")
	
		if not post and post.error then
			Cache.Posts[handle.."_"..id] = { error = true, time = os.time() }
			message:addReaction("⚠")
			return
		end

		Cache.Posts[handle.."_"..id] = { post = CopyTable(post.thread.post), time = os.time() + (2*3600) }
		Cache.Posts[post.thread.post.author.did.."_"..id] = Cache.Posts[handle.."_"..id]

		if post.thread.parent and post.thread.parent["$type"] == "app.bsky.feed.defs#threadViewPost" then
			Cache.Posts[handle.."_"..id].parent = CopyTable(post.thread.parent.post)
			Cache.Posts[post.thread.post.author.did.."_"..id].parent = Cache.Posts[handle.."_"..id].parent
			parent = post.thread.parent.post
		end
	
		post = post.thread.post
	else
		if Cache.Posts[handle.."_"..id].error then return end

		post = CopyTable(Cache.Posts[handle.."_"..id].post)
		if Cache.Posts[handle.."_"..id].parent then parent = CopyTable(Cache.Posts[handle.."_"..id].parent) end
	end

	-- Building the message
	local video,images,texts,embed = nil,{},{},{}
	local external_url = ""

	embed.post = {}
	embed.post[1] = {}
	embed.post[1].color = 34303 -- "#0085ff"
	embed.post[1].title,embed.post[1].url = post.author.displayName,"https://bsky.app/profile/"..post.author.did.."/post/"..id
	embed.post[1].author = { icon_url = post.author.avatar, name = "@"..post.author.handle.." • Bluesky", url = "https://bsky.app/profile/"..post.author.did }
	embed.post[1].footer = { text = os.date("Postado em %d/%m/%y às %H:%M",(DateToTimestamp(post.record.createdAt)-10800)) }

	if post.record.text and post.record.text ~= "" then texts.post = FormatMessage(post.record.text).."\n\n" end

	-- FACETS MANAGER FUNCTION
	local Facets = function(manage,facets)
		for _,facet in pairs(facets) do
			-- URLs
			if facet.features[1]["$type"] == "app.bsky.richtext.facet#link" and external_url ~= facet.features[1].uri then
				local url = facet.features[1].uri:gsub("https?://",""):gsub("%/$","")
				if string.match(texts[manage],url) == nil then
					url = url:sub(0,20)..texts[manage]:match(url:sub(0,20):gsub("([%.%-])","%%%1").."(.*)%.%.%.").."..."
				end
				texts[manage] = texts[manage]:gsub(url,"["..url.."]("..facet.features[1].uri..")")
			end
			-- Hashtags
			if facet.features[1]["$type"] == "app.bsky.richtext.facet#tag" then
				texts[manage] = texts[manage]:gsub("#"..facet.features[1].tag.."([^%a%d]?)","[#"..facet.features[1].tag.."](https://bsky.app/hashtag/"..facet.features[1].tag..")%1",1)
			end
			-- User mentions
			if facet.features[1]["$type"] == "app.bsky.richtext.facet#mention" then
				local handle = (" "..texts[manage]):match("[^%[]@([%w%.-]+)")
				texts[manage] = texts[manage]:gsub("@"..handle:gsub("([%.%-])","%%%1"),"[@"..handle.."](https://bsky.app/profile/"..facet.features[1].did..")")
			end
		end
	end

	if post.embed then

		------------------
		---- IMAGE(S) ----
		------------------

		if post.embed["$type"] == "app.bsky.embed.images#view" or 
			(post.embed["$type"] == "app.bsky.embed.recordWithMedia#view" and 
			post.embed.media["$type"] == "app.bsky.embed.images#view") then

			if post.embed["$type"] == "app.bsky.embed.recordWithMedia#view" then
				post.embed.images = post.embed.media.images
			end

			images.post = {}
			for _,image in pairs(post.embed.images) do
				images.post[#images.post+1] = image.fullsize
			end
		end

		---------------
		---- VIDEO ----
		---------------

		if post.embed["$type"] == "app.bsky.embed.video#view" or 
			(post.embed["$type"] == "app.bsky.embed.recordWithMedia#view" and 
			post.embed.media["$type"] == "app.bsky.embed.video#view") then

			video = {"post",post.author.did,id}
		end

		------------------
		---- EXTERNAL ----
		------------------
		if (post.embed["$type"] == "app.bsky.embed.external#view" or 
			(post.embed["$type"] == "app.bsky.embed.recordWithMedia#view" and 
			post.embed.media["$type"] == "app.bsky.embed.external#view")) then

			if post.embed["$type"] == "app.bsky.embed.recordWithMedia#view" then
				post.embed.external = post.embed.media.external
			end

			if post.embed.external.uri:sub(1,24) == "https://media.tenor.com/" then
				embed.post[1].image = { url = post.embed.external.uri }
			else
				if post.embed.external.thumb then
					embed.post[1].image = { url = post.embed.external.thumb }
				end
				local title = post.embed.external.title
				if title ~= "" then
					title = title:match("(.-)% %-% (.-)") or title
					title = title:match("(.-)% %|% (.-)") or title
					title = title:lower():gsub("[%[%]%(%)%.%+%-%*%?%^%$]","%%%1")
				end

				if title ~= "" and texts.post:lower():match(title:lower()) == nil then
					texts.post = texts.post.."["..post.embed.external.title.."]("..post.embed.external.uri..")\n\n"
				else
					local textUrl = false
					for _,facet in pairs(post.record.facets or {}) do
						if facet.features[1]["$type"] == "app.bsky.richtext.facet#link"
						and facet.features[1].uri == post.embed.external.uri then
							textUrl = true
							break
						end
					end

					local url = post.embed.external.uri:gsub("https?://",""):gsub("%/$","")
					if textUrl then
						if string.match(texts.post,url) == nil then
							url = url:sub(0,20)..texts.post:match(url:sub(0,20):gsub("([%.%-])","%%%1").."(.*)%.%.%.").."..."
						end
						texts.post = texts.post:gsub(url,"["..url.."]("..post.embed.external.uri..")")
					else
						texts.post = texts.post.."["..url.."]("..post.embed.external.uri..")\n\n"
					end
				end
				external_url = post.embed.external.uri
			end
		end

		---------------------
		---- QUOTED POST ----
		---------------------
		if not parent and (post.embed["$type"] == "app.bsky.embed.record#view" or 
			(post.embed["$type"] == "app.bsky.embed.recordWithMedia#view" and 
			post.embed.record and post.embed.record.record and
			post.embed.record.record["$type"] == "app.bsky.embed.record#viewRecord")) then

			if post.embed["$type"] == "app.bsky.embed.recordWithMedia#view" then
				post.embed.record = post.embed.record.record
			end

			embed.mention = {[1]={}}
			embed.mention[1].color = 34303 -- "#0085ff"

			tbl = SeparateSlashes(post.embed.record.uri)
			local quote_id = tbl[#tbl]

			if post.embed.record["$type"] == "app.bsky.embed.record#viewRecord" then
				embed.mention[1].author = { name = "Menção a post:" }
				embed.mention[1].title,embed.mention[1].url = post.embed.record.author.displayName.." - @"..post.embed.record.author.handle,"https://bsky.app/profile/"..post.embed.record.author.did.."/post/"..quote_id
				if post.embed.record.value.text and post.embed.record.value.text ~= "" then texts.mention = FormatMessage(post.embed.record.value.text) end

				if post.embed.record.embeds and post.embed.record.embeds[1] then
					-- Check if has images
					if post.embed.record.embeds[1]["$type"] == "app.bsky.embed.images#view" then
						images.mention = {}
						for _,image in ipairs(post.embed.record.embeds[1].images) do
							images.mention[#images.mention+1] = image.fullsize
						end
						images.mention = ReverseTable(images.mention) -- Reversing table order because Discord shows images in reverse order, idk why
					end

					-- Check if has video
					if not video
					and post.embed.record.embeds[1]["$type"] == "app.bsky.embed.video#view" then
						video = {"mention",post.embed.record.author.did,quote_id}
					end

					-- Check if has external URL
					if post.embed.record.embeds[1]["$type"] == "app.bsky.embed.external#view" then
						if post.embed.record.embeds[1].external.uri:sub(1,24) == "https://media.tenor.com/" then
							embed.mention[1].image = { url = post.embed.record.embeds[1].external.uri }
						elseif post.embed.record.embeds[1].external.thumb then
							embed.mention[1].image = { url = post.embed.record.embeds[1].external.thumb }
						end
					end
				end

				if post.embed.record.value.facets then Facets("mention",post.embed.record.value.facets) end
			elseif post.embed.record["$type"] == "app.bsky.embed.record#viewDetached" then
				embed.mention[1].title,embed.mention[1].url = "🛈 Menção a um post removido pelo autor","https://bsky.app/profile/"..post.embed.record.author.did.."/post/"..quote_id
			elseif post.embed.record["$type"] == "app.bsky.embed.record#viewBlocked" then
				embed.mention[1].title,embed.mention[1].url = "🛈 Menção a um post bloqueado pelo autor","https://bsky.app/profile/"..post.embed.record.author.did.."/post/"..quote_id
			end
		end

	end

	-- PARENT
	if parent then
		embed.mention = {[1]={}}
		embed.mention[1].color = 34303 -- "#0085ff"

		tbl = SeparateSlashes(parent.uri)
		local quote_id = tbl[#tbl]

		embed.mention[1].author = { name = "Resposta a post:" }
		embed.mention[1].title,embed.mention[1].url = parent.author.displayName.." - @"..parent.author.handle,"https://bsky.app/profile/"..parent.author.did.."/post/"..quote_id
		
		if parent.record.text and parent.record.text ~= "" then texts.mention = FormatMessage(parent.record.text) end

		if parent.embed then
			-- Check if has images
			if parent.embed["$type"] == "app.bsky.embed.images#view" or 
				(parent.embed["$type"] == "app.bsky.embed.recordWithMedia#view" and 
				parent.embed.media["$type"] == "app.bsky.embed.images#view") then

				if parent.embed["$type"] == "app.bsky.embed.recordWithMedia#view" then
					parent.embed.images = parent.embed.media.images
				end

				images.mention = {}
				for _, image in ipairs(parent.embed.images) do
					images.mention[#images.mention+1] = image.fullsize
				end
				images.mention = ReverseTable(images.mention) -- Reversing table order because Discord shows images in reverse order, idk why
			end

			-- Check if has video
			if not video and
				(parent.embed["$type"] == "app.bsky.embed.video#view" or 
				(parent.embed["$type"] == "app.bsky.embed.recordWithMedia#view" and 
				parent.embed.media["$type"] == "app.bsky.embed.video#view")) then

				video = {"mention",parent.author.did,quote_id}
			end

			-- Check if has external URL
			if (parent.embed["$type"] == "app.bsky.embed.external#view" or 
			(parent.embed["$type"] == "app.bsky.embed.recordWithMedia#view" and 
			parent.embed.media["$type"] == "app.bsky.embed.external#view")) then

				if parent.embed["$type"] == "app.bsky.embed.recordWithMedia#view" then
					parent.embed.external = parent.embed.media.external
				end

				if parent.embed.external.uri:sub(1,24) == "https://media.tenor.com/" then
					embed.mention[1].image = { url = parent.embed.external.uri }
				elseif parent.embed.external.thumb then
					embed.mention[1].image = { url = parent.embed.external.thumb }
				end
			end
		end

		if parent.record.facets then Facets("mention",parent.record.facets) end
	end

	if post.record.facets then Facets("post",post.record.facets) end

	embed.post[1].description =	(texts.post or "")..
		"<:comments:1306441248474664991>⠀"..FormatNumber(post.replyCount).."⠀⠀⠀⠀".. -- 💬
		"<:repost:1306441284319449158>⠀"..FormatNumber(post.repostCount).." + "..FormatNumber(post.quoteCount).."⠀⠀⠀⠀".. -- 🔄
		"<:like:1306441277293989918>⠀"..FormatNumber(post.likeCount) -- ❤️

	if texts.mention then embed.mention[1].description = FormatMessage(texts.mention) end

	if next(images) ~= nil then
		for tbl in pairs(images) do
			local counter = 1
			for _,image in ipairs(images[tbl]) do
				if counter > 1 then embed[tbl][counter] = CopyTable(embed[tbl][counter-1]) end
				embed[tbl][counter].image = { url = image }
				counter = counter + 1
			end
		end
	end

	-- Prepare the messages to be sent

	local messagesToSend = {[1]={ reference = { message = message, mention = false } }}

	if not embed.mention then
		messagesToSend[1].embeds = embed.post

		if video and video[1] == "post" then
			messagesToSend[2] = { content = "[`Download do vídeo`](https://downloader.xsky.app/profile/"..video[2].."/post/"..video[3].."?download)" }
		end
	else
		if not video then
			messagesToSend[1].embeds = JoinTables(embed.post,embed.mention)
		else
			if video[1] == "post" then
				messagesToSend[1].embeds = embed.post
				messagesToSend[2] = { content = "[`Download do vídeo`](https://downloader.xsky.app/profile/"..video[2].."/post/"..video[3].."?download)" }
				messagesToSend[3] = { embeds = embed.mention }
			elseif video[1] == "mention" then
				messagesToSend[1].embeds = JoinTables(embed.post,embed.mention)
				messagesToSend[2] = { content = "[`Download do vídeo`](https://downloader.xsky.app/profile/"..video[2].."/post/"..video[3].."?download)" }
			end
		end
	end

	-- Hide original embed, send message(s) and add message(s) to tables to be manageable later
	message:hideEmbeds()

	Fixes[message.id] = { fix = {}, message = message, time = os.time() + (6*3600) }

	for i,details in ipairs(messagesToSend) do
		sent = message.channel:send{ embeds = details.embeds or nil, content = details.content or nil, reference = details.reference or nil }
		if not sent then return end
		Fixes[message.id].fix[i] = sent
		FixesRef[sent.id] = message.id
	end
end

-------------------------------------------------
--------------------- EVENTS --------------------
-------------------------------------------------

local function Embed(message,client) -- messageCreate event
	if not message.guild then return end
	if message.author.bot then return end

	if message.content:match("<http") or message.content:match("||") then return end

	local links = ExtractLinks(message.content)
	for _,link in pairs(links) do
		if IsFromBluesky(link) and string.match(link,"/profile/") then
			if string.match(link,"/post/") then
				Post(message,link)
			else
				Profile(message,link)
			end
			return
		end
	end
end

local function UserMessageDeleted(message,client) -- messageDelete event
	if not message.guild then return end
	if message.author.bot then return end

	if not Fixes[message.id] then return end

	Fixes[message.id]._deleted = true

	for i,fix in pairs(Fixes[message.id].fix) do
		if not fix._deleted then
			fix.delete(fix)
			FixesRef[fix.id] = nil
		end
	end

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

	for i,fix in pairs(Fixes[id].fix) do
		if fix.id == message.id then
			Fixes[id].fix[i]._deleted = true
			break
		end
	end
	
	for i,fix in pairs(Fixes[id].fix) do
		if not fix._deleted then return end
	end

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

	for i,fix in pairs(Fixes[id].fix) do
		if not fix._deleted then
			fix.delete(fix)
			FixesRef[fix.id] = nil
		end
	end

	if reaction.message.id == Fixes[id].message.id then reaction:delete(userId) end

	Fixes[id].message:showEmbeds()
	Fixes[id] = nil
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	messageCreate = {Embed},
	messageDelete = {UserMessageDeleted,BotMessageDeleted},
	reactionAdd = {DeleteUsingReaction},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
