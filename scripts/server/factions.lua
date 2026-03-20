package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")
include ("galaxy")
local SectorTurretGenerator = include ("sectorturretgenerator")
include("weapontype")
include("faction")
local FactionPacks = include("factionpacks")

local StateForms = {}
StateForms[FactionStateFormType.Vanilla] =
{
    type = FactionStateFormType.Vanilla,
    subtypes = {
        {name = "The %s/*This refers to factions, such as 'The Xsotan'.*/"%_T, p = 1},
    },
    traits = {
        {name = "aggressive", from = -3, to = 3},
        {name = "brave", from = -3, to = 3},
        {name = "greedy", from = -3, to = 3},
        {name = "honorable", from = -3, to = 3},
        {name = "mistrustful", from = -3, to = 3},
        {name = "forgiving", from = -3, to = 3}
    },
}

StateForms[FactionStateFormType.Emirate] =
{
    type = FactionStateFormType.Emirate,
    subtypes = {
        {name = "The %s Emirate"%_T, p = 8},
        {name = "The Emirate of %s"%_T, p = 8},
        {name = "The United %s Emirate"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Emirate of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Emirate"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Emirate of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Emirate"%_T,     honorable = -3, p = 1},
        {name = "The Universal Emirate of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Emirate"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Emirate of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -1, to = 2},
        {name = "brave", from = 0, to = 2},
        {name = "greedy", from = -2, to = 0},
        {name = "honorable", from = 1, to = 1},
        {name = "mistrustful", from = -1, to = 1},
        {name = "forgiving", from = -3, to = 0}
    },
}

StateForms[FactionStateFormType.States] =
{
    type = FactionStateFormType.States,
    subtypes = {
        {name = "The %s States"%_T, p = 8},
        {name = "The States of %s"%_T, p = 8},
        {name = "The United %s States"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United States of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s States"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic States of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s States"%_T,     honorable = -3, p = 1},
        {name = "The Universal States of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s States"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic States of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -2, to = -1},
        {name = "brave", from = 0, to = 2},
        {name = "greedy", from = -2, to = 0},
        {name = "honorable", from = 0, to = 2},
        {name = "mistrustful", from = -2, to = 1},
        {name = "forgiving", from = -1, to = 2}
    },
}

StateForms[FactionStateFormType.Planets] =
{
    type = FactionStateFormType.Planets,
    subtypes = {
        {name = "The %s Planets"%_T, p = 8},
        {name = "The Planets of %s"%_T, p = 8},
        {name = "The United %s Planets"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Planets of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Planets"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Planets of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Planets"%_T,     honorable = -3, p = 1},
        {name = "The Universal Planets of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Planets"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Planets of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -1, to = 1},
        {name = "brave", from = -2, to = 0},
        {name = "greedy", from = 0, to = 1},
        {name = "honorable", from = -1, to = 1},
        {name = "mistrustful", from = -1, to = 2},
        {name = "forgiving", from = -1, to = 2}
    },
}

StateForms[FactionStateFormType.Kingdom] =
{
    type = FactionStateFormType.Kingdom,
    subtypes = {
        {name = "The %s Kingdom"%_T, p = 8},
        {name = "The Kingdom of %s"%_T, p = 8},
        {name = "The United %s Kingdom"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Kingdom of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Kingdom"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Kingdom of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Kingdom"%_T,     honorable = -3, p = 1},
        {name = "The Universal Kingdom of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Kingdom"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Kingdom of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -2, to = 0},
        {name = "brave", from = -1, to = 1},
        {name = "greedy", from = -1, to = 1},
        {name = "honorable", from = 2, to = 4},
        {name = "mistrustful", from = -2, to = 0},
        {name = "forgiving", from = -3, to = 0}
    },
}

