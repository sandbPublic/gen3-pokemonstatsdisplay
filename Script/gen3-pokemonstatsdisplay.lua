local VERSIONS = {
    "POKEMON RUBY",
    "POKEMON SAPP",
    "POKEMON FIRE",
    "POKEMON LEAF",
    "POKEMON EMER"
}

local LANGUAGES = {
    "Unknown",
    "Deutsch",
    "French",
    "Italian",
    "Spanish",
    "English",
    "Japanese"
}

local function comparebytetostring(b, s)
    if #b ~= string.len(s) then
        return false
    else
        for i, byte in ipairs(b) do
            if(byte ~= string.byte(s, i)) then
                return false
            end
        end
    end
    return true
end

local function checkversion(version)
	for i,v in ipairs(VERSIONS) do
		if comparebytetostring(version,v) then
			return i
		end
	end
end


			 
local vbytes = memory.readbyterange(0x080000A0, 12)
local vindex = checkversion(vbytes)
if vindex==nil then
	print("Unknown version. Stopping script.")
	return
end

print(string.format("Version: %s", VERSIONS[vindex]))

local lan = memory.readbyte(0x080000AF)
local lindex = 1

if lan==0x44 then
	lindex = 2
elseif lan==0x46 then
	lindex = 3
elseif lan==0x49 then
	lindex = 4
elseif lan==0x53 then
	lindex = 5
elseif lan==0x45 then
	lindex = 6
elseif lan==0x4A then
	lindex = 7
end

print(string.format("Language: %s", LANGUAGES[lindex]))

if lindex == 1 then
	print("This language is not currently supported")
	print("You can help improving this script at: https://github.com/red-the-dev/gen3-pokemonstatsdisplay")
	print("Stopping scrpt")
	return
end

local game=1 --see below

-- Auto-setting game variable

if vindex == 1 or vindex == 2 then  -- R/S
	if lindex == 4 then
		game = 7
	elseif lindex == 6 then
		game = 1
	elseif lindex == 7 then
		game = 4
	end
end

if vindex == 3 or vindex == 4 then  -- FR/LG
	if lindex == 4 or lindex == 6 then
		game = 3
	elseif lindex == 7 then
		game = 6
	elseif lindex == 5 then
		game = 8
	end
end

if vindex == 5 then  -- E
	if lindex == 4 or lindex == 6 then
		game = 2
	elseif lindex == 7 then
		game = 5
	end
end

local RNG_START =0x83ED --insert the first value of RNG

-- These are all the possible key names: [keys]
-- backspace, tab, enter, shift, control, alt, pause, capslock, escape,
-- space, pageup, pagedown, end, home, left, up, right, down, insert, delete,
-- 0 .. 9, A .. Z, numpad0 .. numpad9, numpad*, numpad+, numpad-, numpad., numpad/,
-- F1 .. F24, numlock, scrolllock, semicolon, plus, comma, minus, period, slash, tilde,
-- leftbracket, backslash, rightbracket, quote.
-- [/keys]
-- Key names must be in quotes.
-- Key names are case sensitive.
local HOTKEYS ={
    CHANGE_VIEW="9", 
    INCREMENT="8", 
    DECREMENT="7"
}

-- It is not necessary to change anything beyond this point.

--for different display modes
local viewmode=1
local VIEW_MODES = {
    PLAYER=1,
    ENEMY=2,
    RNG=3
}
local VIEW_MODE_NAMES = {
    "Player",
    "Enemy",
    "RNG"
}

local substatus={1,1,1}

local tabl={}
local prev={}

local X_FIX =0 --x position of display handle
local Y_FIX =65 --y position of display handle

local X_FIX_2 =105 --x position of 2nd handle
local Y_FIX_2 =0 --y position of 2nd handle

--for different game versions
--1: Ruby/Sapphire U
--2: Emerald U
--3: FireRed/LeafGreen U
--4: Ruby/Sapphire J
--5: Emerald J (TODO)
--6: FireRed/LeafGreen J (1360)
--7: Ruby/Sapphire I
--8: FireRed/LeafGreen S

--game dependent

local stats={
    {0x3004360, 0x20244EC, 0x2024284, 0x3004290, 0x2024190, 0x20241E4, 0x3004370, 0x2024284}, -- player
    {0x30045C0, 0x2024744, 0x202402C, 0x30044F0, 0x0000000, 0x2023F8C, 0x30045D0, 0x202402C}  -- enemy
}
local rng   ={0x3004818, 0x3005D80, 0x3005000, 0x3004748, 0x0000000, 0x3005040, 0} --0X3004FA0
local rng2  ={0x0000000, 0x0000000, 0x20386D0, 0x0000000, 0x0000000, 0x203861C, 0}


