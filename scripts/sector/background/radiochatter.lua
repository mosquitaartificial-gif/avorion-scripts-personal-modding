package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("randomext")
include ("callable")
include ("galaxy")
include ("faction")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RadioChatter
RadioChatter = {}
local self = RadioChatter
local xsotanChatter = nil
local riftInvasionBase = false

if onClient() then

self.entityTimes = {}
self.specificLines = {}
self.dist = nil

self.EntityTimeBetweenSpeechBubbles = 120

function RadioChatter.getUpdateInterval()
    if not self.which then return 1 end

    return 30 + random():getInt(15)
end

function RadioChatter.initialize()
    local sector = Sector()
    riftInvasionBase = (sector:getEntitiesByScript("riftresearchcenter.lua") ~= nil)

    local x, y = sector:getCoordinates()
    local dist = length(vec2(x, y))
    self.dist = dist

    self.GeneralStationChatter =
    {
        -- jibber jabber
        "Dock ${LN2} is clear."%_t,
        "Dock ${LN2} is not clear."%_t,
        "${R}: Docking permission granted."%_t,
        "${R}: Docking permission denied."%_t,
        "Approach vector ${N2}/${N} confirmed."%_t,
        "We cannot allow just anybody to come aboard."%_t,
        "General reminder to the populace: open doors create unnecessary suction."%_t,
        "According to form ${R}, all taxes have been paid."%_t,
        "Requesting confirmation of received goods."%_t,
        "All incoming vessels: we welcome you in our sector and we hope for you that your intentions are peaceful."%_t,
        "Freighter ${N2}: this is ${R}. Please identify yourself."%_t,
        "Oh, back so early?"%_t,
        "Major Tom, please come in."%_t,
        "Please repeat the last statement."%_t,
        "${R}, what is your estimated time of arrival?"%_t,
        "${R}, you're free to dock. Choose whichever dock you please."%_t,
        "${R}, please send us position and approach angle."%_t,
        "Negative, we are still waiting for the delivery."%_t,
        "Hello ${R}, it's great to see you again!"%_t,
        "${R}? What are you guys doing here?"%_t,
        "This is the automated response system. Denied requests can be reviewed at any time by our algorithm."%_t,
        "Mandatory meeting of all station commanders tomorrow in room ${R}."%_t,
        "${R}, please come in."%_t,
        "No, that form is no longer up to date."%_t,
        "We ask all captains and pilots not to occupy docks any longer than necessary."%_t,

        -- hidden world bosses hints
        "Public Service Announcement: After losing contact to our latest chemical transport, we strongly advise not to open any sealed containers."%_t,
    }

    self.GeneralShipChatter =
    {
        -- jibber jabber
        "Hyperspace engine is a code ${N2}, shields are a code ${N}. Repairs not urgent, but welcome."%_t,
        "Requesting permission to dock."%_t,
        "Requesting flight vector."%_t,
        "We are now at vector ${N2}/${N}."%_t,
        "Negative, we are still waiting for our goods."%_t,
        "Asking for clearance."%_t,
        "So far, so good."%_t,
        "I have a bad feeling about this."%_t,
        "${R} entering flight vector."%_t,

        -- weapons
        "Personally, I don't like those fancy energy weapons. I'd take some good old chain guns over plasma any day."%_t,
        "... yeah, but shields are nearly useless against plasma weapons."%_t,
        "Railguns rip through a ship's hull like hot targo through a panem. /* Those are fantasy words */"%_t,

        -- general hints
        "One of these days I'll find one of those asteroids and claim it for myself."%_t,
        "No, no, no! With R-Mining Lasers, you get high yields of ores that you have to refine!"%_t,
        "Greedy bastard got himself killed going after the yellow blips on his galaxy map. Pirates everywhere."%_t,
        "Yes, really! If you don't shoot the Xsotan, they just move on! Saw it with my own eyes!"%_t,
        "The lightest material in the galaxy is Trinium. Trinium ships are a dream to steer."%_t,
        "They started building Cloning Pods with Xanion. Gives me the shivers."%_t,
        "If you ever come across one of those Behemoths, just pray that they won't detect you."%_t,
        "That last sector I visited was completely ravaged. Nothing left. Not even salvage. Creepy as hell if you ask me."%_t,

        -- hidden world bosses hints
        "I'm telling you, there's some old guard ship out there. That thing is defending some wrecks like they're still inhabited!"%_t,
        "The captain is completely crazy. Wants all kinds of ship parts for his collection, as if ships were something like rare butterflies."%_t,
        "Have you heard about the ship where everyone is asleep? The autopilot has taken control and put everyone into cryosleep!"%_t,
        "You have to come with us! The galaxy is going down! We're all meeting up to leave this galaxy aboard the \"Opportunity\"! If you're not on the list, they won't let you near it!"%_t,
        "These \"traders\" are even worse than pirates! One should simply equip a ship, search for their hideout and smoke them out once and for all! But our fleet can't even do that!"%_t,
        "Yesterday, Bob once again let off a story. About a motley ship full of crazy people who destroyed his last freighter because it was too gray."%_t,
        "... heard already? They've built a weapon of mass destruction that can instantly pulverize any ship! I saw them once! We barely got away with it!"%_t,
        "... heard about the missing prison ship? A friend told me that the prisoners had taken over the ship!"%_t,
        "I'm telling you: Fully automated! This bot will take down any wreck in no time. I just hope it can tell functional ships from wrecks."%_t,

        -- flair
        "Contact message: We have encountered increased pirate presence in the vicinity. Combat operation requested."%_t,
    }

    self.FreighterChatter =
    {
    }

    self.HostileShipChatter =
    {
        -- Move along
        "Hey you! You'd better move along!"%_t,
        "You need to leave."%_t,
        "Leave our territory."%_t,
        "Please leave our territory."%_t,
        "You should leave our territory."%_t,
        "You had better run along."%_t,
        "I think it would be better for you to move on."%_t,

        -- More formal move along
        "This is a friendly reminder: please leave our territory."%_t,
        "This is a friendly reminder: hostile parties are not welcome, and will find their stay less than rewarding."%_t,
        "You aren't welcome around these parts. We kindly ask you to vacate our territory."%_t,
        "According to our records, you're an enemy of our faction. Please leave our territory, otherwise we'll have to take actions against you."%_t,
        "We'd like to ask you to leave our territory. You're not welcome here."%_t,
        "Our records state that you have to leave our territory."%_t,
        "Our leadership has ordered us to open fire if you don't leave our territory."%_t,

        -- Threatening
        "We've got our eyes on you. One wrong step is all it takes."%_t,
        "We've got orders to shoot down any hostiles if they try something and right now you're on that list. Better move on."%_t,
        "There they are again. Should we shoot them down?"%_t,
        "I hope you're only passing through. Otherwise things could get ugly."%_t,
        "This is a friendly reminder: our faction has mercenaries on their payroll."%_t,
        "This is a friendly reminder: if you don't leave our territory, we will open fire."%_t,
        "This is an unfriendly reminder to leave. Now."%_t,
        "Warning: if you don't leave this territory, we will open fire."%_t,
        "Warning: mercenaries have been contacted."%_t,
        "Warning: your details have been forwarded to our mercenary squad."%_t,
    }

    if getLanguage() == "en" then
        -- these don't have translation markers on purpose
        table.insert(self.HostileShipChatter, "Why are you even here? Just go somewhere else.")
        table.insert(self.HostileShipChatter, "Do anything even remotely suspicious and you'll be space debris in no time.")
        table.insert(self.HostileShipChatter, "For your information, we tolerate your existence just because we are too lazy to kill you.")
        table.insert(self.HostileShipChatter, "We should have built a hyperspace rift around this sector to keep people like you out.")
        table.insert(self.HostileShipChatter, "Alright guys, who invited THAT piece of scrap here?")
        table.insert(self.HostileShipChatter, "I wish there was a hyperspace rift around this sector to keep people like you out.")
        table.insert(self.HostileShipChatter, "We have our orders. Just leave peacefully and nothing will happen to you.")
        table.insert(self.HostileShipChatter, "We don't serve your kind here!")
        table.insert(self.HostileShipChatter, "Greetings and welcome to- Okay nevermind, it's just some stranger poking their ship in sectors where they don't belong.")
        table.insert(self.HostileShipChatter, "Hey, look sharp now. There is a suspicious ship right there.")

        -- these don't have translation markers on purpose
        table.insert(self.GeneralStationChatter, "Tractor beam capacity at ${N2}%.")
        table.insert(self.GeneralStationChatter, "Who thought it would be a good idea to fix the oxygen vent with duct tape?")
        table.insert(self.GeneralStationChatter, "Where do I sign up?")
        table.insert(self.GeneralStationChatter, "Due to crew shortage, all overtime will be mandatory and unpaid.")
        table.insert(self.GeneralStationChatter, "Station stabilizer fields working at ${N2}% efficiency.")
        table.insert(self.GeneralStationChatter, "Notice to all arriving ships: Dock ${L}-${N} is temporarily disabled for maintenance. Thank you for your patience.")
        table.insert(self.GeneralStationChatter, "Construction of section ${N2} is now complete.")
        table.insert(self.GeneralStationChatter, "So, do you think any of it is true? Multiverse theory?")
        table.insert(self.GeneralStationChatter, "Medical section announcement: Remember to get up from your chair every now and then and take breaks between long gaming sessions.")
        table.insert(self.GeneralStationChatter, "Due to maintenance in corridor ${N2}, all personnel on their way to section ${LN3} should take elevator ${R} instead of ${LN3}.")
        table.insert(self.GeneralStationChatter, "I heard a rumor from a traveling merchant that she found a sector with asteroids placed in really weird formations.")

        -- these don't have translation markers on purpose
        table.insert(self.GeneralShipChatter, "I found this really beautiful sector just a few jumps away. The view was breathtaking.")
        table.insert(self.GeneralShipChatter, "I wish I could land on planets but my ship is too large for atmospheric entry.")
        table.insert(self.GeneralShipChatter, "You ever get the odd feeling that we're just floating around, not even in control of ourselves? Just me? Alright.")
        table.insert(self.GeneralShipChatter, "So, do you come here often?")
        table.insert(self.GeneralShipChatter, "My cousin's out fighting pirates, and what do I get? Guard duty.")
        table.insert(self.GeneralShipChatter, "Transponder signal verified. Continued existence permitted.")
        table.insert(self.GeneralShipChatter, "Flight calculations complete. Initiating automatic flight procedure.")
        table.insert(self.GeneralShipChatter, "Entering rotation cycle ${N2}. All systems nominal.")
        table.insert(self.GeneralShipChatter, "Even after all these years, I still can't fly a spaceship properly.")
        table.insert(self.GeneralShipChatter, "I got ambushed by pirates last week and got miraculously saved by some adventurer who was on their way towards the center of the galaxy.")
        table.insert(self.GeneralShipChatter, "False alarm. For a second I thought that asteroid was a pirate ship.")
        table.insert(self.GeneralShipChatter, "Sometimes you'll mine a rock that looks normal, and you'll find a fantastic stash of minerals inside!")

        -- these don't have translation markers on purpose
        table.insert(self.FreighterChatter, "I sure hope our cargo will fetch a good price.")
        table.insert(self.FreighterChatter, "I think I left my wallet back at the Equipment Dock.")

        -- we don't want these too often to not seem as repetitive
        if random():test(0.25) then
            table.insert(self.GeneralStationChatter, "Attention to all crew members: Get your free plushie alpaca from deck ${N2}.")
            table.insert(self.GeneralStationChatter, "Don't you DARE hit that red button!")

            table.insert(self.GeneralShipChatter, "Whose idea was it to get all these alpacas on board?")
            table.insert(self.GeneralShipChatter, "I am very happy with my job of saying random things to all passers-by while someone else flies the ship.")
            table.insert(self.GeneralShipChatter, "Man, I could really go for a vacation to Pillars of Debauchery ${N}...")
            table.insert(self.GeneralShipChatter, "Roses are red, violets are blue. I'm stuck in outer space, and so are you.")
            table.insert(self.GeneralShipChatter, "There's a bar in sector ${N3}:${N2} that has really good beer, and really cute.... Oh, hi Captain, didn't see you there. ")
            table.insert(self.GeneralShipChatter, "I watched him tear apart those pirates with salvaging turrets. Ripped their ships to shreds. That's what I call savage salvage.")

            table.insert(self.FreighterChatter, "This isn't Echoes of Damnation Alpha! Damned route calculation!")
            table.insert(self.FreighterChatter, "I hope they don't scan us... Wait! Who left the comm open?!")
        end
    end


    self.XsotanSwarmChatter = {
    {
        -- xsotanSwarmOngoing
        "There are too many!"%_t,
        "SOS! We're being overrun! Requesting immediate backup!"%_t,
        "When will it stop? Please make it stop!"%_t,
        "Bloody Xsotan. We'll show you how to stand fast!"%_t,
        "We won't lose! Stay strong!"%_t,
        "Why Boxelware, WHY!?"%_t,
        "I think this qualifies as the worst day of my life."%_t,
        "This sector will burn!"%_t,
        "Empty all magazines! Fire! Fire! Fire!"%_t,
    },
    {
        -- xsotanSwarmSuccess
        "Let's hope this swarm never comes back!"%_t,
        "We showed them damn Xsotan! Woohoo!"%_t,
        "Did those Xsotan really think they could win?!"%_t
    },
    {
        -- xsotanSwarmFail
        "Have we really lost? What now?"%_t,
        "We hoped to defeat the Xsotan plague once and for all. Guess it wasn't meant to be."%_t
    },
    {
        -- xsotanSwarmForeshadow
        "The Xsotan swarm was so damn strong. Let's hope this doesn't happen again!"%_t,
        "It's so good that we defeated the Xsotan swarm. Who knows what would have happened otherwise."%_t,
        "A lot of Xsotan appeared on our radars... are they regrouping?"%_t,
    }
    }

    local x, y = Sector():getCoordinates()
    local dist = length(vec2(x, y))

    if dist > 350 and dist < 430 then
        -- swoks
        table.insert(self.GeneralShipChatter, "Yes, Swoks was his name. I heard he ambushes anyone who is looking for new Titanium asteroid fields."%_t)
        table.insert(self.GeneralShipChatter, "Don't fly around outside the civilized sectors, or Swoks will come for you."%_t)
        table.insert(self.GeneralShipChatter, "Have you heard of this pirate boss, too?"%_t)
        table.insert(self.GeneralShipChatter, "Oh no, not here. I won't take even a single jump outside the civilized sectors."%_t)
        table.insert(self.GeneralShipChatter, "You should stay on the gate routes. There is increased pirate activity in the unexplored and empty sectors."%_t)

        table.insert(self.GeneralShipChatter, "Yes, around here. He appears when you do ten consecutive jumps into empty sectors."%_t)
        table.insert(self.GeneralShipChatter, "There's a myth around here: after ten consecutive jumps through empty sectors, Swoks will come for you."%_t)
        table.insert(self.GeneralShipChatter, "Personally, I don't believe it, but they say that after at least ten consecutive jumps through empty sectors, Swoks will come for you."%_t)
        table.insert(self.GeneralShipChatter, "... don't ask ME how he does it! All I know is, that after ten jumps into empty sectors, he'll come for you."%_t)

    end

    if dist > 240 and dist < 340 then
        -- the AI
        table.insert(self.GeneralShipChatter, "When you venture off into the unknown around here, you can find old war machines."%_t)
        table.insert(self.GeneralShipChatter, "Don't trail off into the unknown. There is some unknown terror around here."%_t)
        table.insert(self.GeneralShipChatter, "Oh no, not here. I won't take even a single jump outside the civilized sectors."%_t)
        table.insert(self.GeneralShipChatter, "I've heard it's an old AI, programmed to fight the Xsotan."%_t)
        table.insert(self.GeneralShipChatter, "It's harmless. Just don't attack it and don't be in the same sector when there are Xsotan."%_t)
        table.insert(self.GeneralShipChatter, "I've seen it once. It's huge and green and terrifying, with tons of plasma cannons."%_t)

        table.insert(self.GeneralShipChatter, "Yes, it tracks you when you jump through no-man's space. Ten jumps or more and you're guaranteed to meet it."%_t)
        table.insert(self.GeneralShipChatter, "Do you actually believe in this myth? How would the number of jumps into empty sectors influence you meeting a monster?"%_t)
        table.insert(self.GeneralShipChatter, "... and it's always watching. It tracks your jumps. Ten or more and it'll come for you."%_t)
    end

    if dist > 150 and dist < 240 then
        -- energy lab
        table.insert(self.GeneralShipChatter, "You can find those satellites in the yellow-blip sectors around here."%_t)
        table.insert(self.GeneralShipChatter, "There are plenty of those research satellites around here, in the non-civilized sectors."%_t)
        table.insert(self.GeneralShipChatter, "My buddy tried to salvage some of those yellow-blip satellites a few days back. Haven't heard from him since."%_t)
        table.insert(self.GeneralShipChatter, "Those new weapons sound like a threat. Are you sure they can't penetrate stone?"%_t)
        table.insert(self.GeneralShipChatter, "Stone can help you defend even against the strongest lightning weapons."%_t)
        table.insert(self.GeneralShipChatter, "They lost contact with their scouts. All they registered was an intense energy signature."%_t)
    end

    if dist > 350 then
        table.insert(self.GeneralShipChatter, "Yes, you can build shield generators out of Naonite! I have to find some!"%_t)
        table.insert(self.GeneralShipChatter, "Naonite, that green metal. Lets you build shield generators. Won't protect against collisions though."%_t)
        table.insert(self.GeneralShipChatter, "I know there's plenty of Iron floating around, but you should really look for Titanium to build your ship."%_t)
        table.insert(self.GeneralShipChatter, "I equipped a buddy's ship with Titanium Integrity Generators. Now it can take quite a few more hits before it breaks apart."%_t)
        table.insert(self.GeneralShipChatter, "I'll start looking for Naonite soon. I really need shield generators."%_t)

    end

    if dist > 330 then
        table.insert(self.GeneralShipChatter, "Best ship building material around here? Titanium. So much lighter than both Naonite and Iron."%_t)
        table.insert(self.GeneralShipChatter, "What? It's your own fault that you don't build ships out of Titanium, it's 42% lighter than Iron!"%_t)
    end

    --chatter only outside the barrier
    if dist > Balancing_GetBlockRingMax() then
        -- swoks
        table.insert(self.GeneralShipChatter, "I heard that in the Iron and Titanium regions, there is this pirate leader Swoks who ambushes anyone who explores the non-civilized sectors."%_t)
        table.insert(self.GeneralShipChatter, "The pirate infestation in the Iron and Titanium regions just doesn't end. As if their leader had doppelgangers."%_t)
        table.insert(self.GeneralShipChatter, "Have you heard of this pirate boss in the Iron and Titanium regions, too?"%_t)
        table.insert(self.GeneralShipChatter, "Don't go exploring in the Iron and Titanium reaches, or you'll be killed by Swoks."%_t)
        table.insert(self.GeneralShipChatter, "Don't fly around outside the civilized sectors in the Iron and Titanium reaches, or Swoks will come for you."%_t)

        -- the 4
        table.insert(self.GeneralShipChatter, "Have you heard of this Brotherhood? Apparently they're looking for Xsotan Artifacts near the Barrier."%_t)
        table.insert(self.GeneralShipChatter, "My colleague found a Xsotan artifact once. He took it to the Brotherhood. Haven't heard from him since."%_t)
        table.insert(self.GeneralShipChatter, "When I find one of those Xsotan artifacts, I'll take it to the Brotherhood and get rich."%_t)
        table.insert(self.GeneralShipChatter, "The Brotherhood pays anyone who brings them Xsotan artifacts good money."%_t)

        -- exodus
        table.insert(self.GeneralShipChatter, "... I kid you not! Some kind of beacon that always repeats the same message."%_t)
        table.insert(self.GeneralShipChatter, "I don't know how they are activated, but apparently those old gates take you far away."%_t)
        table.insert(self.GeneralShipChatter, "My nephew's brother in law's friend told me about this mysterious gate network."%_t)
        table.insert(self.GeneralShipChatter, "... In order to activate those gates, you need Xsotan artifacts."%_t)
        table.insert(self.GeneralShipChatter, "... beacons that always repeat the same message. I found one in an asteroid field."%_t)

        -- research artifact
        table.insert(self.GeneralShipChatter, "Apparently the AI of Research Stations combines legendary-tier subsystems into something new and strange."%_t)
        table.insert(self.GeneralShipChatter, "Some researchers of my wife's Research Station combined legendary-tier subsystems into something new."%_t)
        table.insert(self.GeneralShipChatter, "... and the three legendary-tier subsystems turned into something weird. An artifact with two scratches on it."%_t)

        if getLanguage() == "en" then
            table.insert(self.GeneralShipChatter, "... transporting a strange Xsotan artifact and said he'd take it through some empty sectors in the Naonite Belt just to be safe. Never saw him again.")
        end
    end

    --chatter only inside the barrier
    if dist < Balancing_GetBlockRingMax() then
        -- xsotan swarm
        table.insert(self.GeneralShipChatter,"Remember the great Xsotan Attack? Hundreds of Xsotan swarming all over.\nI wonder what made them stop."%_t)


        -- corrupted AI
        table.insert(self.GeneralShipChatter,"... and they turned it against us... without knowing our language."%_t)
        table.insert(self.GeneralShipChatter,"A lot of the parts that had broken off started flying in our direction and tried to ram us."%_t)

        -- laserboss
        table.insert(self.GeneralShipChatter,"The whole ship...destroyed in seconds."%_t)
        table.insert(self.GeneralShipChatter,"It was protected by some new technology, had something to do with the asteroids around it."%_t)
        table.insert(self.GeneralShipChatter,"We evaded its big laser, but there was no damaging it!"%_t)

    end

    local generalChatter =
    {
        -- jibber jabber
        "Radio test: Can you hear me? Frank? Hello?"%_t,
        "Checking radio... Changing frequency to ${R}."%_t,
        "Looks like the comm is still on."%_t,

        -- general flair
        "The Xsotan are slowly becoming a threat."%_t,
        "I heard that inside the Barrier, the Xsotan eat up entire planets."%_t,
    }

    RadioChatter.addStationChatter(generalChatter)
    RadioChatter.addShipChatter(generalChatter)
