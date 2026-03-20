package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PirateAmbushLeader
PirateAmbushLeader = {}

-- make the NPC talk to players
PirateAmbushLeader = include("npcapi/singleinteraction")

include("stringutility")

function PirateAmbushLeader.getDialog()
    return {text = "Haha, our fake distress call worked! You're as good as dead, maggot!"%_t}
end
