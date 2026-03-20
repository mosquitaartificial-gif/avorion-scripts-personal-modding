package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlayerRollCredits
PlayerRollCredits = {}

PlayerRollCredits.data = {
    {person = "Avorion", roles = {"by Boxelware"}},
    {person = "Konstantin Kronfeldner", roles = {"Game Director", "Lead Developer"}},
    {person = "Philipp Erhardt", roles = {"Engine Developer"}},
    {person = "Margareta Schieber", roles = {"Developer"}},
    {person = "Felix Schieber", roles = {"Game Design"}},
    {person = "Susanne Bertling", roles = {"Developer"}},
    {person = "Hans Spath", roles = {"Developer"}},
    {person = "Susanna Balbaschova", roles = {"Community & PR"}},
    {person = "Fabio Krapohl", roles = {"Additional Programming"}},
    {person = "Music", roles = {
        "Hannes Kretzer",
        "Per Kiilstofte",}},
    {person = "Working Students", roles = {
        "Jan Martens",
        "Patrick Dill",
        "Tobias Lengfeld",
        "Daniel Lazar",
        "Martin Stumpf",
        "Ina Rupprecht",
        }},
    {person = "Boxelware Interns", roles = {
        "Veronika Schmid",
        "Niko Gesell",
        "Britta Philippsen",
        "Janik Zielonka",
        "Pascal Diroll",
        "Matthias Fleßner",
        }},
    {person = "Boxelware Interns", roles = {
        "Dominik Kirsch",
        "Lubomir Svetlinski",
        "Jonas Wörner",
        "Ben Berendes",
        "Laurin Sonnberger",
        }},
    {person = "Sound Design", roles = {
        "Only Sound",}},
    {person = "Additional 3D Assets", roles = {
        "Steven Futrell (BD)",}},
    {person = "Additional Assets", roles = {
        "Ann-Kathrin Raab",
        "Lorc, Delapouite & contributors",
        "rubina119",}},
    {person = "Additional Sound Effects", roles = {
        "JoelGerlach",
        "sarge4267",
        "Jason Thomas D",
        "Ryan Conway",
        "Kenney Vleugels"}},
    {person = "Special thanks to", roles = {
        "Andreas Schwarz (Llandon)",
        "Andreas Schäfer",
        "Ben Kotzubei",
        "Bernhard Heinloth",
        "Crispy",
        "Darieu"}},
    {person = "Special thanks to", roles = {
        "Dsko",
        "Florian Kühnert",
        "Helmut & Gertraud Wagner",
        "Justin",
        "Lao-Tse"}},
    {person = "Special thanks to", roles = {
        "Lumarious",
        "Mark Davis",
        "Flintsteel7",
        "Ulf",
        "arw"}},
    {person = "Special thanks to", roles = {
        "Nexi",
        "Robert Tang-Richardson",
        "Sellywelly",
        "Stefan Marcinek",
        "Victor Tombs"}},
    {person = "Special thanks to", roles = {
        "Wesley Johnson",
        "BigAlzBub",
        "Hahniel",
        "Ryan McAuley",
        "Dereck Draper"}},
    {person = "", roles = {
        "Complete Credits are",
        "available in the Main Menu",
        "For more info, visit",
        "our homepage at",
        "avorion.net"}},

}

if onClient() then

local currentIndex = 1
local showTimer = 0
local pauseTimer = 0
local fadeInTimer = 0
local fadeOutTimer = 0
function PlayerRollCredits.updateClient(timestep)
    fadeInTimer = fadeInTimer + timestep
    if fadeInTimer < 2 then
        PlayerRollCredits.fadeText(true, fadeInTimer)
    else
        showTimer = showTimer + timestep
        if showTimer < 5 then
            PlayerRollCredits.renderText()
        else
            fadeOutTimer = fadeOutTimer + timestep
            if fadeOutTimer < 2 then
                PlayerRollCredits.fadeText(false, fadeOutTimer)
            else
                pauseTimer = pauseTimer + timestep
            end
        end
    end

    if pauseTimer > 3 then
        fadeInTimer = 0
        showTimer = 0
        fadeOutTimer = 0
        pauseTimer = 0
        currentIndex = currentIndex + 1
        if currentIndex > #PlayerRollCredits.data then
            PlayerRollCredits.stop()
            terminate() -- immediately stop showing text
        end
    end
end

function PlayerRollCredits.fadeText(fadeIn, duration)
    local offset = 0
    local alpha = duration / 2
    local screenResolution = getResolution()

    if fadeIn then
        offset = offset + renderText(vec2(100, screenResolution.y/3) + vec2(10, offset), PlayerRollCredits.data[currentIndex].person, 40, 0, alpha)
        offset = offset + 20
        for _, roll in pairs(PlayerRollCredits.data[currentIndex].roles) do
            offset = offset - 10
            offset = offset + renderText(vec2(120, screenResolution.y/3) + vec2(10, offset), roll, 25, 0, alpha + 0.0)
        end
    else
        offset = offset + renderText(vec2(100, screenResolution.y/3) + vec2(10, offset), PlayerRollCredits.data[currentIndex].person, 40, 0,  (1 - alpha))
        offset = offset + 20
        for _, roll in pairs(PlayerRollCredits.data[currentIndex].roles) do
            offset = offset - 10
            offset = offset + renderText(vec2(120, screenResolution.y/3) + vec2(10, offset), roll, 25, 0,  (1 - alpha) + 0.0)
        end
    end
end

local showNames = false
function PlayerRollCredits.renderText()
    local screenResolution = getResolution()

    local offset = 0
    offset = offset + renderText(vec2(100, screenResolution.y/3) + vec2(10, offset), PlayerRollCredits.data[currentIndex].person, 40, 0)
    offset = offset + 20
    for _, roll in pairs(PlayerRollCredits.data[currentIndex].roles) do
        offset = offset - 10
        offset = offset + renderText(vec2(120, screenResolution.y/3) + vec2(10, offset), roll, 25, 0)
    end
end

end

function PlayerRollCredits.initialize()

end

-- common function
function PlayerRollCredits.stop()
    if onClient() then
        invokeServerFunction("stop")
    else
        terminate()
    end
end
callable(PlayerRollCredits, "stop")