end

function RadioChatter.getRiftInvasionBaseChatter()
    local riftChatter =
    {
        -- lines for civil ships
        "Come with me into the rifts. Yes it's dangerous, but do you know how many resources you can gather there with R-Mining Lasers? Huge amounts!"%_t,
        "...The quantum fluctuations of the rift subspace distortion have an adverse effect on purifying ores. It simply is not possible."%_t,
        "...Don't bother with purifiying mining lasers in rifts, R-Mining is the way to go!"%_t,
    }

    return riftChatter
end

function RadioChatter.addStationChatter(lines)
    for _, line in pairs(lines) do
        table.insert(self.GeneralStationChatter, line)
    end
end

function RadioChatter.addShipChatter(lines)
    for _, line in pairs(lines) do
        table.insert(self.GeneralShipChatter, line)
    end
end

function RadioChatter.addHostileShipChatter(lines)
    for _, line in pairs(lines) do
        table.insert(self.HostileShipChatter, line)
    end
end

function RadioChatter.addSpecificLines(id, lines)
    local entity = Entity(id)
    if entity then
        entity:setValue("npc_chatter", true)
    end

    local id_str = tostring(id)

    local tbl = self.specificLines[id_str]
    if not tbl then
        tbl = {}
        self.specificLines[id_str] = tbl
    end

    for _, line in pairs(lines) do
        table.insert(tbl, line)
    end
