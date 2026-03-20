package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("galaxy")
include ("randomext")
local SectorGenerator = include ("SectorGenerator")
local Balancing = include ("galaxy")
local PlanGenerator = include ("plangenerator")

-- mission.tracing = true

mission.data.title = "Hide Evidence"%_t
mission.data.brief = mission.data.title

mission.data.autoTrackMission = true

mission.data.location = {}
mission.data.description = {}
mission.data.description[1] = "After one of our military exercises we stumbled across a little problem. It seems that some of our torpedos went a little out of control and hit a civilian ship. We left the sector immediately, but the wreckage of that civilian ship is still there. We need help hiding any evidence hinting that we are involved in that incident."%_T
mission.data.description[2] = {text = "", bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[3] = {text = "Check your mail for your reward."%_T, bulletPoint = true, fulfilled = false, visible = false}

mission.data.accomplishMessage = "The flight recorder with all evidence has been destroyed. Check your mail for your reward."%_t
mission.data.failMessage = "The remains of the ship have been found."%_t

mission.data.timeLimit = 30 * 60
mission.data.timeLimitInDescription = true

mission.data.custom.isDone = false

mission.phases[1] = {}
mission.phases[1].onBegin = function()
    mission.data.description[2] = {text = "Go to sector (${x}:${y}) and salvage the wreckage until nothing can be traced back to us."%_T, arguments = {x = mission.data.location.x, y = mission.data.location.y}, visible = true, bulletPoint = true}
end
mission.phases[1].onTargetLocationEntered = function (x, y)
    createWreckage()
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].onBeginClient = function()
    -- this highlights the wreckage as interesting object and draws a little arrow
    Player():registerCallback("onPreRenderHud", "onPreRenderHud")
end
mission.phases[2].updateServer = function(timestep)
    local coords = {Sector():getCoordinates()}
    if mission.data.location.x ~= coords[1] or mission.data.location.y ~= coords[2] then return end

    if not mission.data.custom.isDone and blackBoxDestroyed() then
        finishUp()
    end
end
mission.phases[2].onRestore = function()
    -- after relog the wreckage should still be highlighted
    Player():registerCallback("onPreRenderHud", "onPreRenderHud")
    Player():registerCallback("onMailCleared", "onMailCleared")
end
mission.phases[2].timers = {}
mission.phases[2].timers[1] = {callback = function() onDeletionTimeUp() end}

function blackBoxDestroyed()

    for _, wreckId in pairs(mission.data.custom.wreckagePieceIds) do
        local entity = Entity(wreckId)
        if not entity then goto continue end

        local plan = Plan(wreckId)
        if not plan then goto continue end
        local blackbox = plan:getBlocksByType(BlockType.BlackBox)
        if blackbox and #blackbox > 0 then
            return false
        end
        ::continue::
    end

    return true
end

function finishUp()
    sendAccomplishedMail()
    mission.data.custom.isDone = true
    mission.data.description[3].visible = true

    showMissionAccomplished()
    -- show chat message as well
    if mission.data.accomplishMessage and mission.data.accomplishMessage ~= "" then
        local player = Player()
        local sender = NamedFormat(mission.data.giver.baseTitle or "", mission.data.giver.titleArgs or {})
        player:sendChatMessage(sender, 0, mission.data.accomplishMessage)
    end

    Player():registerCallback("onMailCleared", "onMailCleared")
    finish()
end

function deleteMail(mailIndex)
    local player = Player()
    local mail = player:getMail(mailIndex)
    if mail and mail.id == "hide_evidence" then
        player:removeMail(mailIndex)
    end
end

local mailToDeleteIndex
function onMailCleared(playerIndex, mailIndex, mailId)
    if mailId == "hide_evidence" then
        -- wait a tick, so that update can happen before we delete this mail
        mailToDeleteIndex = mailIndex
        mission.phases[2].timers[1].time = 5
    end
end

function onDeletionTimeUp()
    deleteMail(mailToDeleteIndex)
    terminate()
end

function createWreckage()
    if onClient() then return end
    local generator = SectorGenerator(Sector():getCoordinates())
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local plan = PlanGenerator.makeFreighterPlan(faction)
    plan:setBlockType(plan.rootIndex, BlockType.BlackBox)

    local wreckages = {generator:createWreckage(faction, plan, 10)}
    mission.data.custom.wreckagePieceIds = {}

    for _, w in pairs(wreckages) do
        table.insert(mission.data.custom.wreckagePieceIds, w.id)
    end
end

function onPreRenderHud()
    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    local renderer = UIRenderer()

    if not mission.data.custom.wreckagePieceIds then return end
    for _, wreckId in pairs(mission.data.custom.wreckagePieceIds) do
        local entity = Entity(wreckId)
        if not entity then return end

        renderer:renderEntityTargeter(entity, ColorRGB(1, 1, 1))
        renderer:renderEntityArrow(entity, 30, 10, 250, ColorRGB(1, 1, 1))
    end

    renderer:display()
end

function sendAccomplishedMail()
    local mail = Mail()
    local r = mission.data.reward
    mail.header = "(no subject)"%_T
    mail.text = "Thank you for taking care of business. Just to remind you: this is top-secret, we never asked you to do anything and you never received anything from us.\n\nYour pay is enclosed.\nPS: This mail will autodelete itself as soon as you take the attachment."%_T
    mail.sender = "Colonel Blisk"%_T
    mail.money = r.credits
    mail:setResources(r.iron, r.titanium, r.naonite, r.trinium, r.xanion, r.ogonite, r.avorion)

    mail.id = "hide_evidence"
    Player():addMail(mail)
end

mission.makeBulletin = function(station)

    --find empty sector
    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    mission.data.location.x, mission.data.location.y = MissionUT.getSector(x, y, 3, 6, false, false, false, false)

    if not mission.data.location.x or not mission.data.location.y or giverInsideBarrier ~= MissionUT.checkSectorInsideBarrier(mission.data.location.x, mission.data.location.y) then return end

    local balancing = Balancing.GetSectorRewardFactor(Sector():getCoordinates())
    reward = {credits = 45000 * balancing, relations = 6500, paymentMessage = "Earned %1% Credits for letting evidence disappear."%_T}
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)

    punishment = {relations = reward.relations}

    local bulletin =
    {
        -- data for the bulletin board
        brief = "Concealment"%_T,
        title = mission.data.title,
        description = mission.data.description[1],
        difficulty = "Easy /*difficulty*/"%_T,
        reward = "¢${reward}"%_T,
        script = "missions/hideevidence.lua",
        formatArguments = {x = mission.data.location.x, y = mission.data.location.y, reward = createMonetaryString(reward.credits)},
        msg = "Go to sector \\s(%1%:%2%) and destroy all evidence of our little incident."%_T,
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = station.id,
            location = mission.data.location,
            reward = reward,
            punishment = punishment,
        }},
    }

    return bulletin
end
