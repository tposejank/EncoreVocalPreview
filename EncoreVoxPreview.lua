version_num="0.0.1"

startxoff = 100
voxlineh = 100
startyoff = 200

phraserecth = 50

-- imgScale=480/1024
movequant=10
quants={1/32,1/24,1/16,1/12,1/8,1/6,1/4,1/3,1/2,1,2,4}
-- highway rendering vars
midiHash=""
beatHash=""
eventsHash=""
trackSpeed=2
inst=5
diff=4
-- pixelsDrumline = 5
-- hopothresh = 170 -- ticks
-- guitarSoloP = 103
-- trillP = 127
-- tremoloP = 126
curOdPhrase = 0
curPhrase = 0
-- beatLineTimes = false
pR={
	36,84
} --pitch ranges
oP=116 --overdrive pitch
pP = 105 -- hahah pp
aPP = 106

offset=0
notes={}
od_phrases = {}
solo_markers = {}

phrases = {}
lyrics = {}
-- tremolos = {}

beatLines={}
eventsData={}
trackRange={0,0}

curTime=0
curTimeLine=1
curEvent=1
-- lastcurnote = 1
curNote=1
-- nxoff=152 --x offset
-- nxm=0.05 --x mult of offset
nyoff=192 --y offset
-- nsm=0.05 --scale multiplier

isunpitchedmode = false

lastCursorTime=reaper.GetCursorPosition()

showHelp=false

local function rgb2num(r, g, b)
	g = g * 256
	b = b * 256 * 256
	return r + g + b
end

function toFractionString(number)
	if number<1 then
		return string.format('1/%d', math.floor(1/number))
	else
		return string.format('%d',number)
	end
end

function getNoteIndex(time, lane)
	for i, note in ipairs(notes) do
		if note[1] == time and note[3] == lane then
			return i
		end
	end
	return -1
end

function findLyric(time,lyricsarr)
	for i, lyrc in ipairs(lyricsarr) do -- lyrc is intentional. I need to keep track of stuff
		if lyrc[1] == time then
			return i
		end
	end
	return -1
end

function findTrack(trackName)
	local numTracks = reaper.CountTracks(0)
	for i = 0, numTracks - 1 do
		local track = reaper.GetTrack(0, i)
		local _, currentTrackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
		if currentTrackName == trackName then
			return track
		end
	end
	return nil
end

gfx.clear = rgb2num(42, 0, 71)
gfx.init("Encore Vox Preview", 640, 190, 0, 200, 200)

instrumentTracks={
	{"PART VOCALS",findTrack("PART VOCALS")},
	{"PART VOCAL",findTrack("PART VOCAL")},
	{"PLASTIC VOCALS",findTrack("PLASTIC VOCALS")},
	{"PRO VOCALS",findTrack("PRO VOCALS")},
	{"PART VOCALS [Unpitched]",findTrack("PART VOCALS")},
	{"PART VOCAL [Unpitched]",findTrack("PART VOCAL")},
	{"PLASTIC VOCALS [Unpitched]",findTrack("PLASTIC VOCALS")},
	{"PRO VOCALS [Unpitched]",findTrack("PRO VOCALS")},
}

eventTracks={
	findTrack("EVENTS"),
	findTrack("BEAT")
}

function stringstarts(String,Start)
	return string.sub(String,1,string.len(Start))==Start
end

local function notesCompare(a, b)
	return a[1] < b[1]