--HP, Atk, Def, Spd, SpAtk, SpDef
local STAT_DISPLAY = {"HP ", "ATK", "DEF", "SPD", "SAT", "SDF"}
local STAT_COLOR = {"yellow", "red", "blue", "green", "magenta", "cyan"}

dofile "tables.lua"

local last_rng=0

local bnd,br,bxr=bit.band,bit.bor,bit.bxor
local rshift, lshift=bit.rshift, bit.lshift
local mdword=memory.readdwordunsigned
local mword=memory.readwordunsigned
local mbyte=memory.readbyteunsigned

local natureorder={"Atk","Def","Spd","SpAtk","SpDef"}
local naturename={
    "Hardy","Lonely","Brave","Adamant","Naughty",
    "Bold","Docile","Relaxed","Impish","Lax",
    "Timid","Hasty","Serious","Jolly","Naive",
    "Modest","Mild","Quiet","Bashful","Rash",
    "Calm","Gentle","Sassy","Careful","Quirky"
}
local typeorder={
    "Fighting","Flying","Poison","Ground",
    "Rock","Bug","Ghost","Steel",
    "Fire","Water","Grass","Electric",
    "Psychic","Ice","Dragon","Dark"
}

--a 32-bit, b bit position bottom, d size
local function getbits(a,b,d)
    return rshift(a,b)%lshift(1,d)
end

--for RNG purposes
local function gettop(a)
    return(rshift(a,16))
end

--does 32-bit multiplication
--necessary because Lua does not allow 32-bit integer definitions
--so one cannot do 32-bit arithmetic
--furthermore, precision loss occurs at around 10^10
--so numbers must be broken into parts
--may be improved using bitop library exclusively
local function mult32(a,b)
    local c=rshift(a,16)
    local d=a%0x10000
    local e=rshift(b,16)
    local f=b%0x10000
    local g=(c*f+d*e)%0x10000
    local h=d*f
    local i=g*0x10000+h
    return i
end

local function advance_rng(old_rng)
    return mult32(old_rng, 0x41C64E6D) + 0x6073
end

--checksum stuff; add halves
local function ah(a)
    local b=getbits(a,0,16)
    local c=getbits(a,16,16)
    return b+c
end

-- draws a 3x3 square with x position a, y position b, and color c
local function drawsquare(a,b,c)
    gui.box(a,b,a+2,b+2,c)
end

-- draws a down arrow, x position a, y position b, and color c
-- this arrow marks the square for the current RNG value
local function drawarrow(a,b,c)
    gui.line(a,b,a-2,b-2,c)
    gui.line(a,b,a+2,b-2,c)
    gui.line(a,b,a,b-6,c)
end

