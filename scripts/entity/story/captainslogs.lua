package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")

function initialize()

end

function interactionPossible(player, option)
    local craft = Player().craft
    if craft == nil then return false end
    local dist = craft:getNearestDistance(Entity())
    if dist < 40.0 then
        return true
    end
    return false, "You're not close enough to search the object."%_t
end

function initUI()
    ScriptUI():registerInteraction("Search for Information"%_t, "onRead")
end

function onRead(entityIndex)
    if entityIndex == nil then
        entityIndex = Entity().index
    end
    if onServer() then return end
    ScriptUI(entityIndex):showDialog(makeDialog())
end

function makeDialog()
    local logTexts = {}

    local d0_CaptainsLog1 = {}
    d0_CaptainsLog1.text = "Captain's Log - Reconnaissance Ship 1331\nDay 236\n"%_t
    .."The forgotten Sectors near the Barrier seem similar to the outer sectors at first glance, but actually they are very different.\n\n"%_t
    .."There are huge numbers of Xsotan warships everywhere that seem to be following us. "%_t
    .."They do not attack us (yet), but they never let us out of their sight and circle around us. \n\n"%_t
    .."All attempts to contact them have been futile, no matter what means of communication we have tried. "%_t
    .."I worry that the crew won't be able to take the constant pressure anymore.\n\n"%_t
    .."Captain's Log - Reconnaissance Ship 1331\nDay 238\n"%_t
    .."It has happened. One of our ships has fired at one of the Xsotan crafts. \n\n"%_t
    .."This has started a battle. We are fighting with all our might, but the Xsotan have called for reinforcements and we are hopelessly outnumbered. "%_t
    .."I can't count all the systems that have failed and our air tanks were hit. \n\n"%_t
    .."We have to evacuate and hope that at least a few can survive in the escape capsules. "%_t
    .."I have to leave now. I don't know if any of us will survive... Captain over and out... CHRRR..."%_t
    table.insert(logTexts, d0_CaptainsLog1)

    local d1_CaptainsLog2 = {}
    d1_CaptainsLog2.text = "Captain's Log - Research Mission 6374\nDay 365\n"%_t
    .."It has been three days since we started fighting the parasite we picked up on planet OF863. \n\n"%_t
    .."The entire crew is cursing the scientist that made us start this horrible mission. "%_t
    .."He claimed it was absolutely important that we take this strange piece of metal on board. \n\n"%_t
    .."But it was already infected and now the parasite is corroding every mineral we have on our ship. There is nothing we can do to stop it!\n\n"%_t
    .."Captain's Log - Research Mission 6374\nDay 368\n"%_t
    .."The parasite has now reached every part of our ship. \n\n"%_t
    .."There is no hope of rescue. Nobody has answered our desperate transmissions. "%_t
    .."The crew is slowly going crazy, we have no more food, no more room to stay... we won't be able to hold on much longer... there is only one option left...\n\n"%_t
    .."end of log. no more entries."%_t
    table.insert(logTexts, d1_CaptainsLog2)

    local d2_CaptainsLog3 = {}
    d2_CaptainsLog3.text = "Captain's Log - Research Expedition 8752\nDay 593\n"%_t
    .."Yesterday's Xsotan attack caused more damage than we had initially assumed. \n\n"%_t
    .."We thought we had only lost a minor amount of water, but it turned out that we had also lost some of our generators. "%_t
    .."We were continuously losing energy and we didn't even know about it because the wires connecting the energy gauge were also hit. \n\n"%_t
    .."Not knowing how fatal that decision would prove to be, we jumped a few sectors away from where we were attacked. "%_t
    .."We didn't get very far. We may have managed to lose the Xsotan, but now we are stuck in the middle of nowhere. \n\n"%_t
    .."We are continuously sending out distress calls, but nobody is answering. But we will not give up hope!\n\n"%_t
    .."Captain's Log - Research Expedition 8752\nDay 601\n"%_t
    .."We have tried to use the remaining energy wisely to get closer to anyone who might be able to hear our distress calls, \n\n"%_t
    .."but we have failed. Now we are drifting through empty space and waiting for the day that we won't have any more food, water and oxygen. "%_t
    .."It can't be long now. Several of our crew have asked to be put into a cryrogenic sleep, so they won't know when the end has come. \n\n"%_t
    .."Morale is very low. I secretly hope that there will be another Xsotan attack so all of this will end quickly."%_t
    table.insert(logTexts, d2_CaptainsLog3)

    local d3_CaptainsLog4 = {}
    d3_CaptainsLog4.text = "My dearest Lucile,\n"%_t
    .."The space cruise I have booked has proven to be incredibly relaxing. "%_t
    .."We are traveling through the sectors, seeing incredible sights and are enjoying amazing food. \n\n"%_t
    .."The best thing about this voyage, however, is not that we are entertained by extravagant shows or that we are staying in very comfortable rooms, "%_t
    .."but a young man named Jack. He is making my stay on the Cinatit the best time of my life! \n\n"%_t
    .."We are spending every waking minute together and he is the first man in my life that is making my heart beat faster.\n\n"%_t
    .."...\n\n"
    .."Lucile! I am afraid! I don't know what to do! Right after a hyperspace jump, our ship has struck a huge asteroid. "%_t
    .."There is a giant hole in one part of the ship and they say it might break apart at any moment. \n\n"%_t
    .."I am waiting to be evacuated, but there are rumors that there might not be enough escape capsules on board! \n\n"%_t
    .."Nobody expected such a big ship like the Cinatit to have an accident. And the worst part is: I can't find Jack! I'm all alone!"%_t
    table.insert(logTexts, d3_CaptainsLog4)

    local d4_CaptainsLog5 = {}
    d4_CaptainsLog5.text = "Captain's Log - Reconnaissance Expedition Nr.4172\n"%_t
    .."After a skirmish with a group of Xsotan ships, which we were able to win easily, we were able to enter a Xsotan craft for the first time. \n\n"%_t
    .."Our scientists have returned with surprising results. They believe that this ship was not meant to sustain life of any kind. "%_t
    .."Indeed, they say that no form of life has ever been on this vessel. There were no carcasses, no water, no breathable gases even. \n\n"%_t
    .."There was, however, a collection of strange apparatuses connected with wires and hoses. "%_t
    .."They were not only attached to each other but also to the ship itself. \n\n"%_t
    .."We have taken everything apart and are now transporting it to our home sector to conduct further research."%_t
    table.insert(logTexts, d4_CaptainsLog5)

    local d5_CaptainsLog6 = {}
    d5_CaptainsLog6.text = "Captain's Log - Research Mission Nr.032856\n"%_t
    .."Yesterday, a small Xsotan reconnaissance ship crashed into the hangar of one of our destroyers. \n\n"%_t
    .."At first, everybody was freaking out and we were discussing just blowing it up right inside our craft. "%_t
    .."But then it was decided that this was a unique opportunity to learn more about the Xsotan. \n\n"%_t
    .."We cut open the hull of the ship and entered it. "%_t
    .."It turned out to have been a large drone of some sort, since no life sustaining technologies could be found. \n\n"%_t
    .."But what was more interesting was the material most of the craft was constructed of. "%_t
    .."It was very light and seems to be ideal for storing energy. "%_t
    .."Our scientists decided to call it AVORION. \n\n"%_t
    .."Since nobody has ever seen anything like it before, it is assumed that this material only exists inside the Barrier. "%_t
    .."Maybe it is even the key to crossing the rifts?"%_t
    table.insert(logTexts, d5_CaptainsLog6)

    local d6_CaptainsLog7 = {}
    d6_CaptainsLog7.text = "Captain's Log - Campaign 7345\n"%_t
    .."We have followed the ships to the regions close to the Barrier that only Xsotan ever go to. \n\n"%_t
    .."Revenge will be ours! Those aliens will be paying for what they did to us in yesterday's battle! "%_t
    .."Nobody may dare attack our faction! Prepare for attack! ... \n\n"%_t
    .."What did I say? Those Xsotan have gotten what they deserved and more! "%_t
    .."They will now think twice to even get near our faction. \n\n"%_t
    .."My crew has fought bravely and with no mercy. Now the wrecks of the Xsotan will drift through empty space for all eternity."%_t
    table.insert(logTexts, d6_CaptainsLog7)

    local d7_CaptainsLog8 = {}
    d7_CaptainsLog8.text = "Captain's Log - Campaign 7635\n"%_t
    .."The pirates set up a trap! We had almost defeated them and they were retreating. "%_t
    .."Suddenly, many more pirate ships jumped into the sector. But we stood our ground! "%_t
    .."All of our ships fought bravely, and although we suffered many losses, victory was ours! "%_t
    .."After caring for our wounded, we began to trace where the pirates had come from. "%_t
    .."We jumped to their home sector and found their stations. Now those stations are ours and their workers work for us! "%_t
    .."Let that be a lesson for anybody who thinks they can attack our faction!"%_t
    table.insert(logTexts, d7_CaptainsLog8)

    local d8_CaptainsLog9 = {}
    d8_CaptainsLog9.text = "Captain's Log - Patrol 362815\n"%_t
    .."No special incidents. No sightings of Xsotan, pirates or enemy factions. \n\n"%_t
    .."The first mate has suggested to diverge from our usual route, he claims he has heard of troubles. "%_t
    .."We will change our course accordingly.\n\n"%_t
    .."... \n\n"
    .."IT WAS A TRAP! The first mate was working for the pirates! "%_t
    .."When we jumped into the sector, we were suddenly faced with a whole fleet of pirates.  \n\n"%_t
    .."We are trying to fight our way out of this, but it does look grim. Tell ... CHRRR ... that ... CHRRR ... "%_t
    table.insert(logTexts, d8_CaptainsLog9)

    local d9_CaptainsLog10 = {}
    d9_CaptainsLog10.text = "Captain's Log - Trading Vessel DUNFATTOORA\n"%_t
    .."A few days ago, we came across a wreckage. "%_t
    .."I wanted to just fly past it, but my first mate persuaded me to go take a look at it. \n\n"%_t
    .."From afar, it looked just like a regular freighter, but when we came closer we realized that it must have been a pirate ship. "%_t
    .."We entered it and immediately realized that all escape capsules were gone. "%_t
    .."Our mechanics took a look at the engine room and reported that the ship was in no state to fly. "%_t
    .."Not only was there no more energy but some of the wires had been fried also. \n\n"%_t
    .."Then we checked out the cargo bay. "%_t
    .."It was not only made completely of lead, but it was also full of cargo! "%_t
    .."Of course we took everything valuable on board and left the wreckage to float through space. \n\n"%_t
    .."Oh what a bad decision that was. "%_t
    .."We have been followed by pirates and smugglers ever since. "%_t
    .."One of the items we took must have had some sort of tracer on it. \n\n"%_t
    .."So far, we are doing a good job of evading our pursuers, and we only have to reach a civilized sector to be safe. "%_t
    table.insert(logTexts, d9_CaptainsLog10)

    local d10_CaptainsLog11 = {}
    d10_CaptainsLog11.text = "Captain's Log - Mining Craft GHANGIRSO\n"%_t
    .."Yesterday evening we jumped into a new sector. "%_t
    .."And we couldn't believe our eyes! \n"%_t
    .."There was a fresh asteroid field full of trinium asteroids. \n\n"%_t
    .."We could tell nobody had ever mined in it before, and we instantly set our mining lasers to it. "%_t
    .."We were all very excited because the resources from this field would mean that we could all take an extended vacation after we were done. \n\n"%_t
    .."But today, as we were just mining away, a ship of the Hunii faction appeared. \n"%_t
    .."We saw them hover at the edge of the asteroid field for a while, then they disappeared. \n\n"%_t
    .."We had meant to take all the trinium on board of the Ghangirso and not share it with anyone. "%_t
    .."But then we realized that we would rather share everything with people from our own faction than with the Hunii. \n\n"%_t
    .."We sent out a call, and not soon after, mining ships from our faction turned up, just about at the same time as more crafts of the Hunii appeared. "%_t
    .."Now it will come down to who can mine faster!"%_t
    table.insert(logTexts, d10_CaptainsLog11)

    local d11_CaptainsLog12 = {}
    d11_CaptainsLog12.text = "Captain's Log - Cruise Ship LOKERAD\n"%_t
    .."This morning something horrible has happened. \n"%_t
    .."We were cruising through an empty sector at slow speed. \n\n"%_t
    .."We were using some drones to recolor the outside of the ship while we were just ambling along. "%_t
    .."Suddenly, one of the drones sent a horrible message: \n\n"%_t
    .."It had run out of the color INFINITY HOT PINK!\n\n"%_t
    .."We checked all the stores on board, but there was nothing left. \n"%_t
    .."Now half of our ship is painted ETERNAL SKY BLUE and the other half pink. \n"%_t
    .."How are we supposed to show our faces in any civilized sector?"%_t
    table.insert(logTexts, d11_CaptainsLog12)

    local d12_CaptainsLog13 = {}
    d12_CaptainsLog13.text = "Captain's Log - Supply Ship S3079\n"%_t
    .."These are my thoughts about the new Type-X Model of generation 2998: \n"%_t
    .."Its design is the most pleasing of all models of the class. "%_t
    .."Streamlined, elegant and yet powerful. \n\n"%_t
    .."Flying it feels fantastic! "%_t
    .."It accelerates to 5500m/s in a few seconds, and because of the ingeniously placed thrusters it is as agile as a bird of prey. \n\n"%_t
    .."Perfect for navigating through asteroid fields. "%_t
    .."Brand new technology of generators and energy containers has been used and there is as much cargo bay as anyone might ever need. \n\n"%_t
    .."The Type-X can be ordered at select shipyards. "%_t
    .."They are offering exceptional service and will customize your ship as well!"%_t
    table.insert(logTexts, d12_CaptainsLog13)

    local d13_CaptainsLog14 = {}
    d13_CaptainsLog14.text = "Recording of 'Space Race 133'\n"%_t
    .."Welcome, welcome and welcome to this year's Space Race! \n"%_t
    .."Spectacular speed and strong ships! \n\n"%_t
    .."This year, the fastest ships and most daring pilots will fly an enormously dangerous route! \n"%_t
    .."Who will win? Who will survive? Who knows! \n\n"%_t
    .."Here they are: \n"%_t
    .."On position number one: Crantichan the Crazy! \n"%_t
    .."On position number two, come all the way from the other side of the galaxy: Promolo the Pretty. \n"%_t
    .."On position number three: Botum the Brave! \n"%_t
    .."On position number four, last years winner: Cluhna the Clever. \n\n"%_t
    .."And on position number five, the secret favorite of many here in the audience: Damjej the Daring! \n"%_t
    .."The racers are making their way to the starting line, only five more minutes to go..."%_t
    table.insert(logTexts, d13_CaptainsLog14)

    local d14_CaptainsLog15 = {}
    d14_CaptainsLog15.text = "Recording of 'Galactic Beauty Pageant 79'\n"%_t
    .."Hello and welcome to the Galactic Beauty Pageant for ships! \n"%_t
    .."The award will go to the most beautiful ship in the galaxy. "%_t
    .."The best ship builders and designers have given their all in the last couple of years to create the most amazing ship in the galaxy. \n\n"%_t
    .."But it is not beauty alone that counts, but also talents. \n"%_t
    .."The categories are Design, Features, Speed and Agility. \n\n"%_t
    .."The winner not only wins an amazing trophy and a sash for their ship but also 5500000 Credits. \n"%_t
    .."May the best ship win! "%_t
    table.insert(logTexts, d14_CaptainsLog15)

    local d15_CaptainsLog16 = {}
    d15_CaptainsLog16.text = "Captain's Log - The Secret Sector\n"%_t
    .."When I was little, my grandfather always told me about a mysterious wormhole near our home sector. "%_t
    .."It leads to a wonderful far off sector, populated by a peaceful species that have made their sector and their planet a perfect place to be. \n\n"%_t
    .."This distant place cannot be reached, as it only exists in my grandfather's stories, since the wormhole simply cannot be found. "%_t
    .."At least that is what I had always believed... \n\n"%_t
    .."One day, after I had already become a successful merchant, and I was just testing a new ship subsystem, a wormhole appeared right in front of me. "%_t
    .."Suddenly I was gripped by the desire for adventure and I flew right into it. \n\n"%_t
    .."On the other side I was greeted by the perfect species my grandfather had described to me. "%_t
    .."I don't know how much time I spent there. "%_t
    .."At first I thought I was never going to leave again, but over time, I realized that I was not happy anymore. \n\n"%_t
    .."If your environment is too perfect, you are too much aware of your own shortcomings. "%_t
    .."I returned to my previous life and I have not seen that wormhole since."%_t
    table.insert(logTexts, d15_CaptainsLog16)

    local d16_CaptainsLog17 = {}
    d16_CaptainsLog17.text = "Captain's Log - HLANSBBO\n"%_t
    .."I don't know what our intern was thinking, or if he was thinking at all, but he didn't close the sheep pen properly. "%_t
    .."Last night, all sheep escaped and are now running around all over the ship! \n\n"%_t
    .."Some have found the biosphere and wreaked havoc there, taking a bite out of every single plant it feels like. "%_t
    .."Others have managed to enter the engine room and not only pulled on some wires but also pressed buttons! \n\n"%_t
    .."This intern is useless, he has always made mistakes but now he has gone too far. We are going to fire him!"%_t
    table.insert(logTexts, d16_CaptainsLog17)

    local d17_CaptainsLog18 = {}
    d17_CaptainsLog18.text = "Captain's Log - WUKSUIO17\n"%_t
    .."Last night we received a distress call. "%_t
    .."Someone was screaming in panic and it took a while to understand he was yelling things like ...CAREFUL!!! and ... CAN'T STOP!!! \n\n"%_t
    .."Shortly after that we saw a small object on the radar that was coming closer very quickly. "%_t
    .."It was a drone that was completely out of control! But it was already too late. \n\n"%_t
    .."The drone crashed into our side. Thankfully we had our shields up, but the drone was scrap. The owner will be very annoyed."%_t
    table.insert(logTexts, d17_CaptainsLog18)

    local d18_CaptainsLog19 = {}
    d18_CaptainsLog19.text = "Captain's Log - About Warships\n"%_t
    .."The Guidebook for Captains says that a fully functioning battleship must have:\n\n"%_t
    .."- 12.000 Omicron\n"%_t
    .."- At least one Colonel\n"%_t
    .."- At least 35% of its durability from shields\n"%_t
    .."- No issues with the crew\n"%_t
    table.insert(logTexts, d18_CaptainsLog19)

    local d19_CaptainsLog20 = {}
    d19_CaptainsLog20.text = "Captain's Log - Staff Meeting\n"%_t
    .."To call in a staff meeting one must use the following items at a Research Station:\n\n"%_t
    .."- Lightning Turret\n"%_t
    .."- Hacking Upgrade\n"%_t
    .."- Laser Turret\n"%_t
    .."- Railgun Turret\n"%_t
    .."- PDC Turret\n"%_t
    .."- IMPORTANT: One of the above must be Exotic or better"%_t
    table.insert(logTexts, d19_CaptainsLog20)

    local idString = (Entity().id.string)
    local number = string.match(idString, "%d+")
    local numberOfTexts = #logTexts
    local textNumber = number % numberOfTexts
    if textNumber == 0 then textNumber = 1 end

    return logTexts[textNumber]
end