end
function parseNotes(take)
	notes = {}
	lyrics = {}

	_,_,_,textcount = reaper.MIDI_CountEvts(take)
	for i = 0, textcount - 1 do
		_,_,_,epos,etype,msg = reaper.MIDI_GetTextSysexEvt(take, i)
		etime = reaper.MIDI_GetProjTimeFromPPQPos(take, epos)
		if etype==5 or etype==1 and not stringstarts(msg, '[') then
			table.insert(lyrics,{etime,msg})
		end
	end

	od_phrases={}
	phrases = {}

	od=false
	cur_od_phrase=1

	_, notecount = reaper.MIDI_CountEvts(take)

	for i = 0, notecount - 1 do
		_, _, _, spos, epos, _, pitch, _ = reaper.MIDI_GetNote(take, i)
		ntime = reaper.MIDI_GetProjTimeFromPPQPos(take, spos)
		nend = reaper.MIDI_GetProjTimeFromPPQPos(take, epos)
		ntimebeats = reaper.MIDI_GetProjQNFromPPQPos(take, spos)
		nendbeats = reaper.MIDI_GetProjQNFromPPQPos(take, epos)
		if pitch == oP then
			table.insert(od_phrases, {ntime,nend})
		elseif pitch == pP or pitch == aPP then
			table.insert(phrases, {ntime,nend})
		elseif pitch >= pR[1] and pitch <= pR[2] then
			local valid=true
			local lane = pitch - pR[1]

			lyricIndex = findLyric(ntime, lyrics)
			lyricMessage = ''
			if lyricIndex == -1 then
				valid = false
			else
				lyricMessage = lyrics[lyricIndex][2]
			end
			table.insert(notes, {ntime, nend - ntime, lane, false, valid, lyricMessage, true}) -- last arg = render as a note
		end
	end

	-- corrects lyrics
	for j = 1, #lyrics do
		local lyric = lyrics[j]
		local time = lyric[1] 
		local foundyet = false
		for k = 1,#notes do
			if notes[k][1] == time then
				foundyet = true
				-- reaper.ShowConsoleMsg('Found note for '..j)
				break
			end
		end

		if not foundyet then
			table.insert(notes, {time, 0, 0, false, valid, lyric[2], false})
		end
	end

	if #od_phrases~=0 then
		for i=1,#notes do
			if notes[i][1]>od_phrases[cur_od_phrase][2] then
				if cur_od_phrase<#od_phrases then cur_od_phrase=cur_od_phrase+1 end
			end
			if notes[i][1]>=od_phrases[cur_od_phrase][1] and notes[i][1]<od_phrases[cur_od_phrase][2] then
				notes[i][4]=true
			end
		end
	end
	table.sort(notes,notesCompare)
end

function updateMidi()
	instrumentTracks={
		{"PART VOCALS",findTrack("PART VOCALS")},
		{"PART VOCAL",findTrack("PART VOCAL")},
		{"PLASTIC VOCALS",findTrack("PLASTIC VOCALS")},
		{"PRO VOCALS",findTrack("PRO VOCALS")},
		{"PART VOCALS [Unpitched]",findTrack("PART VOCALS")},
		{"PART VOCAL [Unpitched]",findTrack("PART VOCAL")},
		{"PLASTIC VOCALS [Unpitched]",findTrack("PLASTIC VOCALS")},
		{"PRO VOCALS [Unpitched]",findTrack("PRO VOCALS")},
	}
	if instrumentTracks[inst][2] then
		local numItems = reaper.CountTrackMediaItems(instrumentTracks[inst][2])
		for i = 0, numItems-1 do
			local item = reaper.GetTrackMediaItem(instrumentTracks[inst][2], i)
			local take = reaper.GetActiveTake(item)
			local _,hash=reaper.MIDI_GetHash(take,false)-- true if only notes
			if midiHash~=hash then
				parseNotes(take)
				curNote=1
				for i=1,#notes do
					curNote=i
					if notes[i][1]+notes[i][2]>=curTime then
						break
					end
					
				end
				midiHash=hash
			end
		end
	else
		midiHash=""
		notes={}
	end
end