end

function RadioChatter.updateClient()
    self.which = self.which or random():getInt(1, 2)

    if self.which == 1 then
        self.updateStationChatter()
        self.which = 2
    else
        self.updateShipChatter()
        self.which = 1
    end
end

function RadioChatter.selectLine(entity, general)
    local specific = self.specificLines[entity.id.string]

    local line = ""
    if specific and random():test(0.35) then
        line = randomEntry(random(), specific)
    else
        line = randomEntry(random(), general)
    end

    return self.fillInIdentifiers(line)
end

function RadioChatter.getChatterCandidates(type)

    local firstSelection = {}
    if type == EntityType.Station then
        firstSelection = {Sector():getEntitiesByType(EntityType.Station)}
    else
        firstSelection = {Sector():getEntitiesByScriptValue("npc_chatter")}
    end

    if #firstSelection == 0 then return {} end

    local player = Player()
    local now = appTime()

    local candidates = {}
    for _, candidate in pairs(firstSelection) do
        if candidate:getValue("is_xsotan") then goto continue end
        if candidate:getValue("no_chatter") then goto continue end
        if candidate.type ~= type then goto continue end
        if player and player:getRelationStatus(candidate.factionIndex) == RelationStatus.War then goto continue end

        local time = self.entityTimes[candidate.id.string]
        if time and now - time < self.EntityTimeBetweenSpeechBubbles then goto continue end

        local ai = ShipAI(candidate)
        if ai and (ai.isBusy or ai.isAttackingSomething) then goto continue end

        table.insert(candidates, candidate)

        ::continue::
    end

    return candidates
