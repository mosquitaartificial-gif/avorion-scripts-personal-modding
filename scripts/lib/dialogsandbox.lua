package.path = package.path .. ";data/scripts/lib/?.lua" .. ";data/scripts/entity/dialogs/?.lua"
include("stringutility")

include("storyhints")

function onAnythingInteresting()
    ScriptUI():showDialog(thefour3())
end