StateForms[FactionStateFormType.Army] =
{
    type = FactionStateFormType.Army,
    subtypes = {
        {name = "The %s Army"%_T, p = 8},
        {name = "The Army of %s"%_T, p = 8},
        {name = "The United %s Army"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Army of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Army"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Army of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Army"%_T,     honorable = -3, p = 1},
        {name = "The Universal Army of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Army"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Army of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 1, to = 2},
        {name = "brave", from = -1, to = 2},
        {name = "greedy", from = -1, to = 1},
        {name = "honorable", from = -2, to = 0},
        {name = "mistrustful", from = -1, to = 1},
        {name = "forgiving", from = -2, to = 1}
    },
}

StateForms[FactionStateFormType.Empire] =
{
    type = FactionStateFormType.Empire,
    subtypes = {
        {name = "The %s Empire"%_T, p = 8},
        {name = "The Empire of %s"%_T, p = 8},
        {name =  "The United %s Empire"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name =  "The United Empire of %s"%_T,     greedy = 3, p = 1},
        {name =  "The Galactic %s Empire"%_T,      aggressive = 3, p = 1},
        {name =  "The Galactic Empire of %s"%_T,   aggressive = 3, p = 1},
        {name =  "The Universal %s Empire"%_T,     honorable = -3, p = 1},
        {name =  "The Universal Empire of %s"%_T,  honorable = -3, p = 1},
        {name =  "The Democratic %s Empire"%_T,    aggressive = -3, p = 1},
        {name =  "The Democratic Empire of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 2, to = 4},
        {name = "brave", from = 2, to = 4},
        {name = "greedy", from = 1, to = 3},
        {name = "honorable", from = -1, to = 1},
        {name = "mistrustful", from = 1, to = 3},
        {name = "forgiving", from = -4, to = -2}
    },
}

StateForms[FactionStateFormType.Clan] =
{
    type = FactionStateFormType.Clan,
    subtypes = {
        {name = "The %s Clan"%_T, p = 8},
        {name = "The Clan of %s"%_T, p = 8},
        {name = "The United %s Clan"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Clan of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Clan"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Clan of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Clan"%_T,     honorable = -3, p = 1},
        {name = "The Universal Clan of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Clan"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Clan of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 3, to = 4},
        {name = "brave", from = 0, to = 3},
        {name = "greedy", from = 0, to = 2},
        {name = "honorable", from = -3, to = -1},
        {name = "mistrustful", from = 1, to = 3},
        {name = "forgiving", from = -3, to = 0}
    },
}

StateForms[FactionStateFormType.Church] =
{
    type = FactionStateFormType.Church,
    subtypes = {
        {name = "The %s Church"%_T, p = 8},
        {name = "The Church of %s"%_T, p = 8},
        {name = "The United %s Church"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Church of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Church"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Church of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Church"%_T,     honorable = -3, p = 1},
        {name = "The Universal Church of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Church"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Church of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -1, to = 1},
        {name = "brave", from = -1, to = 2},
        {name = "greedy", from = -4, to = -2},
        {name = "honorable", from = 2, to = 3},
        {name = "mistrustful", from = -2, to = 1},
        {name = "forgiving", from = 2, to = 4}
    },
}

StateForms[FactionStateFormType.Corporation] =
{
    type = FactionStateFormType.Corporation,
    subtypes = {
        {name = "The %s Corporation"%_T, p = 8},
        {name = "The Corporation of %s"%_T, p = 8},
        {name = "The United %s Corporation"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Corporation of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Corporation"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Corporation of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Corporation"%_T,     honorable = -3, p = 1},
        {name = "The Universal Corporation of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Corporation"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Corporation of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 0, to = 2},
        {name = "brave", from = -3, to = -2},
        {name = "greedy", from = 1, to = 3},
        {name = "honorable", from = -2, to = 0},
        {name = "mistrustful", from = 0, to = 3},
        {name = "forgiving", from = -1, to = 2}
    },
}

StateForms[FactionStateFormType.Federation] =
{
    type = FactionStateFormType.Federation,
    subtypes = {
        {name = "The %s Federation"%_T, p = 8},
        {name = "The Federation of %s"%_T, p = 8},
        {name = "The United %s Federation"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Federation of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Federation"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Federation of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Federation"%_T,     honorable = -3, p = 1},
        {name = "The Universal Federation of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Federation"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Federation of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -3, to = -1},
        {name = "brave", from = -2, to = 0},
        {name = "greedy", from = -3, to = 0},
        {name = "honorable", from = 2, to = 4},
        {name = "mistrustful", from = -4, to = -4},
        {name = "forgiving", from = 0, to = 3}
    },
}

StateForms[FactionStateFormType.Collective] =
{
    type = FactionStateFormType.Collective,
    subtypes = {
        {name = "The %s Collective"%_T, p = 8},
        {name = "The Collective of %s"%_T, p = 8},
        {name = "The United %s Collective"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Collective of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Collective"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Collective of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Collective"%_T,     honorable = -3, p = 1},
        {name = "The Universal Collective of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Collective"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Collective of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -1, to = 2},
        {name = "brave", from = -1, to = 1},
        {name = "greedy", from = -1, to = 2},
        {name = "honorable", from = -2, to = 0},
        {name = "mistrustful", from = -4, to = -2},
        {name = "forgiving", from = -1, to = 1}
    },
}

StateForms[FactionStateFormType.Followers] =
{
    type = FactionStateFormType.Followers,
    subtypes = {
        {name = "The %s Followers"%_T, p = 8},
        {name = "The Followers of %s"%_T, p = 8},
        {name = "The United %s Followers"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Followers of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Followers"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Followers of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Followers"%_T,     honorable = -3, p = 1},
        {name = "The Universal Followers of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Followers"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Followers of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 1, to = 3},
        {name = "brave", from = 1, to = 4},
        {name = "greedy", from = -2, to = 1},
        {name = "honorable", from = 1, to = 2},
        {name = "mistrustful", from = -1, to = 2},
        {name = "forgiving", from = -1, to = 2}
    },
}

StateForms[FactionStateFormType.Organization] =
{
    type = FactionStateFormType.Organization,
    subtypes = {
        {name = "The %s Organization"%_T, p = 8},
        {name = "The Organization of %s"%_T, p = 8},
        {name = "The United %s Organization"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Organization of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Organization"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Organization of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Organization"%_T,     honorable = -3, p = 1},
        {name = "The Universal Organization of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Organization"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Organization of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -2, to = 2},
        {name = "brave", from = -2, to = 2},
        {name = "greedy", from = -2, to = 2},
        {name = "honorable", from = -2, to = 2},
        {name = "mistrustful", from = -2, to = 2},
        {name = "forgiving", from = -2, to = 2}
    },
}

StateForms[FactionStateFormType.Alliance] =
{
    type = FactionStateFormType.Alliance,
    subtypes = {
        {name = "The %s Alliance"%_T, p = 8},
        {name = "The Alliance of %s"%_T, p = 8},
        {name = "The United %s Alliance"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Alliance of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Alliance"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Alliance of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Alliance"%_T,     honorable = -3, p = 1},
        {name = "The Universal Alliance of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Alliance"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Alliance of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -1, to = 1},
        {name = "brave", from = -1, to = 1},
        {name = "greedy", from = -1, to = 2},
        {name = "honorable", from = 0, to = 2},
        {name = "mistrustful", from = -4, to = -2},
        {name = "forgiving", from = 0, to = 3}
    },
}

StateForms[FactionStateFormType.Republic] =
{
    type = FactionStateFormType.Republic,
    subtypes = {
        {name = "The %s Republic"%_T, p = 8},
        {name = "The Republic of %s"%_T, p = 8},
        {name = "The United %s Republic"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Republic of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Republic"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Republic of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Republic"%_T,     honorable = -3, p = 1},
        {name = "The Universal Republic of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Republic"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Republic of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -1, to = 1},
        {name = "brave", from = -3, to = -1},
        {name = "greedy", from = -2, to = 0},
        {name = "honorable", from = 1, to = 3},
        {name = "mistrustful", from = -2, to = 1},
        {name = "forgiving", from = -1, to = 2}
    },
}

StateForms[FactionStateFormType.Commonwealth] =
{
    type = FactionStateFormType.Commonwealth,
    subtypes = {
        {name = "The %s Commonwealth"%_T, p = 8},
        {name = "The Commonwealth of %s"%_T, p = 8},
        {name = "The United %s Commonwealth"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Commonwealth of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Commonwealth"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Commonwealth of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Commonwealth"%_T,     honorable = -3, p = 1},
        {name = "The Universal Commonwealth of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Commonwealth"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Commonwealth of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -2, to = 0},
        {name = "brave", from = -2, to = 0},
        {name = "greedy", from = -2, to = 1},
        {name = "honorable", from = -2, to = 0},
        {name = "mistrustful", from = -2, to = 0},
        {name = "forgiving", from = 0, to = 3}
    },
}

StateForms[FactionStateFormType.Dominion] =
{
    type = FactionStateFormType.Dominion,
    subtypes = {
        {name = "The %s Dominion"%_T, p = 8},
        {name = "The Dominion of %s"%_T, p = 8},
        {name = "The United %s Dominion"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Dominion of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Dominion"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Dominion of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Dominion"%_T,     honorable = -3, p = 1},
        {name = "The Universal Dominion of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Dominion"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Dominion of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 4, to = 4},
        {name = "brave", from = -1, to = 1},
        {name = "greedy", from = -2, to = 0},
        {name = "honorable", from = -3, to = -1},
        {name = "mistrustful", from = 4, to = 4},
        {name = "forgiving", from = -4, to = -3}
    },
    badInitialRelations = true,
}

StateForms[FactionStateFormType.Syndicate] =
{
    type = FactionStateFormType.Syndicate,
    subtypes = {
        {name = "The %s Syndicate"%_T, p = 8},
        {name = "The Syndicate of %s"%_T, p = 8},
        {name = "The United %s Syndicate"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Syndicate of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Syndicate"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Syndicate of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Syndicate"%_T,     honorable = -3, p = 1},
        {name = "The Universal Syndicate of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Syndicate"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Syndicate of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 4, to = 4},
        {name = "brave", from = -4, to = -3},
        {name = "greedy", from = 3, to = 4},
        {name = "honorable", from = -4, to = 3},
        {name = "mistrustful", from = 4, to = 4},
        {name = "forgiving", from = -4, to = -3}
    },
    badInitialRelations = true,
}

StateForms[FactionStateFormType.Guild] =
{
    type = FactionStateFormType.Guild,
    subtypes = {
        {name = "The %s Guild"%_T, p = 8},
        {name = "The Guild of %s"%_T, p = 8},
        {name = "The United %s Guild"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Guild of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Guild"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Guild of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Guild"%_T,     honorable = -3, p = 1},
        {name = "The Universal Guild of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Guild"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Guild of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -4, to = -2},
        {name = "brave", from = -3, to = -2},
        {name = "greedy", from = -2, to = 0},
        {name = "honorable", from = -1, to = 2},
        {name = "mistrustful", from = -1, to = 2},
        {name = "forgiving", from = -1, to = 2}
    },
}

StateForms[FactionStateFormType.Buccaneers] =
{
    type = FactionStateFormType.Buccaneers,
    subtypes = {
        {name = "The %s Buccaneers"%_T, p = 8},
        {name = "The Buccaneers of %s"%_T, p = 8},
        {name = "The United %s Buccaneers"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Buccaneers of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Buccaneers"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Buccaneers of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Buccaneers"%_T,     honorable = -3, p = 1},
        {name = "The Universal Buccaneers of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Buccaneers"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Buccaneers of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = 4, to = 4},
        {name = "brave", from = 2, to = 3},
        {name = "greedy", from = 1, to = 3},
        {name = "honorable", from = -4, to = -3},
        {name = "mistrustful", from = 4, to = 4},
        {name = "forgiving", from = -4, to = -3}
    },
    badInitialRelations = true,
}

StateForms[FactionStateFormType.Conglomerate] =
{
    type = FactionStateFormType.Conglomerate,
    subtypes = {
        {name = "The %s Conglomerate"%_T, p = 8},
        {name = "The Conglomerate of %s"%_T, p = 8},
        {name = "The United %s Conglomerate"%_T,        greedy = 3, p = 1}, -- Trait Changes here must be the exact same as the traits assigned below, and not opposites
        {name = "The United Conglomerate of %s"%_T,     greedy = 3, p = 1},
        {name = "The Galactic %s Conglomerate"%_T,      aggressive = 3, p = 1},
        {name = "The Galactic Conglomerate of %s"%_T,   aggressive = 3, p = 1},
        {name = "The Universal %s Conglomerate"%_T,     honorable = -3, p = 1},
        {name = "The Universal Conglomerate of %s"%_T,  honorable = -3, p = 1},
        {name = "The Democratic %s Conglomerate"%_T,    aggressive = -3, p = 1},
        {name = "The Democratic Conglomerate of %s"%_T, aggressive = -3, p = 1},
    },
    traits = {
        {name = "aggressive", from = -2, to = 0},
        {name = "brave", from = -4, to = -3},
        {name = "greedy", from = 2, to = 4},
        {name = "honorable", from = -2, to = 0},
        {name = "mistrustful", from = 2, to = 4},
        {name = "forgiving", from = -1, to = 2}
    },
}

-- Legacy faction names for backwards compatability
-- those are not being used, but kept around so translation won't break
local oldNamesForTranslation =
{
    "The %s Pirates"%_T,
    "The Pirates of %s"%_T,

    "The United %s Pirates"%_T,
    "The United Pirates of %s"%_T,
    "The Galactic %s Pirates"%_T,
    "The Galactic Pirates of %s"%_T,
    "The Universal %s Pirates"%_T,
    "The Universal Pirates of %s"%_T,
    "The Democratic %s Pirates"%_T,
    "The Democratic Pirates of %s"%_T,
}
-- End legacy faction names


function initializeAIFaction(faction, baseName, stateFormName)

    local seed = Server().seed + faction.index
    local random = Random(seed)

    local language = Language(random:createSeed())
    faction:setLanguage(language)

    local possibleStateForms = {}
    for k, v in pairs(FactionStateFormType) do
        table.insert(possibleStateForms, v)
    end

    local stateFormType = FactionStateFormType.Vanilla
    if random:test(0.9) then
        stateFormType = randomEntry(random, possibleStateForms)
    end

    local stateForm = StateForms[stateFormType] or StateForms[FactionStateFormType.Vanilla]
    local subtype = {}
    faction:setValue("state_form_type", stateFormType)

    if baseName then
        faction.baseName = baseName
    else
        faction.baseName = language:getName()

        local subtypes = {}
        for _, subtype in pairs(stateForm.subtypes) do
            subtypes[subtype] = subtype.p
        end

        subtype = selectByWeight(random, subtypes)
        faction.stateForm = subtype.name
    end

    if stateFormName then
        faction.stateForm = stateFormName
    end

    local traitPairs =
    {
        aggressive = {name = "aggressive"%_T, opposite = "peaceful"%_T},
        peaceful = {name = "peaceful"%_T, opposite = "aggressive"%_T},
        brave = {name = "brave"%_T, opposite = "careful"%_T},
        careful = {name = "careful"%_T, opposite = "brave"%_T},
        greedy = {name = "greedy"%_T, opposite = "generous"%_T},
        generous = {name = "generous"%_T, opposite = "greedy"%_T},
        honorable = {name = "honorable"%_T, opposite = "opportunistic"%_T},
        opportunistic = {name = "opportunistic"%_T, opposite = "honorable"%_T},
        mistrustful = {name = "mistrustful"%_T, opposite = "trusting"%_T},
        trusting = {name = "trusting"%_T, opposite = "mistrustful"%_T},
        unforgiving = {name = "unforgiving"%_T, opposite = "forgiving"%_T},
        forgiving = {name = "forgiving"%_T, opposite = "unforgiving"%_T},
    }

    -- assign traits
    for _, traitData in pairs(stateForm.traits) do
        local trait = traitPairs[traitData.name]

        local value = random:getInt(traitData.from, traitData.to)
        value = value + (subtype[traitData.name] or 0)
        value = math.max(-4, math.min(4, value))

        SetFactionTrait(faction, trait.name, trait.opposite, value / 4)
    end

    -- initial relations
    local initialRelations = random:getInt(-10000, 20000)
    if stateForm.badInitialRelations then
        initialRelations = -800000
    end

    local variation = random:getInt(0, 8)
    if variation == 0 then initialRelations = random:getInt(-40000, -25000) end -- random bad relations
    if variation == 1 then initialRelations = random:getInt(25000, 40000) end -- random good relations

    -- difficulty ranges from -3 (easiest) to 3 (hardest)
    local playerDelta = GameSettings().initialRelations * -15000
    local initialRelationsToPlayer = initialRelations + playerDelta

    if variation ~= 1 then
        -- except for the random good relations factions, initial relations to players
        -- get worse towards the center of the galaxy
        local maxWorsened = 40000 - playerDelta;
        local dimensions = Balancing_GetDimensions()

        local hx, hy = faction:getHomeSectorCoordinates()
        local worsening = lerp(length(vec2(hx, hy)), 0, 350, maxWorsened, 0)

        initialRelationsToPlayer = initialRelations - worsening
    end

    faction.initialRelationsToPlayer = math.max(-80000, initialRelationsToPlayer)
    faction.initialRelations = math.max(-80000, initialRelations)


    -- armament
    local turretGenerator = SectorTurretGenerator(seed)
    turretGenerator.coaxialAllowed = false

    local x, y = faction:getHomeSectorCoordinates()

    local armed1 = turretGenerator:generateArmed(x, y, 0, Rarity(RarityType.Common))
    local armed2 = turretGenerator:generateArmed(x, y, 0, Rarity(RarityType.Common))
    local unarmed1 = turretGenerator:generate(x, y, 0, Rarity(RarityType.Common), WeaponType.MiningLaser)

    -- make sure the armed turrets don't have a too high fire rate
    -- so they don't slow down update times too much when there's lots of firing going on
    for _, turret in pairs({armed1, armed2}) do

        local weapons = {turret:getWeapons()}
        turret:clearWeapons()

        for _, weapon in pairs(weapons) do

            if weapon.isProjectile and (weapon.fireRate or 0) > 2 then
                local old = weapon.fireRate
                weapon.fireRate = math.random(1.0, 2.0)
                weapon.damage = weapon.damage * old / weapon.fireRate;
            end

            turret:addWeapon(weapon)
        end
    end

    faction:getInventory():add(armed1, false)
    faction:getInventory():add(armed2, false)
    faction:getInventory():add(unarmed1, false)


    FactionPacks.tryApply(faction)
end

function initializePlayer(player)

    local galaxy = Galaxy()
    local server = Server()

    local random = Random(server.seed)

    -- get a random angle, fixed for the server seed
    local angle = random:getFloat(2.0 * math.pi)


    -- for each player registered, add a small amount on top of this angle
    -- this way, all players are near each other
    local home = nil
    local faction

    local distFromCenter = 450.0
    local distBetweenPlayers = 1 + random:getFloat(0, 1) -- distance between the home sectors of different players

    local tries = {}

    for i = 1, 3000 do
        -- we're looking at a distance of 450, so the perimeter is ~1413
        -- with every failure we walk a distance of 3 on the perimeter, so we're finishing a complete round about every 500 failing iterations
        -- every failed round we reduce the radius by several sectors to cover a bigger area.
        local offset = math.floor(i / 500) * 5

        local coords =
        {
            x = math.cos(angle) * (distFromCenter - offset),
            y = math.sin(angle) * (distFromCenter - offset),
        }

        table.insert(tries, coords)

        -- try to place the player in the area of a faction
        faction = galaxy:getLocalFaction(coords.x, coords.y)
        if faction then
            -- found a faction we can place the player to - stop looking if we don't need different start sectors
            if server.sameStartSector then
                home = coords
                break
            end

            -- in case we need different starting sectors: keep looking
            if galaxy:sectorExists(coords.x, coords.y) then
                angle = angle + (distBetweenPlayers / distFromCenter)
            else
                home = coords
                break
            end
        else
            angle = angle + (3 / distFromCenter)
        end
    end

    if not home then
        home = randomEntry(tries)
        faction = galaxy:getLocalFaction(home.x, home.y)
    end

    player:setHomeSectorCoordinates(home.x, home.y)
    player:setReconstructionSiteCoordinates(home.x, home.y)
    player:setRespawnSiteCoordinates(home.x, home.y)

    -- make sure the player has an early ally
    if not faction then
        faction = galaxy:getNearestFaction(home.x, home.y)
    end

    faction:setValue("enemy_faction", -1) -- this faction won't participate in faction wars
    galaxy:setFactionRelations(faction, player, 85000)
    player:setValue("start_ally", faction.index)
    player:setValue("gates2.0", true)

    local random = Random(SectorSeed(home.x, home.y) + player.index)
    local settings = GameSettings()

    if settings.startingResources == -4 then -- -4 means quick start
        player:receive(250000, 25000, 15000)
    elseif settings.startingResources == Difficulty.Beginner then
        player:receive(50000, 5000)
    elseif settings.startingResources == Difficulty.Easy then
        player:receive(40000, 2000)
    elseif settings.startingResources == Difficulty.Normal then
        player:receive(30000)
    else
        player:receive(10000)
    end

    -- create turret generator
    local generator = SectorTurretGenerator()

    local miningLaser = InventoryTurret(generator:generate(450, 0, nil, Rarity(RarityType.Common), WeaponType.MiningLaser, Material(MaterialType.Iron)))
    for i = 1, 2 do
        player:getInventory():add(miningLaser, false)
    end

    local chaingun = InventoryTurret(generator:generate(450, 0, nil, Rarity(RarityType.Common), WeaponType.ChainGun, Material(MaterialType.Iron)))
    for i = 1, 2 do
        player:getInventory():add(chaingun, false)
    end

    if settings.playTutorial then
        -- extra inventory items for tutorial: One arbitrary tcs, three more armed turrets with the name used in the text of tutorial stage
        local upgrade = SystemUpgradeTemplate("data/scripts/systems/arbitrarytcs.lua", Rarity(RarityType.Uncommon), Seed(121))
        player:getInventory():add(upgrade, true)

        chaingun.title = "Chaingun /* Weapon Type */"%_T
        player:getInventory():add(chaingun, false)
        player:getInventory():add(chaingun, false)
        player:getInventory():add(chaingun, false)

        -- start with 750 iron and 30.000 credits into tutorial independent of difficulty
        player.money = 30000
        player:setResources(750, 0, 0, 0, 0, 0, 0, 0)
    else
        if server.difficulty <= Difficulty.Normal then

            local upgrade = SystemUpgradeTemplate("data/scripts/systems/arbitrarytcs.lua", Rarity(RarityType.Uncommon), Seed(1))
            player:getInventory():add(upgrade, true)

            player:receive(0, 7500)

            for i = 1, 2 do
                player:getInventory():add(miningLaser, false)
                player:getInventory():add(chaingun, false)
            end
        end
    end

    if settings.fullBuildingUnlocked then
        player.maxBuildableMaterial = Material(MaterialType.Avorion)
    else
        player.maxBuildableMaterial = Material(MaterialType.Iron)
    end

    if settings.unlimitedProcessingPower or settings.fullBuildingUnlocked then
        player.maxBuildableSockets = 0
    else
        player.maxBuildableSockets = 4
    end
end

function initializeAlliance(alliance)
    alliance:setValue("gates2.0", true)

end