end

function RadioChatter.updateStationChatter()
    local stations = RadioChatter.getChatterCandidates(EntityType.Station)
    if #stations == 0 then return end

    local station = randomEntry(random(), stations)
    if station.hasPilot then return end -- don't show chatter if player is flying this ship

    -- if relations are hostile, player shouldn't be able to listen in on chatter
    if Player():getRelations(station.factionIndex) < -80000 then return end

    self.entityTimes[station.id.string] = appTime()

    -- check for xsotan event
    RadioChatter.showXsotanSwarmChatter()

    if xsotanChatter and self.dist < 150 and random():test(0.2) then
        displaySpeechBubble(station, randomEntry(random(), self.XsotanSwarmChatter[xsotanChatter]))
    else
        if random():test(0.85) then
            displaySpeechBubble(station, self.selectLine(station, self.GeneralStationChatter))
        else
            invokeServerFunction("displayStateFormSpecificChatter", station)
        end
    end
end

function RadioChatter.updateShipChatter()
    local ships = RadioChatter.getChatterCandidates(EntityType.Ship)
    if #ships == 0 then return end

    local ship = randomEntry(random(), ships)
    if ship.hasPilot then return end -- don't show chatter if player is flying this ship
    self.entityTimes[ship.id.string] = appTime()

    -- too hostile for normal chatter
    if Player():getRelations(ship.factionIndex) < -80000 then
        displaySpeechBubble(ship, self.selectLine(ship, self.HostileShipChatter))
        return
    end

    -- check for xsotan event
    RadioChatter.showXsotanSwarmChatter()
    if xsotanChatter and self.dist < 150 and random():test(0.2) then
        displaySpeechBubble(ship, randomEntry(random(), self.XsotanSwarmChatter[xsotanChatter]))
        return
    end

    -- rift chatter
    if riftInvasionBase and random():test(0.10) then
        local riftLines = self:getRiftInvasionBaseChatter()
        displaySpeechBubble(ship, self.selectLine(ship, riftLines))
        return
    end

    -- general chatter
    local lines = self.GeneralShipChatter
    if ship:getValue("is_trader") or ship:getValue("is_freighter") then
        if #self.FreighterChatter > 0 and random():test(0.5) then
            lines = self.FreighterChatter
        end
    end

    if random():test(0.85) then
        displaySpeechBubble(ship, self.selectLine(ship, lines))
    else
        invokeServerFunction("displayStateFormSpecificChatter", ship)
    end