function updateEvents()
	eventTracks[1]=findTrack("EVENTS")
	if eventTracks[1] then
		local numItems = reaper.CountTrackMediaItems(eventTracks[1])
		for i = 0, numItems-1 do
			local item = reaper.GetTrackMediaItem(eventTracks[1], i)
			local take = reaper.GetActiveTake(item)
			local _,hash=reaper.MIDI_GetHash(take,false)
			if eventsHash~=hash then
				eventsData={}
				_,_,_,textcount = reaper.MIDI_CountEvts(take)
				for i = 0, textcount - 1 do
					_,_,_,epos,etype,msg = reaper.MIDI_GetTextSysexEvt(take, i)
					etime = reaper.MIDI_GetProjTimeFromPPQPos(take, epos)
					if etype==1 then
						table.insert(eventsData,{epos,msg})
						if msg=="[music_start]" then trackRange[1]=etime
						elseif msg=="[end]" then trackRange[2]=etime
						end
					end
				end
				eventsHash=hash
			end
		end
	else
		eventsHash=""
		eventsData={}
	end
end

function updateBeatLines()
	eventTracks[2]=findTrack("BEAT")
	if eventTracks[2] then
		local numItems = reaper.CountTrackMediaItems(eventTracks[2])
		for i = 0, numItems-1 do
			local item = reaper.GetTrackMediaItem(eventTracks[2], i)
			local take = reaper.GetActiveTake(item)
			local _,hash=reaper.MIDI_GetHash(take,true)
			if beatHash~=hash then
				beatLines={}
				_, notecount = reaper.MIDI_CountEvts(take)
				for i = 0, notecount - 1 do
					_, _, _, spos, _, _, pitch, _ = reaper.MIDI_GetNote(take, i)
					btime = reaper.MIDI_GetProjTimeFromPPQPos(take, spos)
					db=true
					if pitch==13 then
						db=false
					end
					if btime>=trackRange[1] and btime<trackRange[2] then
						table.insert(beatLines,{btime,db})
					end
				end
				beatHash=hash
			end
		end
	else
		beatHash=""
		beatLines={}
	end
end