--a press is when input is registered on one frame but not on the previous
--that's why the previous input is used as well
prev=input.get()
local function fn()
--*********
    tabl=input.get()

    if tabl[HOTKEYS.CHANGE_VIEW] and not prev[HOTKEYS.CHANGE_VIEW] then
        viewmode=viewmode+1
        if viewmode > VIEW_MODES.ENEMY then
            viewmode = VIEW_MODES.PLAYER
        end
    end

    if tabl[HOTKEYS.INCREMENT] and not prev[HOTKEYS.INCREMENT] then
        substatus[viewmode]=substatus[viewmode]+1
        if substatus[viewmode] > 6 then
            substatus[viewmode]=1
        end
    end

    if tabl[HOTKEYS.DECREMENT] and not prev[HOTKEYS.DECREMENT] then
        substatus[viewmode]=substatus[viewmode]-1
        if substatus[viewmode] < 1 then
            substatus[viewmode]=6
        end
    end

    prev=tabl

    -- gui.text(200,0,status)
    -- gui.text(200,10,substatus[1])
    -- gui.text(200,20,substatus[2])

    -- now for display
    if viewmode==VIEW_MODES.PLAYER or viewmode==VIEW_MODES.ENEMY then
        local start=stats[viewmode][game]+100*(substatus[viewmode]-1)

        local personality=mdword(start)
        local trainerid=mdword(start+4)
        local magicword=bxr(personality, trainerid)

        local i=personality%24

        local growthoffset=(growthtbl[i+1]-1)*12
        local attackoffset=(attacktbl[i+1]-1)*12
        local effortoffset=(efforttbl[i+1]-1)*12
        local miscoffset=(misctbl[i+1]-1)*12

        local growth1=bxr(mdword(start+32+growthoffset),magicword)
        local growth2=bxr(mdword(start+32+growthoffset+4),magicword)
        local growth3=bxr(mdword(start+32+growthoffset+8),magicword)

        local attack1=bxr(mdword(start+32+attackoffset),magicword)
        local attack2=bxr(mdword(start+32+attackoffset+4),magicword)
        local attack3=bxr(mdword(start+32+attackoffset+8),magicword)

        local effort1=bxr(mdword(start+32+effortoffset),magicword)
        local effort2=bxr(mdword(start+32+effortoffset+4),magicword)
        local effort3=bxr(mdword(start+32+effortoffset+8),magicword)

        local misc1=bxr(mdword(start+32+miscoffset),magicword)
        local misc2=bxr(mdword(start+32+miscoffset+4),magicword)
        local misc3=bxr(mdword(start+32+miscoffset+8),magicword)

        local cs=ah(growth1)+ah(growth2)+ah(growth3)+ah(attack1)+ah(attack2)+ah(attack3)
            +ah(effort1)+ah(effort2)+ah(effort3)+ah(misc1)+ah(misc2)+ah(misc3)

        cs=cs%65536

        gui.text(0,10, mword(start+28))
        gui.text(0,20, cs)

        local species=getbits(growth1,0,16)

        local holditem=getbits(growth1,16,16)

        local pokerus=getbits(misc1,0,8)

        local evs1=effort1
        local evs2=effort2

        local ivs = {}
        local hidpowtype = 0
        local hidpowbase = 0
        local multiplier = 1
        for i = 1, 6 do
            ivs[i] = getbits(misc2, 5*(i-1),5)
            hidpowtype = hidpowtype + multiplier * (ivs[i]%2)
            hidpowbase = hidpowbase + multiplier * getbits(ivs[i],1,1)
            multiplier = multiplier * 2
        end
        hidpowtype=math.floor((hidpowtype*15)/63)
        hidpowbase=math.floor((hidpowbase*40)/63 + 30)

        local nature=personality%25
        local natinc=math.floor(nature/5)
        local natdec=nature%5

        local move1=getbits(attack1,0,16)
        local move2=getbits(attack1,16,16)
        local move3=getbits(attack2,0,16)
        local move4=getbits(attack2,16,16)
        local pp1=getbits(attack3,0,8)
        local pp2=getbits(attack3,8,8)
        local pp3=getbits(attack3,16,8)
        local pp4=getbits(attack3,24,8)

        gui.text(X_FIX+15,Y_FIX-8, "Stat")
        gui.text(X_FIX+35,Y_FIX-8, "IV")
        gui.text(X_FIX+50,Y_FIX-8, "EV")
        gui.text(X_FIX+65,Y_FIX-8, "Nat")

        local speciesname=pokemontbl[species]
        if speciesname==nil then speciesname="none" end

        gui.text(X_FIX,Y_FIX-16, string.format("CurHP: %3d/%3d", mword(start+86), mword(start+88)), STAT_COLOR[1])
        gui.text(X_FIX,Y_FIX-24, string.format("%s %d %s", VIEW_MODE_NAMES[viewmode], substatus[viewmode], speciesname))

        local evs = {
            getbits(evs1, 0, 8),
            getbits(evs1, 8, 8),
            getbits(evs1, 16, 8),
            getbits(evs1, 24, 8),
            getbits(evs2, 0, 8),
            getbits(evs2, 8, 8),
        }
        for i = 1, 6 do
            gui.text(X_FIX,Y_FIX+8*(i-1), STAT_DISPLAY[i], STAT_COLOR[i])
            gui.text(X_FIX+20,Y_FIX+8*(i-1), string.format("%3d", mword(start+88+2*(i-1))), STAT_COLOR[i])
            gui.text(X_FIX+35,Y_FIX+8*(i-1), string.format("%2d", ivs[i]), STAT_COLOR[i])
            gui.text(X_FIX+50,Y_FIX+8*(i-1), string.format("%3d", evs[i]), STAT_COLOR[i])
        end

        if natinc~=natdec then
            gui.text(X_FIX+65,Y_FIX+8*(natinc+1), "+", STAT_COLOR[natinc+2])
            gui.text(X_FIX+65,Y_FIX+8*(natdec+1), "-", STAT_COLOR[natdec+2])
        else
            gui.text(X_FIX+65,Y_FIX+8*(natinc+1), "+-", "grey")
        end

        -- gui.text(xfix2, yfix2,"Species "..species)
        -- gui.text(xfix2, yfix2+10,"Nature: "..naturename[nature+1])
        -- gui.text(xfix2, yfix2+20,natureorder[natinc+1].."+ "..natureorder[natdec+1].."-")

        local movename1=movetbl[move1] or "none"
        local movename2=movetbl[move2] or "none"
        local movename3=movetbl[move3] or "none"
        local movename4=movetbl[move4] or "none"

        gui.text(X_FIX_2, Y_FIX_2, "1: "..movename1)
        gui.text(X_FIX_2, Y_FIX_2+10, "2: "..movename2)
        gui.text(X_FIX_2, Y_FIX_2+20, "3: "..movename3)
        gui.text(X_FIX_2, Y_FIX_2+30, "4: "..movename4)
        gui.text(X_FIX_2+65, Y_FIX_2, "PP: "..pp1)
        gui.text(X_FIX_2+65, Y_FIX_2+10, "PP: "..pp2)
        gui.text(X_FIX_2+65, Y_FIX_2+20, "PP: "..pp3)
        gui.text(X_FIX_2+65, Y_FIX_2+30, "PP: "..pp4)
        gui.text(X_FIX_2, Y_FIX_2+40,"Hidden Power: "..typeorder[hidpowtype+1].." "..hidpowbase)
        gui.text(X_FIX_2, Y_FIX_2+50,"Hold Item "..holditem)
        gui.text(X_FIX_2, Y_FIX_2+60,"Pokerus Status "..pokerus)
        gui.text(X_FIX_2, Y_FIX_2+70, "Pokerus remain "..mbyte(start+85))
    end

    if viewmode==VIEW_MODES.RNG then
        local rng_steps=0
        local curr_rng=memory.readdword(rng[game])
        local next_rng=last_rng
        while bit.tohex(curr_rng)~=bit.tohex(next_rng) and rng_steps<=100 do
            next_rng=advance_rng(next_rng)
            rng_steps=rng_steps+1
        end
        gui.text(120,20,"Last RNG value: "..bit.tohex(last_rng))
        last_rng=curr_rng
        gui.text(120,0,"Current RNG value: "..bit.tohex(curr_rng))
        if rng_steps<=100 then
            gui.text(120,10,"RNG distance since last: "..rng_steps)
        else
            gui.text(120,10,"RNG distance since last: >100")
        end

        --math
        local indexfind=RNG_START
        local index=0
        for j=0,31 do
            if getbits(curr_rng,j,1)~=getbits(indexfind,j,1) then
                indexfind=mult32(indexfind,multspa[j+1])+multspb[j+1]
                index=index+bit.lshift(1,j)
                if j==31 then
                    index=index+0x100000000
                end
            end
        end
        gui.text(120,30,index)

        local modd = 3
        if substatus[3]>=5 and substatus[3]<=8 then
            modd = 2
        end

        if rng_steps>modd and rng_steps<=100 then
            gui.box(3,30,17,44, "red")
            gui.box(5,32,15,42, "black")
        end

        local substatusremainder = substatus[3]%4
        if substatusremainder==1 then
            gui.text(10,45, "Critical Hit/Max Damage")
        elseif substatusremainder==2 then
            gui.text(10,45, "Move Miss (95%)")
        elseif substatusremainder==3 then
            gui.text(10,45, "Move Miss (90%)")
        else
            gui.text(10,45, "Quick Claw")
        end
            
        drawarrow(3,52, "#FF0000FF")
        next_rng=curr_rng
        -- i row j column
        for i=0,13 do
            for j=0,17 do
                local clr="#808080FF"
                if j%modd==1 then
                    clr="#C0C0C0FF"
                end
                local randvalue=gettop(next_rng)

                if substatusremainder==1 then
                    if randvalue%16==0 then
                        local test2=next_rng
                        for _=1,7 do
                            test2=advance_rng(test2)
                        end
                        clr={r=255, g=0x10*(gettop(test2)%16), b=0, a=255}
                    end
                elseif substatusremainder==2 then
                    if randvalue%100>=95 then
                        clr="#0000FFFF"
                    end
                elseif substatusremainder==3 then
                    if randvalue%100>=90 then
                        clr="#000080FF"
                    end
                else
                    --if randvalue<0x3333 then
                    if randvalue%512==62 then
                        clr="#00FF00FF"
                    end
                end	  
                
                drawsquare(2+4*j,54+4*i, clr)

                next_rng=advance_rng(next_rng)
            end
        end
    end

    gui.text(0,0,emu.framecount())

    --*********
end
gui.register(fn)
