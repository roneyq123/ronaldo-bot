-------------------------------------------------
---------------- EMBED - TWITTER ----------------
-------------------------------------------------

local json,fs = require("json"),require("fs")
local Config = json.decode(fs.readFileSync("./config.json"))

local http = require("coro-http")
local timer = require("timer")

local Cache = { Tweets = {}, Profiles = {} }
local Fixes,FixesRef = {},{}

local reactionNeeded,reactionUrl = true,{}

local emojis = {reaction="1306441268079104061",comments="1306441248474664991",repost="1306441284319449158",like="1306441277293989918"}
local TimeTranslate = {[" day left"]=" dia restante",[" days left"]=" dias restantes",[" hour left"]=" hora restante",[" hours left"]=" horas restantes",[" minute left"]=" minuto restante",[" minutes left"]=" minutos restantes",[" second left"]=" segundo restante",[" seconds left"]="segundos restantes"}
local LangCodes = {"af","ak","am","ar","as","az","be","bg","bn","br","bs","ca","cs","cy","da","de","el","en","eo","es","et","eu","fa","fi","fj","fo","fr","ga","gd","gl","gn","gu","ha","he","hi","hr","ht","hu","hy","ia","id","ie","ig","ik","is","it","iu","ja","jv","ka","kg","ki","kk","kl","km","kn","ko","ks","ku","ky","la","lb","lg","ln","lo","lt","lu","lv","mg","mk","ml","mn","mr","ms","mt","my","na","nb","nd","ne","nl","nn","no","nr","nv","ny","oc","om","or","os","pa","pl","ps","pt","qu","rm","rn","ro","ru","rw","sa","sc","sd","se","sg","si","sk","sl","sm","sn","so","sq","sr","ss","st","su","sv","sw","ta","te","tg","th","ti","tk","tl","tn","to","tr","ts","tt","ug","uk","ur","uz","ve","vi","vo","wa","wo","xh","yi","yo","za","zu"}
local AltLangCodes = {["zh"]="zh-cn",["cn"]="zh-cn",["tw"]="zh-tw",["jp"]="ja",["kr"]="ko",["ua"]="uk",["gr"]="el"}

--------------
-- INTERVAL --
--------------