function drawNotes()
	-- isplastic = inst >= 5
	-- isprodrums = inst == 5
	-- isexpert = diff == 4
	-- isriffmaster = inst >= 6

	if not isunpitchedmode then
		for i=1,#notes do
			invalid=false
			ntime=notes[i][1]
			nlen=notes[i][2]
			local rtrackspeed = trackSpeed - 2.85
			-- nlenbeats=notes[i][7]
			if notes[i][5]==false then
				invalid=true
			end
			lane=notes[i][3]
			od=notes[i][4]
			text=notes[i][6]
			text = string.gsub(text, "=", "-") -- ignores the equal sing
	
			canrender = notes[i][7]
			
			-- a random note with render set to false means it is invalid
			-- however, if the text ends in # means its unpitched therefore not invalid
			if not text:find('#') and not canrender then
				invalid = true
			end
	
			text = string.gsub(text, "#", "") -- ignores the hashtag sign
	
			rtime=((ntime-curTime)*(rtrackspeed+2))
			rend=(((ntime+nlen)-curTime)*(rtrackspeed+2))

			local notex = startxoff + (nyoff * rtime)
			local endy = (voxlineh - 3) + startyoff
			local starty = startyoff
			local notey = startyoff + (lane - pR[1]) * (starty - endy) / (pR[2] - pR[1]) + 25
			--reaper.ShowConsoleMsg('\n'.. notey)
			notexend = startxoff + (nyoff * rend)
	
			if stringstarts(text, '+') then -- connect with the previous note as the + means it continues it
				if #notes >= 2 then
					text = string.gsub(text, "+", "")
	
					prev = notes[i-1]
	
					lastinvalid=false
					lastntime=prev[1]
					lastnlen=prev[2]
					if prev[5]==false then
						lastinvalid=true
					end
					lastlane=prev[3]
					lastod=prev[4]
					lasttext=prev[6]
					lastcanrender = prev[7]
					if not lasttext:find('#') and not lastcanrender then
						lastinvalid = true
					end
					lastrtime=((lastntime-curTime)*(rtrackspeed+2))
					lastrend=(((lastntime+lastnlen)-curTime)*(rtrackspeed+2))
	
					local lastendy = (voxlineh - 3) + startyoff
					local laststarty = startyoff
					local lastnotey = startyoff + (lastlane - pR[1]) * (laststarty - lastendy) / (pR[2] - pR[1]) + 25
					lastnotexend = startxoff + (nyoff * lastrend)
	
					gfx.r, gfx.g, gfx.b = 0.8, 0, 0.8
					if lastod then
						gfx.r, gfx.g, gfx.b=.53,.6,.77
					end
		
					if lastinvalid then
						gfx.r, gfx.g, gfx.b=1,0,0
					end
	
					if lastcanrender then
						if notex > 0 then
							gfx.line(lastnotexend,lastnotey,notex,notey)
							gfx.line(lastnotexend,lastnotey+1,notex,notey+1)
							gfx.line(lastnotexend,lastnotey+2,notex,notey+2)
						end
					end
				end
			end
	
			if --[[rend>=-0.05]] true then
				gfx.r, gfx.g, gfx.b = 0.8, 0, 0.8
				if od then
					gfx.r, gfx.g, gfx.b=.53,.6,.77
				end
	
				if invalid then
					gfx.r, gfx.g, gfx.b=1,0,0
				end
				if notexend > 0 and notex < gfx.w then -- offscreen
					if canrender then
						gfx.line(notex,notey,notexend,notey)
						gfx.line(notex,notey+1,notexend,notey+1)
						gfx.line(notex,notey+2,notexend,notey+2)
					end
	
					if od then
						gfx.r, gfx.g, gfx.b=.53,.6,.77
						local pos = {
							{-1, -1},
							{-1, 0},
							{-1, 1},
							{0, 1},
							{1, 1},
							{1, 0},
							{1, -1},
							{0, -1},
						}
						for i = 1, 8 do
							gfx.setfont(1, "Arial", 20)
							gfx.x,gfx.y=notex + pos[i][1], (startyoff + voxlineh + 5) + pos[i][2]
							gfx.drawstr(text)
						end
					end
	
					gfx.x,gfx.y=notex,startyoff + voxlineh + 5
					gfx.setfont(1, "Arial", 20)
					if not invalid then gfx.r, gfx.g, gfx.b = 1, 1, 1 end
					gfx.drawstr(text)
				end
			end
		end
	end

	if not isunpitchedmode then
		for i=1,#phrases do
			ntime=phrases[i][2]
			-- nlen=phrases[i][2]
			local rtrackspeed = trackSpeed - 2.85
	
			rtime=((ntime-curTime)*(rtrackspeed+2))
			-- rend=(((ntime+nlen)-curTime)*(rtrackspeed+2))
	
			--
	
			if --[[rend>=-0.05]] true then
				gfx.r, gfx.g, gfx.b = 0.81, 0.37, 0.81
	
				phrasey = startyoff
				phrasex = startxoff + (nyoff * rtime)
				addy = 25
	
				-- reaper.ShowConsoleMsg(phrasey..' '..phrasex..'\n')
	
				if phrasex > -3 and phrasex < gfx.w then -- offscreen
					for j = 1,3 do
						gfx.line(phrasex+j,phrasey,phrasex+j,phrasey + voxlineh + addy)
					end
				end
			end
		end
	end
end

function moveCursorByBeats(increment)
    local currentPosition = reaper.GetCursorPosition()
    local currentBeats = reaper.TimeMap2_timeToQN(reaper.EnumProjects(-1), currentPosition)

    -- Calculate the new position in beats
	local newBeats = currentBeats + increment
	newBeats=math.floor(newBeats*(1/quants[movequant])+0.5)/(1/quants[movequant])
	-- Convert the new beats position to seconds
    local newPosition = reaper.TimeMap2_QNToTime(reaper.EnumProjects(-1), newBeats)
    -- Move the edit cursor to the new position
    reaper.SetEditCurPos2(0, newPosition, true, true)
end

updateMidi()
updateEvents()
updateBeatLines()

