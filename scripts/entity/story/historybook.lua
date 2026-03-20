
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")

function initialize()

end

function interactionPossible(player, option)
    local craft = Player().craft
    if craft == nil then return false end
    local dist = craft:getNearestDistance(Entity())
    if dist < 20.0 then
        return true
    end
    return false, "You're not close enough to open the object."%_t
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
    local historyTexts = {}

    local d0_TheColonization = {}
    d0_TheColonization.text = "HISTORY OF THE GALAXY\nChapter 1\nThe colonization of the galaxy began 600 years ago. "%_t
    .."The alliances had committed centuries of research to the technologies that allowed settlement in space. \n\n"%_t
    .."Those that had not managed to acquire the necessary knowledge received help from other factions. "%_t
    .."Peace and prosperity reigned all throughout the galaxy.\n\n"%_t
    .."The alliances aided each other in battling epidemics, natural catastrophes and inner conflicts. "%_t
    .."But ever so slowly it became apparent that this peaceful galaxy was not meant to last...\n"%_t
    table.insert(historyTexts, d0_TheColonization)

    local d1_TheArrival = {}
    d1_TheArrival.text = "HISTORY OF THE GALAXY\nChapter 2\nThe arrival of the Xsotan\n"%_t
    .."About three centuries ago, the first Xsotan ships were sighted in our peaceful galaxy. "%_t
    .."At that time, all factions had come together to found the United Alliances (UA) and life was good.\n\n"%_t
    .."There were only few that dared to act against the common laws, and everybody worked together to subdue those individuals. "%_t
    .."But all of that changed when the Xsotan arrived.\n\n"%_t
    .."At first, the UA were willing to treat the newcomers with the same respect and friendliness they offered all life forms in the galaxy. "%_t
    .."They attempted to contact them, to invite them to assemblies and conferences. \n\n"%_t
    .."But no matter which means of communication was tried, an answer was never received. More and more Xsotan ships arrived, and then it began. \n\n"%_t
    .."The Xsotan attacked, destroyed and plundered anything that came close to their crafts. Ships, stations, asteroids, nothing was safe from them. "%_t
    .."Rumors started to spread that they annihilated entire planets and even suns! \n\nThe UA were shocked and helpless. "%_t
    .."But then they decided that they had to defend their galaxy. They began researching new war technologies and they were ready to stand their ground."%_t
    table.insert(historyTexts, d1_TheArrival)

    local d2_TheGreatWar = {}
    d2_TheGreatWar.text = "HISTORY OF THE GALAXY\nChapter 3\nThe Great War\n"%_t
    .."The Great War between the United Alliances (UA) and the Xsotan was the most brutal in history. "%_t
    .."For seven decades the two parties fought 38 battles and uncountable skirmishes for power and territory. \n\n"%_t
    .."Neither had any technological advantages or larger numbers to allow them to get the upper hand. "%_t
    .."But it was only the 39th battle that the UA lost for good. \n\n"%_t
    .."Even though their numbers were reduced and their soldiers weak, they entered the battle with hopeful fervor. "%_t
    .."They were led by the Haatii, the most powerful faction of that time with the most battle experience. \n\n"%_t
    .."They fought fiercely and while they didn't manage to break the Xsotan lines, they still forced the enemy to give up one sector after the other. "%_t
    .."All of a sudden, the Xsotan army decided to pull back. \n\n"%_t
    .."Drunk with happiness over their presumed victory, "%_t
    .."the army of the UA did not chase the Xsotan but remained where they were to care for their wounded and burn their dead. "%_t
    .."This was their undoing. "%_t
    table.insert(historyTexts, d2_TheGreatWar)

    local d3_TheEvent = {}
    d3_TheEvent.text = "HISTORY OF THE GALAXY\nChapter 4\nThe Event\n"%_t
    .."At the end of the Great War, the United Alliances (UA) had mounted one last battle against the Xsotan."%_t
    .."This battle ended with the Xsotan fleeing. \n\n"%_t
    .."The UA warriors believed they had defeated the Xsotan for good and celebrated. "%_t
    .."But it did not take long for them to realize that this had been a fatal error. The Xsotan had one more ace up their sleeve.\n\n "%_t
    .."They had invented a method to cause rifts in the space-time-continuum which could destroy entire sectors. "%_t
    .."Suddenly, the galaxy as it was known before ceased to exist.\n\n"%_t
    .."Instead, the entire center of the galaxy was separated from the outer sectors by a huge, impassable Barrier. "%_t
    .."This not only caused huge confusion among the UA, it also annihilated their army.\n\n "%_t
    .."In chasing the Xsotan, a large part of the army had been in exactly those sectors that the rift was created in. "%_t
    .."To this day nobody knows the fate that befell those unlucky enough to have been caught there."%_t
    table.insert(historyTexts, d3_TheEvent)

    local d4_OperationExodus = {}
    d4_OperationExodus.text = "HISTORY OF THE GALAXY\nChapter 5\nOperation Exodus\n"%_t
    .."After the Great War was lost, most of the remaining inhabitants of the galaxy moved to the outer sectors where the chances of Xsotan attacks were considered to be lower.\n\n "%_t
    .."The United Alliances (UA) were hesitant to leave such a large part of their fleet behind on the other side of the Barrier, but they could not see any way to save them at that moment.\n\n "%_t
    .."On their trek to the outer sectors, they left behind encrypted messages in case the survivors from beyond the rift would manage to escape and try to find them in their hiding places. "%_t
    .."But nobody ever returned from the other side of the Barrier. "%_t
    table.insert(historyTexts, d4_OperationExodus)

    local d5_TheBarrier = {}
    d5_TheBarrier.text = "HISTORY OF THE GALAXY\nChapter 6\nThe Barrier\n"%_t
    .."There are no reports that anyone has managed to enter any of the sectors inside the Barrier since the Event, although countless have tried. \n\n"%_t
    .."In the beginning, when there was still hope that the ships cut off from the outer sectors might be saved, many tried to research a way to cross the rift. "%_t
    .."But all of them gave up sooner or later. Nowadays, only odd adventurers in search of Xsotan riches attempt to find a way into the center. \n\n"%_t
    .."The only ones who can freely cross the Barrier are the Xsotan themselves. \n\n"%_t
    .."Even though they rule the entire center of the galaxy, there are still countless Xsotan in the outer sectors, attacking innocent ships and stations and causing everybody to live in constant fear. "%_t
    table.insert(historyTexts, d5_TheBarrier)

    local d6_TheFuture = {}
    d6_TheFuture.text = "HISTORY OF THE GALAXY\nChapter 7\nThe Future\n"%_t
    .."For a long time the United Alliances (UA) discussed what to do after the Xsotan had created the Barrier around the center of the galaxy. "%_t
    .."Some factions wanted to take cover and hide inside protected stations. \n\n"%_t
    .."Others wanted to spend all their time and energy on researching how to remove the Barrier and defeat the Xsotan once and for all. "%_t
    .."Many simply wanted to go on living their lives at the far reaches of the galaxy. Soon it became clear that no consensus would be reached. \n\n"%_t
    .."The UA disbanded, some factions left the galaxy never to be heard from again. "%_t
    .."Others, like the Haatii, built up their defenses and remained in the outer sectors, never losing hope that one day they would be able to expel the Xsotan from the galaxy."%_t
    table.insert(historyTexts, d6_TheFuture)

    local idString = (Entity().id.string)
    local number = string.match(idString, "%d+")
    local numberOfTexts = #historyTexts
    local textNumber = number % numberOfTexts
    if textNumber == 0 then textNumber = 1 end

    return historyTexts[textNumber]
end