local tbl1,tbl2,currentTime
timer.setInterval(0.2*3600*1000,function() -- Clear expired cache and fixes from the table
	tbl1,tbl2 = {},{}
	currentTime = os.time()

	-- Caches
	for id,info in pairs(Cache.Tweets) do if currentTime > info.time then tbl1[id] = true end end
	for id in pairs(tbl1) do Cache.Tweets[id] = nil end tbl1 = {}
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

local function IsFromTwitter(url)
	return (string.match(url,"[./]twitter%.com/") or string.match(url,"[./]x%.com/")) ~= nil
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

-------------------
-- FIXING EMBEDS --
-------------------

local function Profile(message,link)
	-- Getting the profile handle
	local tbl = {}
	for i in link:gmatch("([^/]+)") do table.insert(tbl,i) end

	local handle = tbl[3] or nil
	if not handle then return end

	-- Get profile info using handle (check in cache first)
	local profile

	if not Cache.Profiles[handle] then
		profile = RequestInfo("https://api.fxtwitter.com/"..handle)

		if not profile then return end
		if not profile.code then return end

		if (profile.code or 0) ~= 200 then
			Cache.Profiles[handle] = { error = true, time = os.time() }
			message:addReaction("⚠")
			return
		end
	
		profile = profile.user
		Cache.Profiles[handle] = { profile = profile, time = os.time() + (1*3600) }
	else
		if Cache.Profiles[handle].error then return end

		profile = Cache.Profiles[handle].profile
	end

	-- Building the message and filling the embed
	local embed = {}

	embed.color = 1942002 -- "#1da1f2"

	embed.title,embed.url = profile.name,profile.url

	embed.description =	"🗣️ **Seguidores**: "..FormatNumberSimple(profile.followers).."\n"..
						"👥 **Seguindo**: "..FormatNumberSimple(profile.following).."\n"..
						"❤️ **Curtidas**: "..FormatNumberSimple(profile.likes).."\n"..
						"📝 **Tweets**: "..FormatNumberSimple(profile.tweets)
	if profile.website then embed.description = embed.description.."\n🌐 **Website**: ["..profile.website.display_url.."]("..profile.website.url..")" end
	if (profile.location or "") ~= "" then embed.description = embed.description.."\n📍 **Local**: "..profile.location end
	if (profile.description or "") ~= "" then embed.description = FormatMessage(profile.description,200).."\n\n"..embed.description end

	embed.author = { name = "@"..profile.screen_name.. " • Twitter" }

	embed.thumbnail = { url = profile.avatar_url:gsub("_normal","") }

	-- Hide original embed, send message and add message to tables to be manageable later
	message:hideEmbeds()

	local fix = message.channel:send{ embed = embed, reference = { message = message, mention = false } }
	if not fix then message:showEmbeds() return end
	Fixes[message.id] = { fix = {fix}, message = message, time = os.time() + (6*3600) }
	FixesRef[fix.id] = message.id
end

local function Tweet(message,link)
	-- Getting the tweet ID and language to translate (if specified)
	local tbl = {}
	for i in link:gmatch("([^/]+)") do table.insert(tbl,i) end

	local id = tbl[5] or nil
	if not id then return end
	if id:match("?") then id = id:match("(.*?)"):gsub("?","") end

	local lang = ""
	if tbl[6] and tbl[6]:len() == 2 then
		tbl[6] = tbl[6]:lower()
		if not AltLangCodes[tbl[6]] then
			for _,code in pairs(LangCodes) do
				if tbl[6] == code then lang = code break end
			end
		else lang = AltLangCodes[tbl[6]] end
	end

	-- Get tweet info using ID (check in cache first)
	local tweet,translation

	if not Cache.Tweets[id] then
		tweet = RequestInfo("https://api.fxtwitter.com/i/status/"..id..(lang ~= "" and "/"..lang or ""))
	
		if not tweet then return end
		if not tweet.code then return end

		if (tweet.code or 0) ~= 200 then
			Cache.Tweets[id] = { error = true, time = os.time() }
			message:addReaction("⚠")
			return
		end

		tweet = tweet.tweet

		if tweet.poll and tweet.poll.time_left_en ~= "Final results" then -- If it has an active poll, cache expiration is faster
			Cache.Tweets[id] = { time = os.time() + (0.2*3600) }
		else
			Cache.Tweets[id] = { time = os.time() + (2*3600) }
		end

		if tweet.translation then
			Cache.Tweets[id].translation = {}
			Cache.Tweets[id].translation[lang] = tweet.translation
			translation = tweet.translation
			tweet.translation = nil
		end

		Cache.Tweets[id].tweet = tweet
	else
		if Cache.Tweets[id].error then return end

		if lang ~= "" and not (Cache.Tweets[id].translation and Cache.Tweets[id].translation[lang]) then
			tweet = RequestInfo("https://api.fxtwitter.com/i/status/"..id..(lang ~= "" and "/"..lang or ""))
	
			if not tweet then return end
			if not tweet.code then return end
	
			if (tweet.code or 0) ~= 200 then
				Cache.Tweets[id] = { error = true, time = os.time() }
				message:addReaction("⚠")
				return
			end

			tweet = tweet.tweet

			if tweet.poll and tweet.poll.time_left_en ~= "Final results" then -- If it has an active poll, cache expiration is faster
				Cache.Tweets[id].time = os.time() + (0.2*3600)
			else
				Cache.Tweets[id].time = os.time() + (2*3600)
			end
			
			if not Cache.Tweets[id].translation then Cache.Tweets[id].translation = {} end
			Cache.Tweets[id].translation[lang] = tweet.translation
			translation = tweet.translation
			tweet.translation = nil

			Cache.Tweets[id].tweet = tweet
		else
			tweet = Cache.Tweets[id].tweet
			if lang ~= "" then
				translation = Cache.Tweets[id].translation[lang]
			end
		end
	end

	-- Building the message and filling the primary embed
	local media,mediaPrimary
	local embed = {{}}

	embed[1].color = 1942002 -- "#1da1f2"

	embed[1].title,embed[1].url = tweet.author.name,tweet.url

	embed[1].description =	"<:comments:"..emojis.comments..">⠀"..FormatNumber(tweet.replies).."⠀⠀⠀⠀".. -- 💬
							"<:repost:"..emojis.repost..">⠀"..FormatNumber(tweet.retweets).."⠀⠀⠀⠀".. -- 🔄
							"<:like:"..emojis.like..">⠀"..FormatNumber(tweet.likes) -- ❤️

	if tweet.poll then
		local poll = ""

		for i,choice in pairs(tweet.poll.choices) do
			poll = poll..choice.label.."\n"..string.rep("█",math.floor((choice.percentage/100)*32)).."⠀⠀"..choice.percentage.."% ("..FormatNumberSimple(choice.count)..")\n\n"
		end

		local time_left = tweet.poll.time_left_en:match("%d+")
		poll = poll..FormatNumberSimple(tweet.poll.total_votes).." votos • "..((time_left ~= nil and time_left..TimeTranslate[tweet.poll.time_left_en:gsub(tostring(time_left),"")]) or "Resultados finais")

		embed[1].description = poll.."\n\n"..embed[1].description
	end
	
	if tweet.text then embed[1].description = FormatMessage((translation and translation.text) or tweet.text).."\n\n"..embed[1].description end
	if tweet.community_note then embed[1].description = embed[1].description.."\n\n 👥 **Este tweet tem uma nota da comunidade** 👥 \n```plaintext\n"..tweet.community_note.text.."```" end

	embed[1].author = { icon_url = tweet.author.avatar_url, name = "@"..tweet.author.screen_name.." • Twitter", url = tweet.author.url }

	embed[1].footer = { text = 
		((tweet.views and FormatNumber(tweet.views).." visualiz. • ") or "")..
		((tweet.source and tweet.source.." • ") or "")..
		os.date("%d/%m/%y às %H:%M",tweet.created_timestamp)
	}
	if tweet.replying_to and tweet.replying_to_status then embed[1].footer.text = "Resposta a tweet de @"..tweet.replying_to.."\n"..embed[1].footer.text end
	if translation then embed[1].footer.text = "Traduzido de "..translation.source_lang:upper().." para "..translation.target_lang:upper().."\n"..embed[1].footer.text end

	-- Manage media of the tweet
	local images,video,gif = "","",""

	if tweet.media and tweet.media.all then
		for _,tweetMedia in pairs(tweet.media.all) do
			if tweetMedia.type == "photo" then images = images..tweetMedia.url..","
			elseif tweetMedia.type == "gif" and gif == "" then gif = tweetMedia.url
			elseif tweetMedia.type == "video" and video == "" then video = tweetMedia.url
				video = video:gsub("video%.twimg%.com","vxtwitter.com/tvid"):gsub("%.mp4","") -- fx video embed currently broken on Discord, using the vxtwitter proxy temporarily
				if video:match("?") then video = video:match("(.*?)"):gsub("?","") end
			end
		end

		if images ~= "" then
			local _,commas = images:gsub(",","")
			if commas == 1 then
				embed[1].image = { url = images:sub(1,-2) }
			else
				embed[1].image = { url = "https://convert.vxtwitter.com/rendercombined.jpg?imgs="..images:sub(1,-2) }
			end
		end
		if video ~= "" then mediaPrimary,media = true,"[`Download do vídeo`]("..video..")"
		elseif gif ~= "" then mediaPrimary,media = true,"[`Download do GIF`]("..gif..")" end
	end

	-- Check if has quoted a tweet
	if tweet.quote then
		-- Building and filling the secondary embed
		embed[2] = { color = 1942002 } -- "#1da1f2"

		embed[2].title,embed[2].url = "Menção ao tweet de "..tweet.quote.author.name.." - @"..tweet.quote.author.screen_name,tweet.quote.url

		--[[
		embed[2].description =	"<:comments:"..emojis.comments..">⠀"..FormatNumber(tweet.quote.replies).."⠀⠀⠀⠀".. -- 💬
								"<:repost:"..emojis.repost..">⠀"..FormatNumber(tweet.quote.retweets).."⠀⠀⠀⠀".. -- 🔄
								"<:like:"..emojis.like..">⠀"..FormatNumber(tweet.quote.likes) -- ❤️
		]]
		embed[2].description = ""

		if tweet.quote.text then embed[2].description = FormatMessage(tweet.quote.text,500).."\n\n"..embed[2].description end

		-- Manage media of the quoted tweet if applicable
		if tweet.quote.media and tweet.quote.media.all then
			images = ""
			for _,tweetMedia in pairs(tweet.quote.media.all) do
				if tweetMedia.type == "photo" then images = images..tweetMedia.url..","
				elseif tweetMedia.type == "gif" and gif == "" then gif = tweetMedia.url
				elseif tweetMedia.type == "video" and video == "" then video = tweetMedia.url
					video = video:gsub("video%.twimg%.com","vxtwitter.com/tvid"):gsub("%.mp4","") -- fx video embed currently broken on Discord, using the vxtwitter proxy temporarily
					if video:match("?") then video = video:match("(.*?)"):gsub("?","") end
				end
			end

			if images ~= "" then
				local _,commas = images:gsub(",","")
				if commas == 1 then
					embed[2].image = { url = images:sub(1,-2) }
				else
					embed[2].image = { url = "https://convert.vxtwitter.com/rendercombined.jpg?imgs="..images:sub(1,-2) }
				end
			end

			if not media then
				if video ~= "" then media = "[`Download do vídeo`]("..video..")"
				elseif gif ~= "" then media = "[`Download do GIF`]("..gif..")" end
			end
		end
	end

	-- If primary embed doesn't have any media but text has a link, get image from websites metadata
	if not media and not embed[1].image and (tweet.text and tweet.text:match("https?://")) then
		if Cache.Tweets[id] and Cache.Tweets[id].imageURL then
			if Cache.Tweets[id].imageURL ~= "0" then
				embed[1].image = { url = Cache.Tweets[id].imageURL }
			end
		else
			Cache.Tweets[id].imageURL = "0"

			local url = ExtractLinks(tweet.text)
			if #url == 1 and not IsFromTwitter(url[1]) then
				url = url[1]
				if url:match("?") then url = url:match("(.*?)"):gsub("?","") end

				--[[local metadata = RequestInfo("https://apimeta.kiriha.ru/info?url="..url)

				if metadata and metadata.opengraph then
					for _,tag in pairs(metadata.opengraph) do
						if tag.property == "og:image" then
							embed[1].image = { url = tag.content }
							Cache.Tweets[id].imageURL = tag.content
							break
						end
					end
				end]]

				local metadata = RequestInfo("https://api.dub.co/metatags?url="..url)

				if metadata and metadata.image then
					embed[1].image = { url = metadata.image }
					Cache.Tweets[id].imageURL = metadata.image
				end
			end
		end
	end

	-- Hide original embed, send message(s) and add message(s) to tables to be manageable later
	message:hideEmbeds()

	local sent,embedsToSend
	if media and mediaPrimary then embedsToSend = {embed[1]}
	else embedsToSend = embed end

	sent = message.channel:send{ embeds = embedsToSend, reference = { message = message, mention = false } }
	if not sent then message:showEmbeds() return end
	Fixes[message.id] = { fix = {sent}, message = message, time = os.time() + (6*3600) }
	FixesRef[sent.id] = message.id

	if not media then return end

	sent = message.channel:send{ content = media }
	if not sent then return end
	Fixes[message.id].fix[2] = sent
	FixesRef[sent.id] = message.id

	if not embed[2] or not mediaPrimary then return end

	sent = message.channel:send{ embed = embed[2] }
	if not sent then return end
	Fixes[message.id].fix[3] = sent
	FixesRef[sent.id] = message.id
end

-------------------------------------------------
--------------------- EVENTS --------------------
-------------------------------------------------

local function Embed(message,client) -- messageCreate event
	if not message.guild then return end
	if message.author.bot then return end

	for id,reaction in pairs(reactionUrl) do
		if reaction.message.guild.id == message.guild.id and reaction.message.channel.id == message.channel.id then
			reaction.message:removeReaction("embed:"..emojis.reaction,client.user.id)
			reactionUrl[id] = nil
			break
		end
	end

	if message.content:match("<http") or message.content:match("||") then return end

	local links = ExtractLinks(message.content)
	for _,link in pairs(links) do
		if IsFromTwitter(link) then
			if string.match(link,"/status/") then
				if not reactionNeeded then
					Tweet(message,link)
				else
					message:addReaction("embed:"..emojis.reaction)

					reactionUrl[message.id] = {message=message,link=link}
					timer.sleep(10000)
					if reactionUrl[message.id] then
						reactionUrl[message.id] = nil
						message:removeReaction("embed:"..emojis.reaction,client.user.id)
					end
				end
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

local function CreateEmbed(reaction,userId,client) -- reactionAdd event
	if not reactionNeeded then return end

	if not reaction.message.guild then return end

	if reaction.emojiId ~= emojis.reaction then return end

	if userId == client.user.id then return end
	if userId ~= reaction.message.author.id and userId ~= Config.OwnerID then
		reaction.message:removeReaction("embed:"..emojis.reaction,userId)
		return
	end

	if not reactionUrl[reaction.message.id] then return end

	local link = reactionUrl[reaction.message.id].link
	reactionUrl[reaction.message.id] = nil
	reaction.message:removeReaction("embed:"..emojis.reaction,client.user.id)
	reaction.message:removeReaction("embed:"..emojis.reaction,userId)
	Tweet(reaction.message,link)
end

-------------------
-- MODULE CONFIG --
-------------------

local functions = {
	messageCreate = {Embed},
	messageDelete = {UserMessageDeleted,BotMessageDeleted},
	reactionAdd = {DeleteUsingReaction,CreateEmbed},
}

local tableReturn = {}
for eventName,events in pairs(functions) do tableReturn[eventName] = events end
return tableReturn