keyBinds={
	[91]=function()
		if inst==1 then inst=#instrumentTracks else inst=inst-1 end
		midiHash=""
		updateMidi()
	end,
	[93]=function()
		if inst==#instrumentTracks then inst=1 else inst=inst+1 end
		midiHash=""
		updateMidi()
	end,
	[43]=function()
		trackSpeed = trackSpeed+0.25
	end,
	[61]=function()
		trackSpeed = trackSpeed+0.25
	end,
	[45]=function()
		if trackSpeed>1 then trackSpeed = trackSpeed-0.25 end
	end,
	[125]=function()
		offset = offset+0.01
	end,
	[123]=function()
		offset = offset-0.01
	end,
	[32]=function()
		if reaper.GetPlayState()==1 then
			reaper.OnStopButton()
		else
			reaper.OnPlayButton()
		end
	end,
	[1919379572.0]=function()
		moveCursorByBeats(quants[movequant])
	end,
	[1818584692.0]=function()
		moveCursorByBeats(-quants[movequant])
	end,
	[1685026670.0]=function() 
		if movequant==1 then movequant=#quants else movequant=movequant-1 end
	end,
	[30064.0]=function() 
		if movequant==#quants then movequant=1 else movequant=movequant+1 end
	end,
	[26161.0]=function() showHelp = not showHelp end,
}

function findMissingElements(table1, table2)
    local result = {}
    local table2Set = {}
    for _, v in ipairs(table2) do
        table2Set[v] = true
    end
    for _, v in ipairs(table1) do
        if not table2Set[v] then
            table.insert(result, v)
        end
    end

    return result
end

