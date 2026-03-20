
local i = 0
local c = function() i = i + 1; return i end

BridgeStyle =
{
    Bridge = c(),
    Cockpit = c(),
    None = c(),
}
i = 0

ShipSubType =
{
    Default = c(),
    Freighter = c(),
    Miner = c(),
    Carrier = c(),
    ColonyShip = c(),
    GasFreighter = c(),
}
i = 0

StationSubType =
{
    Default = c(),
    Shipyard = c(),
    RepairDock = c(),
    ResourceDepot = c(),
    TradingPost = c(),
    EquipmentDock = c(),
    SmugglersMarket = c(),
    Scrapyard = c(),

    Mine = c(),
    SingleAsteroidMine = c(),
    Factory = c(),
    TurretFactory = c(),
    FighterFactory = c(),
    SolarPowerPlant = c(),
    Farm = c(),
    Ranch = c(),
    Collector = c(),

    Biotope = c(),
    Casino = c(),
    Habitat = c(),
    MilitaryOutpost = c(),
    Headquarters = c(),
    ResearchStation = c(),

    Commerce = c(),
    TravelHub = c(),
    RiftResearchCenter = c(),
}
i = 0

-- Please note that these PartTypes and VisualFeatures are rather subjective and may not represent everything perfectly.
-- Also note that not all of these are completely implemented yet and more features may come.
-- Some of these can be mutually exclusive. For performance reasons, combination validity like that is not checked,
-- so be careful and use common sense when adding them to your parts.

-- A lot of PartTypes are mutually exclusive, so only use 1 to be completely safe.
-- If these part types and visual features are used wrongly (and contradict each other for example), they won't be selected during the generation process.
PartType =
{
    Core = c(),
    Wing = c(),
    Nose = c(),
    Bridge = c(),
    Front = c(),
    Engine = c(),

    Decoration = c(),
    TurretBase = c(),
    GasTank = c(),
    Container = c(),
    Antennas = c(),

    StationPart = c(),
    SolarPanel = c(),
    ProductionCenter = c(),
    FarmCenter = c(),
    BioSphere = c(),
    Collector = c(),
    ResearchSphere = c(),
    Crane = c(),

    StationCore = c(),
    StationRing = c(),
    StationPartialRing = c(),
    StationOffsetRing = c(),
    StationPlatform = c(),
    StationArm = c(),
    StationDock = c(),
    StationAsteroid = c(),
    StationScaffolding = c(),
    StationTypeAdvertisement = c(),
    StationTravelRing = c(),
    StationRiftArm = c(),
    StationRiftAntennaA = c(),
    StationRiftAntennaB = c(),
    StationRiftDish = c(),
    StationContainerAdapter = c(),
    StationGasTankAdapter = c(),

    FighterWing = c(),
}

VisualFeature =
{
    -- general shape
    Allround        = c(), -- for when the part doesn't have any specific shape

    Simple          = c(), -- very easy to use, low-poly parts
    Round           = c(),
    Oval            = c(),

    -- rough indicator for size of the part
    -- Note: Different PartTypes have different size relations, a Small PartType.StationPart may have the same size as a large PartType.Core
    Small           = c(),
    Medium          = c(),
    Large           = c(),

    -- rough indicator if a part is especially long in one direction (in relation to the other axes)
    LongX           = c(),
    LongY           = c(),
    LongZ           = c(),

    -- Symmetry axes of the part, if it's symmetrical. These will not get verified in any way, so make sure they're correct!
    SymmetryX       = c(),
    SymmetryY       = c(),
    SymmetryZ       = c(),

    -- these are for when the part has only out-connectors in a certain direction
    OutXOnly        = c(),
    OutYOnly        = c(),
    OutZOnly        = c(),

    -- secondary shape
    Bulky           = c(), -- fat, bulky looking structures
    Filigrane       = c(), -- thin structures
    Elegant         = c(), -- elegant, smooth shape
    Hangar          = c(), -- can serve as a hangar

    -- these get worked into the surface through coloring, extra blocks or stretching
    Industrial      = c(), -- rugged look w/ lots of chimneys, shafts, framework
    Spiky           = c(), -- lots of long, sharp corners
    VerySpiky       = c(), -- lots of even longer, sharp corners
    Sharp           = c(), -- sharp edges
    Pillars         = c(), -- with pillars
    Alien           = c(), -- lots of different geometric, mathematical weirdness
    Advertisement   = c(), -- flashy, holo, colorful
    Armored         = c(), -- military style, armor blocks

    -- these get worked into the shape
    LightLines      = c(),
    Lights          = c(),

    -- For when the part should have a small separator to add a gap between itself and the next part
    Separator       = c(),

    -- technically speaking the following are topological features,
    -- but it is important to be able to control these when generating styles
    Repeating       = c(), -- parts with repeating connectors

    -- This is a visual feature that basically says "I can ONLY be an End"
    -- Don't use optionally. Every part can be turned into an end via direction white-/blacklist.
    -- May be used by Style/Stage as an 'additionalFeature' to easily remove all connectors after the first.
    End             = c(), -- Parts designed to work as an end. Only a single connector

    -- LinearX, Y, Z is a feature that is meant to indicate that a part can ONLY be linear (connector directions).
    -- Don't use optionally. Every part can be turned into a linear part via direction white-/blacklist.
    Linear         = c(), -- parts with in- and out connectors, only in 1 direction
    LinearX         = c(), -- parts with in- and out connectors, only in X direction, must define Linear as well
    LinearY         = c(), -- parts with in- and out connectors, only in Y direction, must define Linear as well
    LinearZ         = c(), -- parts with in- and out connectors, only in Z direction, must define Linear as well

    -- For when the part supports mirroring in a certain direction
    -- Mirror must be defined in OptionalFeatures, a part should never be able to enforce mirroring
    MirrorX         = c(),
    MirrorY         = c(),
    MirrorZ         = c(),


    -- testing & development
    TestFeature     = c(),
    Dev             = c(),
}