end

function RadioChatter.generate(chars, num)
    local result = ""

    for i = 1, num do
        local c = random():getInt(1, #chars)
        result = result .. chars:sub(c, c)
    end

    return result
end

function RadioChatter.fillInIdentifiers(str)

    local numbers = "0123456789"
    local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    local args = {}
    args.L = self.generate(letters, 1)
    args.L2 = self.generate(letters, 2)
    args.L3 = self.generate(letters, 3)
    args.L4 = self.generate(letters, 4)

    args.N = self.generate(numbers, 1)
    args.N2 = self.generate(numbers, 2)
    args.N3 = self.generate(numbers, 3)
    args.N4 = self.generate(numbers, 4)

    args.LN = self.generate(letters, 1) .. "-" .. self.generate(numbers, 1)
    args.LN2 = self.generate(letters, 1) .. "-" .. self.generate(numbers, 2)
    args.LN3 = self.generate(letters, 1) .. "-" .. self.generate(numbers, 3)
    args.L2N = self.generate(letters, 2) .. "-" .. self.generate(numbers, 1)
    args.L2N2 = self.generate(letters, 2) .. "-" .. self.generate(numbers, 2)
    args.L2N3 = self.generate(letters, 2) .. "-" .. self.generate(numbers, 3)

    args.player = Player().name

    if random():getInt(1, 2) == 1 then
        args.R = self.generate(letters, random():getInt(1,2)) .. "-" .. self.generate(numbers, random():getInt(1,2))
    else
        args.R = self.generate(numbers, random():getInt(1,2)) .. "-" .. self.generate(letters, random():getInt(1,2))
    end

    return str % args
end

function RadioChatter.displayChatter(entity, line)
    -- called from server with unresolved arguments for tranlsation to work -> fill in identifiers here
    displaySpeechBubble(entity, self.fillInIdentifiers(line % _t))
end

end

function RadioChatter.displayStateFormSpecificChatter(entity)
    if not valid(entity) then return end

    local faction = Faction(entity.factionIndex)
    if not valid(faction) then return end
    if not faction.isAIFaction then return end

    local stateForm = faction:getValue("state_form_type") or FactionStateFormType.Vanilla

    local chatterLinesByStateForm = {}

    -- vanilla
    chatterLinesByStateForm[FactionStateFormType.Vanilla] =
    {
        -- no defining traits
    }
    chatterLinesByStateForm[FactionStateFormType.Organization] =
    {
        "Fight for equality for everyone!"%_t,
        "Worker's lives haven't improved for years. It's time to do something about it!"%_t,
        "This job at the factory has been killing people forever!"%_t,
        "I won't stop fighting for my rights!"%_t,
    }

    -- traditional
    chatterLinesByStateForm[FactionStateFormType.Emirate] =
    {
        "Even a prince has to follow traditions."%_t,
        "Remember young ones, listen to your grandfathers! They know best."%_t,
        "Galactic Sun elects the man of your dreams: generous and brave, with a hint of danger!"%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Kingdom] =
    {
        "Honor is one of the most important qualities of a person."%_t,
        "Whatever you do, do it for king and glory!"%_t,
        "Monarchies may be a bit old-school. But they bring peace and stability!"%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Empire] =
    {
        "Tea anyone? Quality assured by the Empress herself!"%_t,
        "Join us or be eradicated."%_t,
        "Our army is the best."%_t,
    }

    -- independent
    chatterLinesByStateForm[FactionStateFormType.States] =
    {
        "Be generous, be honorable and peace will follow you!"%_t,
        "Stand up for your rights, but trust in the government."%_t,
        "Honor our forefathers, for they made this life possible!"%_t,
        "It's everyone's duty to stand up for our great nation!"%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Planets] =
    {
        "The galaxy is vast and mostly empty. Stay safe!"%_t,
        "They say there was once a blue planet named Earth."%_t,
        "Last year ${N} new planets have enriched our community by joining in."%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Republic] =
    {
        "The galaxy is vast and full of pirates. Better prepare!"%_t,
        "You don't have to get too close, if you have long-range scanners."%_t,
        "No, being careful has never been a problem."%_t,
        "I have a bad feeling about this."%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Dominion] =
    {
        "I say: Shoot first, ask later."%_t,
        "I love my guns, I take one everywhere. Have one right under my pillow, too."%_t,
        "Have you heard? They're finally increasing our military budget."%_t,
        "There is no threat that would be a match for us."%_t,
        "Surveys indicate a happiness index of 9${N}%. That means we can still do better."%_t,
        "The happiness index increased by 4${N}%, after public executions of wrong-thinkers resumed."%_t,
    }

    -- militaristic
    chatterLinesByStateForm[FactionStateFormType.Army] =
    {
        "I'm doing My part!"%_t,
        "Honor our veterans. They risked their lives for us!"%_t,
        "Join the army today and get a free pen to sign your contract!"%_t,
        "Rations in section ${LN2} will have to be cut."%_t,
        "${N2} dishonorable deserters have been eliminated over the past week."%_t,
        "Recruitment is at an all-time high."%_t,
        "We have the biggest military budget per capita of the galaxy!"%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Clan] =
    {
        "We are the best here!"%_t,
        "Our community ist the best all over the galaxy."%_t,
        "Nothing compares to our big family!"%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Buccaneers] =
    {
        "Give me a good opportunity and I'll immediately get there."%_t,
        "What's wrong with taking an opportunity if it offers itself?"%_t,
        "... so I took it. A dead guy doesn't need it anyway, does he?"%_t,
    }

    -- religious
    chatterLinesByStateForm[FactionStateFormType.Church] =
    {
        "Unfortunately today's mass is cancelled."%_t,
        "Today, ${N}:00 o'clock: reading from psalm ${LN2}"%_t,
        "Faith offers strength. Always."%_t,
        "Find yourself again in prayer."%_t,
        "Confession will be postponed by ${N} days."%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Followers] =
    {
        "The Great One will speak live at the ceremony."%_t,
        "Tune in to channel ${N} to listen to the sacred scrolls."%_t,
        "Follow the prophecy, find to the light."%_t,
        "The prophecy has never and will never fail us."%_t,
        "The prophecy lives through us all."%_t,
    }

    -- corporate
    chatterLinesByStateForm[FactionStateFormType.Corporation] =
    {
        "New work opportunities! Don’t let bots take you down."%_t,
        "${N2} new shipments at Dock ${L}."%_t,
        "We have ${N} open positions in sector ${LN3}."%_t,
        "Department ${LN3}'s workforce has lowered by 1${N}%."%_t,
        "Department ${LN3}'s workforce has increased by 1${N}%."%_t,
        "Stocks have increased by 1${N}%."%_t,
        "Today, I was promoted to consumer."%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Syndicate] =
    {
        "We'd like to remind outsiders that all our activities are 100% legal."%_t,
        "Having trouble staying on the straight path? We don’t, either!"%_t,
        "So there's this old, completely legal ship that needs taking care of, and ... oh, wrong channel."%_t,
        "A friend of mine has a special delivery that's looking for a new owner."%_t,
        "Yes, absolutely. Yes, ${N2}% legal."%_t,
        "My friend asked me to join a union. I refused, 'cause I don't want to be fired."%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Guild] =
    {
        "Productivity is at 9${N}%."%_t,
        "${N} new shipments today, ${N2} tomorrow."%_t,
        "${N} new businesses have joined the Guild over the past two weeks."%_t,
        "Do what you love, and get a fair wage for it."%_t,
        "I've been waiting for these shipments forever. Where are they!?"%_t,
        "Containers of section ${LN2} have been moved to section ${L2}."%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Conglomerate] =
    {
        "Gotta up those numbers."%_t,
        "Find what you love. Then buy it. Then sell it for a profit."%_t,
        "I think I'll sell my vacation days for that 0.${N2}% profit."%_t,
        "Use bots, not workers. They don't need sleep, or wages, or food. It's a win-win-win."%_t,
        "The Conglomerate has bought ${N2} new businesses so far this week."%_t,
    }

    -- alliance
    chatterLinesByStateForm[FactionStateFormType.Federation] =
    {
        "Research, exploration and curiosity is what drives us."%_t,
        "The Federation stands for integrity, unity and honor."%_t,
        "Ugh, that stupid replicator on deck ${L} is broken again."%_t,
        "I don't think you should wear that red shirt on your mission."%_t,
        "Technological progress, so that we can improve a bit every day."%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Alliance] =
    {
        "Those who join us will receive protection."%_t,
        "Together, we're stronger."%_t,
        "Stand together in unison."%_t,
        "The Alliance is the shield we use to defend ourselves."%_t,
        "The Alliance has been joined by ${N3} new individuals today."%_t,
        "Fight the Horde! For the Alliance!"%_t,
    }
    chatterLinesByStateForm[FactionStateFormType.Commonwealth] =
    {
        "The Commonwealth stands for prosperity, liberty and wealth."%_t,
        "Everyone has to do their part here, but it's all worth it."%_t,
        "Sacrifices have to be made to create a better tomorrow."%_t,
        "For the greater good of the Commonwealth."%_t,
        "Update: Cameras in personal apartments on deck ${L} are now operational for your safety."%_t,
        "It's perfectly fine that these holo recorders are everywhere, after all, it's for the safety of all of us."%_t,
    }

    -- sect
    chatterLinesByStateForm[FactionStateFormType.Collective] =
    {
        "Are you willing to give yourself to the light? Join us."%_t,
        "Great pleasure awaits those that follow the path of union."%_t,
        "One of us."%_t,
        "Joining the Collective isn't mandatory, but recommended."%_t,
        "The Collective has welcomed ${N3} happy new individuals yesterday."%_t,
        "There is no discord here."%_t,
    }

    local line = randomEntry(random(), chatterLinesByStateForm[stateForm])
    if line then
        invokeClientFunction(Player(callingPlayer), "displayChatter", entity, line)
    end
end
callable(RadioChatter, "displayStateFormSpecificChatter")

function RadioChatter.showXsotanSwarmChatter()
    if onClient() then
        if self.dist < 150 then
            invokeServerFunction("showXsotanSwarmChatter")
        end
        return
    end

    local server = Server()
    if server:getValue("xsotan_swarm_active") then
        xsotanChatter = 1
    else
        local swarmSuccess = server:getValue("xsotan_swarm_success")
        local swarmTime = server:getValue("xsotan_swarm_time")
        if swarmTime and swarmTime < (15 * 60) then
            xsotanChatter = 4
        elseif swarmSuccess and swarmTime and swarmTime > (115 * 60) then
            xsotanChatter = 2
        elseif swarmSuccess == false and swarmTime and swarmTime > (115 * 60) then
            xsotanChatter = 3
        else
            xsotanChatter = nil
        end
    end

    RadioChatter.sync()
end
callable(RadioChatter, "showXsotanSwarmChatter")

function RadioChatter.sync(data_in)
    if onServer() then
        invokeClientFunction(Player(callingPlayer), "sync", xsotanChatter)
        return
    end

    if onClient() then
        if data_in then
            xsotanChatter = data_in
        else
            invokeServerFunction("sync")
        end
    end
end
callable(RadioChatter, "sync")