local function Main()
	imgScale=math.min(gfx.w,gfx.h)/1024
	local char = gfx.getchar()
	if char ~= -1 then
		reaper.defer(Main)
	end
	playState=reaper.GetPlayState()
	if keyBinds[char] then
        keyBinds[char]()
    end
	isunpitchedmode = inst >= 5
	if playState==1 then
		curTime=reaper.GetPlayPosition()-offset
	end
	curCursorTime=reaper.GetCursorPosition()
	if playState~=1  then
		curTime=curCursorTime
	end
	if curCursorTime~=lastCursorTime then
		lastCursorTime=curCursorTime
	end
	curNote=1
	for i=1,#notes do
		curNote=i
		if notes[i][1]+notes[i][2]>=curTime then
			break
		end
	end
	curOdPhrase=1
	for i=1,#od_phrases do
		if od_phrases[i][1] <= curTime then
			curOdPhrase = i
		end
	end
	curPhrase=1
	for i=1,#phrases do
		if phrases[i][1] <= curTime then
			curPhrase = i
		end
	end

	startyoff = (gfx.h / 2) - (voxlineh / 2)
	gfx.r, gfx.g, gfx.b = 0.4, 0, 0.4
	
	if not isunpitchedmode then
		gfx.rect(0, startyoff, gfx.w, voxlineh + 25)

		-- draw the gray line thingy
		gfx.r, gfx.g, gfx.b = 0.59, 0.12, 0.59
		gfx.line(startxoff, startyoff, startxoff, startyoff + voxlineh)
		gfx.line(startxoff + 1, startyoff, startxoff + 1, startyoff + voxlineh)
	
		-- draw the line corners
		gfx.rect(startxoff - 5, startyoff, 13, 3)
		gfx.rect(startxoff - 3, startyoff + 3, 9, 3)
		gfx.rect(startxoff - 1, startyoff + 6, 5, 3)
	
		gfx.rect(startxoff - 5, (startyoff + voxlineh) - 3, 13, 3)
		gfx.rect(startxoff - 3, (startyoff + voxlineh) - 6, 9, 3)
		gfx.rect(startxoff - 1, (startyoff + voxlineh) - 9, 5, 3)
	
		gfx.r, gfx.g, gfx.b = 0.32, 0, 0.32
	
		-- draw the separator lines
		gfx.rect(0, startyoff-3, gfx.w, 3)
		gfx.rect(0, startyoff + voxlineh, gfx.w, 3)
		gfx.rect(0, startyoff + voxlineh + 25, gfx.w, 3)
	else
		startyoff = (gfx.h / 2) - (phraserecth / 2)

		gfx.r, gfx.g, gfx.b = 0.4, 0, 0.4
		-- main bg
		gfx.rect(0, startyoff, gfx.w, phraserecth)
		-- lines
		gfx.r, gfx.g, gfx.b = 0.32, 0, 0.32
		gfx.rect(0, startyoff, gfx.w, 5)
		gfx.rect(0, startyoff + phraserecth - 5, gfx.w, 5)
		

		gfx.r, gfx.g, gfx.b = 1,1,1
		gfx.setfont(1, "Arial", 25)

		local lyricTextsInCurPhrase = {}
		local lyricsUntilThePHPoint = {}

		if #phrases > 0 then
			for i = 1, #lyrics do
				if lyrics[i][1] >= phrases[curPhrase][1] and lyrics[i][1] < phrases[curPhrase][2] then
					-- if lyrics[i][2] ~= '+' then -- it doesnt work if the phrase ends with a + for some reason
						-- reaper.ShowConsoleMsg(lyrics[i][2]..'\n')
						table.insert(lyricTextsInCurPhrase, lyrics[i])
	
						if i ~= #lyrics then
							if lyrics[i + 1][1] > curTime then
								table.insert(lyricsUntilThePHPoint, lyrics[i])
							end
						end
	
						if i == #lyrics then -- just add it
							table.insert(lyricsUntilThePHPoint, lyrics[i])
						end
					-- end
				end
			end
		end

		if #lyricTextsInCurPhrase > 0 then
			local realLyricTextsInCurPhrase = {}
			for k = 1, #lyricTextsInCurPhrase do
				table.insert(realLyricTextsInCurPhrase, lyricTextsInCurPhrase[k][2])
			end
			fullText = table.concat(realLyricTextsInCurPhrase, ' ')
			fullText = string.gsub(fullText, '- ', '')
			currentlyDoing = ''
			if #lyricsUntilThePHPoint > 0 then
				currentlyDoing = lyricsUntilThePHPoint[1][2]
				realCurrentlyDoing = string.gsub(currentlyDoing, '-', '')
			end
	
			local realMissingElements = {}
			-- doing this fixes often times where there are two 'I' in the phrase
			local fakeMissingElements = findMissingElements(lyricTextsInCurPhrase, lyricsUntilThePHPoint)
			for k = 1, #fakeMissingElements do
				table.insert(realMissingElements, fakeMissingElements[k][2])
			end
			
	
			alreadyDone = table.concat(realMissingElements, ' ')
			alreadyDone = string.gsub(alreadyDone, '- ', '')
			realAlreadyDone = string.gsub(alreadyDone, '-', '')
	
			pstrx,pstry = gfx.measurestr(fullText)
	
			gfx.x = (gfx.w / 2 ) - (pstrx / 2)
			storeDefaultX = gfx.x
			gfx.y = (gfx.y / 2 ) - (pstry / 2) + 7
	
			-- draw the entire text first
			gfx.drawstr(fullText)
	
			gfx.x = storeDefaultX

			-- gfx.y = gfx.y + 30
	
			-- draw the text already done
			gfx.r, gfx.g, gfx.b = 0.8,0.8,0.8
			gfx.drawstr(realAlreadyDone)
	
			-- last bullshiz
			local space = ' '
			if alreadyDone:find('-') or alreadyDone == '' then space = '' end
			strsx, _ = gfx.measurestr(realAlreadyDone..space)
			gfx.x = storeDefaultX + strsx
	
			-- gfx.y = gfx.y + 30

			-- reaper.ShowConsoleMsg(realAlreadyDone..' '..realCurrentlyDoing..'\n')

			-- draw the text that is currently being sung
			gfx.r, gfx.g, gfx.b = 1,1,0
			gfx.drawstr(realCurrentlyDoing)
		end

		if curPhrase ~= #phrases then -- stop sign one
			local lyricTextsInTheNextPhrase = {}
			for m = 1, #lyrics do
				if #phrases > 1 then -- stop sign two
					if lyrics[m][1] >= phrases[curPhrase+1][1] and lyrics[m][1] < phrases[curPhrase+1][2] then
						table.insert(lyricTextsInTheNextPhrase, lyrics[m][2])
					end
				end
			end

			local nextphrasetext = table.concat(lyricTextsInTheNextPhrase, ' ')
			nextphrasetext = string.gsub(nextphrasetext, '- ', '')

			local nextphraserecth = 30
			gfx.r, gfx.g, gfx.b = 0.4, 0, 0.4
			-- main bg (next phrase)
			calcx = (gfx.w /2) - ((gfx.w - (gfx.w/3)) /2) 
			gfx.rect(calcx, startyoff + phraserecth, gfx.w - (gfx.w/3), nextphraserecth)
			-- lines (next phrase)
			gfx.r, gfx.g, gfx.b = 0.32, 0, 0.32
			-- gfx.rect(0, startyoff, gfx.w, 5)
			gfx.rect(calcx, startyoff + phraserecth + nextphraserecth, gfx.w - (gfx.w/3), 3)

			gfx.r, gfx.g, gfx.b = 0.8,0.8,0.8
			gfx.setfont(1, "Arial", 20)

			pstrx2,pstrx2 = gfx.measurestr(nextphrasetext)

			gfx.x = (gfx.w / 2 - pstrx2 / 2)
			gfx.y = startyoff + phraserecth + 5
			gfx.drawstr(nextphrasetext)
		end
	end

	updateEvents()
	updateMidi()
	updateBeatLines()
	drawNotes()
	gfx.x,gfx.y=0,0
	gfx.setfont(1, "Arial", 15)
	gfx.r, gfx.g, gfx.b = 1, 1, 1
	if not isunpitchedmode then
		gfx.drawstr(string.format(
			[[%s ---- Note: %d/%d
			]],
			-- diffNames[diff],
			instrumentTracks[inst][1],
			curNote,
			tostring(#notes)
		))
	else
		gfx.drawstr(string.format(
			[[%s ---- Syllable: %d/%d
			]],
			-- diffNames[diff],
			instrumentTracks[inst][1],
			curNote,
			tostring(#notes)
		))
	end
	local stuff = string.format(
		[[%.03f s | %s | Offset: %.02f | Speed: %.02f 
		]],
		curTime,
		toFractionString(quants[movequant]),
		offset,
		trackSpeed)
	--gfx.setfont(1, "Arial", 15)
	strx,stry = gfx.measurestr(stuff)
	gfx.x,gfx.y=gfx.w-strx,0
	gfx.r, gfx.g, gfx.b = 1, 1, 1
	gfx.drawstr(stuff)
	gfx.x,gfx.y=0,gfx.h-15
	gfx.setfont(1, "Arial", 15)
	gfx.drawstr(string.format("v%s",version_num))
	strx,stry=gfx.measurestr("[F1] Controls")
	gfx.x,gfx.y=gfx.w-strx,gfx.h-stry
	gfx.drawstr("[F1] Controls")

	if showHelp then
		gfx.mode=0
		gfx.r,gfx.g,gfx.b,gfx.a=0,0,0,0.75
		gfx.rect(0,0,gfx.w,gfx.h)
		gfx.r,gfx.g,gfx.b,gfx.a=1,1,1,1
		gfx.x,gfx.y=0,320*imgScale
		gfx.setfont(1, "Arial", 15)

		local HELP = [[Change track type: [ / ]
		Change track speed: + / -
		Change offset: { / } (Shift + [ / ])
		Change snap: up / down arrow keys
		Scroll: left/right arrow keys]]
		strx,stry = gfx.measurestr(HELP)
		gfx.x,gfx.y = gfx.w/2 - strx/2, gfx.h/2 - stry/2

		gfx.drawstr(HELP)
	end
	lastcurnote = curNote
	gfx.update()
end

Main()
