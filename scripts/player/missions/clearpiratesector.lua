package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("callable")
include("randomext")
include("structuredmission")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")


mission.data.brief = "Wipe out Pirates"%_t
mission.data.title = "Wipe out pirates in (${location.x}:${location.y})"%_t

mission.data.autoTrackMission = true

mission.data.description = "You were tasked to take care of a group of pirates that appears to have settled in sector (${location.x}:${location.y})."%_t

mission.data.reward.paymentMessage = "Earned %1% credits for wiping out a pirate group."%_T
mission.data.accomplishMessage = "Thank you for taking care of this scum. We transferred the reward to your account."%_t
mission.data.finishMessage = "Looks like someone already took care of them. Thank you nevertheless."%_t
mission.data.custom.playerReportedPresent = false

mission.phases[1] = {}
mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    mission.data.custom.playerReportedPresent = true
end

local timerStarted = false
mission.phases[1].updateTargetLocationServer = function(timeStep)
    local count = countWavePirates()
    mission.data.piratesFound = mission.data.piratesFound or count > 0

    if not mission.data.custom.playerReportedPresent then return end -- wait for client

    if mission.data.piratesFound and count == 0 then
        reward()
        accomplish()
    elseif not mission.data.piratesFound and count == 0 then
        if not timerStarted then
            mission.phases[1].timers[1].time = 5 -- wait some time for a more natural flow aka 'scanners take a bit of time'
            timerStarted = true
        end
    end
end
mission.phases[1].timers =
{
    {
        callback = function()
            if onClient() then return end

            showMissionAccomplished()
            finish()
        end
    }
}

function countWavePirates()
    local count = 0
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(ships) do
        if ship:getValue("is_wave") then
            count = count + 1
        end
    end

    return count
end

mission.makeBulletin = function(station)

    -- find a sector that has pirates
    local specs = SectorSpecifics()
    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    local coords = specs.getShuffledCoordinates(random(), x, y, 2, 15)
    local serverSeed = Server().seed
    local target = nil

    for _, coord in pairs(coords) do
        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)

        if offgrid and not blocked and giverInsideBarrier == MissionUT.checkSectorInsideBarrier(coord.x, coord.y) then
            specs:initialize(coord.x, coord.y, serverSeed)

            if specs.generationTemplate.path == "sectors/pirateasteroidfield" then
                if not Galaxy():sectorExists(coord.x, coord.y) then
                    target = coord
                    break
                end
            end
        end
    end

    if not target then return end

    local description = "A nearby sector has been occupied by pirates and they have been attacking our convoys and traders.\nWe cannot let that scum do whatever they like. We need someone to take care of them.\n\nSector: (${x} : ${y})"%_t

    reward = {credits = 50000 * Balancing.GetSectorRewardFactor(Sector():getCoordinates()), relations = 6000}
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)

    local bulletin =
    {
        -- data for the bulletin board
        brief = "Wipe out Pirates"%_T,
        description = description,
        difficulty = "Medium /*difficulty*/"%_T,
        reward = "¢${reward}"%_T,
        script = "missions/clearpiratesector.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward.credits)},
        msg = "Their location is \\s(%1%:%2%)."%_T,
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = station.index,
            location = target,
            reward = reward,
        }},
    }

    return bulletin
end
