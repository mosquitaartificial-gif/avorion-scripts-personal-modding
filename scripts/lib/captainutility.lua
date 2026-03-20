package.path = package.path .. ";data/scripts/lib/?.lua"

local CommandType = include("data/scripts/player/background/simulation/commandtype")
include("stringutility")
include("tooltipmaker")
include("randomext")
local CaptainClass = include("captainclass")

local CaptainUtility = {}

CaptainUtility.ClassType = CaptainClass

function CaptainUtility.ClassProperties()
    local properties = {}

    properties[CaptainUtility.ClassType.None] =
    {
        displayName = "",
        displayNameFemale = "",
        untranslatedName = "",
        untranslatedNameFemale = "",
        description = "The captain has had no special training. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain has had no special training. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-vanilla.png",
        tooltipIcon = "data/textures/ui/captain/symbol-vanilla-black-bg.png",
        center = "data/textures/ui/captain/center-white-shaded.png",
        ring = "data/textures/ui/captain/ring-grey-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(1,1,1),
        primaryColor = ColorRGB(1.0, 1.0, 1.0),
        secondaryColor = ColorRGB(1.0, 1.0, 1.0),
    }

    properties[CaptainUtility.ClassType.Commodore] =
    {
        displayName = "Commodore /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Commodore /* Captain Class of a female captain*/"%_t,
        untranslatedName = "Commodore /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Commodore /* Captain Class of a female captain*/"%_T,
        description = "The captain has already collected experience working as a commodore. He has already commanded smaller fleets and made a name for himself. Enemies think twice before attacking him. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain has already collected experience working as a commodore. She has already commanded smaller fleets and made a name for herself. Enemies think twice before attacking her. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-commodore.png",
        tooltipIcon = "data/textures/ui/captain/symbol-commodore-black-bg.png",
        center = "data/textures/ui/captain/center-turquoise-shaded.png",
        ring = "data/textures/ui/captain/ring-turquoise-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(1.0, 1.0, 1.0),
        primaryColor = ColorRGB(0.0, 0.75, 0.75),
        secondaryColor = ColorRGB(0.6, 0.75, 0.75),
    }

    properties[CaptainUtility.ClassType.Smuggler] =
    {
        displayName = "Smuggler /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Smuggler /* Captain Class of a female captain */"%_t,
        untranslatedName = "Smuggler /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Smuggler /* Captain Class of a female captain */"%_T,
        description = "The captain has chosen to become a smuggler. As an expert in shady deals and moving goods of all kinds, he can trade and transport all goods. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain has chosen to become a smuggler. As an expert in shady deals and moving goods of all kinds, she can trade and transport all goods. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-smuggler.png",
        tooltipIcon = "data/textures/ui/captain/symbol-smuggler-black-bg.png",
        center = "data/textures/ui/captain/center-violet-shaded.png",
        ring = "data/textures/ui/captain/ring-violet-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(1.0, 1.0, 1.0),
        primaryColor = ColorRGB(0.75, 0.0, 0.75),
        secondaryColor = ColorRGB(0.75, 0.35, 0.75),
    }

    properties[CaptainUtility.ClassType.Merchant] =
    {
        displayName = "Merchant /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Merchant /* Captain Class of a female captain */"%_t,
        untranslatedName = "Merchant /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Merchant /* Captain Class of a female captain */"%_T,
        description = "The captain is excellent at trading. He is gifted with superior powers of persuasion which allows him to ensure the best deals, and he doesn't need licenses for dangerous goods. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain is excellent at trading. She is gifted with superior powers of persuasion which allows her to ensure the best deals, and she doesn't need licenses for dangerous goods. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-merchant.png",
        tooltipIcon = "data/textures/ui/captain/symbol-merchant-black-bg.png",
        center = "data/textures/ui/captain/center-green-shaded.png",
        ring = "data/textures/ui/captain/ring-green-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(1.0, 1.0, 1.0),
        primaryColor = ColorRGB(0.5, 0.8, 0.0),
        secondaryColor = ColorRGB(0.6, 0.75, 0.6),
    }

    properties[CaptainUtility.ClassType.Miner] =
    {
        displayName = "Miner /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Miner /* Captain Class of a female captain */"%_t,
        untranslatedName = "Miner /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Miner /* Captain Class of a female captain */"%_T,
        description = "The captain is an experienced miner. He is blessed with a good eye for rocks which increases his profits when mining. His experience allows him to perform longer mining operations. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain is an experienced miner. She is blessed with a good eye for rocks which increases her profits when mining. Her experience allows her to perform longer mining operations. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-miner.png",
        tooltipIcon = "data/textures/ui/captain/symbol-miner-black-bg.png",
        center = "data/textures/ui/captain/center-white-shaded.png",
        ring = "data/textures/ui/captain/ring-grey-shaded.png",

        centerColor = ColorRGB(0.6, 0.4, 0.12),
        ringColor = ColorRGB(0.8, 0.5, 0.16),
        primaryColor = ColorRGB(0.8, 0.5, 0.16),
        secondaryColor = ColorRGB(0.8, 0.6, 0.4),
    }

    properties[CaptainUtility.ClassType.Scavenger] =
    {
        displayName = "Scavenger /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Scavenger /* Captain Class of a female captain */"%_t,
        untranslatedName = "Scavenger /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Scavenger /* Captain Class of a female captain */"%_T,
        description = "The captain is a passionate scavenger. As a result, he knows a lot about scrap and metals which increases his profits when scrapping and allows him to perform longer scrapping operations. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain is a passionate scavenger. As a result, she knows a lot about scrap and metals which increases her profits when scrapping and allows her to perform longer scrapping operations. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-scavenger.png",
        tooltipIcon = "data/textures/ui/captain/symbol-scavenger-black-bg.png",
        center = "data/textures/ui/captain/center-blue-shaded.png",
        ring = "data/textures/ui/captain/ring-blue-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(1.0, 1.0, 1.0),
        primaryColor = ColorRGB(0.1, 0.5, 1.0),
        secondaryColor = ColorRGB(0.4, 0.6, 1.0),
    }

    properties[CaptainUtility.ClassType.Explorer]  =
    {
        displayName = "Explorer /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Explorer /* Captain Class of a female captain */"%_t,
        untranslatedName = "Explorer /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Explorer /* Captain Class of a female captain */"%_T,
        description = "The captain is an explorer. He has made it his mission to explore the galaxy and collect as much data as possible. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain is an explorer. She has made it her mission to explore the galaxy and collect as much data as possible. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-explorer.png",
        tooltipIcon = "data/textures/ui/captain/symbol-explorer-black-bg.png",
        center = "data/textures/ui/captain/center-white-shaded.png",
        ring = "data/textures/ui/captain/ring-yellow-shaded.png",

        centerColor = ColorRGB(0.9, 0.8, 0.0),
        ringColor = ColorRGB(1.0, 1.0, 1.0),
        primaryColor = ColorRGB(0.9, 0.8, 0.0),
        secondaryColor = ColorRGB(0.9, 0.85, 0.5),
    }

    properties[CaptainUtility.ClassType.Daredevil] =
    {
        displayName = "Daredevil /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Daredevil /* Captain Class of a female captain */"%_t,
        untranslatedName = "Daredevil /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Daredevil /* Captain Class of a female captain */"%_T,
        description = "The captain is a daredevil. Somehow, he always ends up in trouble. But nothing can keep him down for long, and he likes to share any loot he collects with his allies. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain is a daredevil. Somehow, she always ends up in trouble. But nothing can keep her down for long, and she likes to share any loot she collects with her allies. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-daredevil.png",
        tooltipIcon = "data/textures/ui/captain/symbol-daredevil-black-bg.png",
        center = "data/textures/ui/captain/center-red-shaded.png",
        ring = "data/textures/ui/captain/ring-red-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(0.9, 0.9, 0.9),
        primaryColor = ColorRGB(0.8, 0.1, 0.1),
        secondaryColor = ColorRGB(0.8, 0.35, 0.35),
    }

    properties[CaptainUtility.ClassType.Scientist] =
    {
        displayName = "Scientist /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Scientist /* Captain Class of a female captain */"%_t,
        untranslatedName = "Scientist /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Scientist /* Captain Class of a female captain */"%_T,
        description = "As a Scientist, this captain is part of a guild that wants to explore Rifts. While inside subspace rifts, he will collect valuable data that can be sold or exchanged for special equipment. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "As a Scientist, this captain is part of a guild that wants to explore Rifts. While inside subspace rifts, she will collect valuable data that can be sold or exchanged for special equipment. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-scientist.png",
        tooltipIcon = "data/textures/ui/captain/symbol-scientist-black-bg.png",
        center = "data/textures/ui/captain/center-orange-shaded.png",
        ring = "data/textures/ui/captain/ring-orange-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(0.9, 0.9, 0.9),
        primaryColor = ColorRGB(1.0, 0.6, 0.45),
        secondaryColor = ColorRGB(0.9, 0.5, 0.3),
    }

    properties[CaptainUtility.ClassType.Hunter] =
    {
        displayName = "Xsotan Hunter /* Captain Class of a male captain */"%_t,
        displayNameFemale = "Xsotan Hunter /* Captain Class of a female captain */"%_t,
        untranslatedName = "Xsotan Hunter /* Captain Class of a male captain */"%_T,
        untranslatedNameFemale = "Xsotan Hunter /* Captain Class of a female captain */"%_T,
        description = "As a Xsotan Hunter, this captain devoted his life to fight against the Xsotan. He has exceptional knowledge of Rifts and attracting rare Xsotan types. While inside subspace rifts, he'll attract special Xsotan that will give you special rewards. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "As a Xsotan Hunter, this captain devoted her life to fight against the Xsotan. She has exceptional knowledge of Rifts and attracting rare Xsotan types. While inside subspace rifts, she'll attract special Xsotan that will give you special rewards. /* sentence referring to a female captain */"%_t,

        icon = "data/textures/ui/captain/symbol-hunter.png",
        tooltipIcon = "data/textures/ui/captain/symbol-hunter-black-bg.png",
        center = "data/textures/ui/captain/center-olive-shaded.png",
        ring = "data/textures/ui/captain/ring-olive-shaded.png",

        centerColor = ColorRGB(1.0, 1.0, 1.0),
        ringColor = ColorRGB(0.9, 0.9, 0.9),
        primaryColor = ColorRGB(0.4, 0.5, 0.3),
        secondaryColor = ColorRGB(0.55, 0.55, 0.35),
    }

    return properties
end


-- DO NOT INTERCHANGE THESE, THEY GET SAVED INTO DATABASE
CaptainUtility.PerkType =
{
    -- 0 is reserved
    Educated = 1,
    Humble = 2,
    Reckless = 3,
    Connected = 4,
    Navigator = 5,
    Stealthy = 6,
    MarketExpert = 7,
    Uneducated = 8,
    Greedy = 9,
    Careful = 10,
    Disoriented = 11,
    Gambler = 12,
    Addict = 13,
    Intimidating = 14,
    Arrogant = 15,
    Cunning = 16,
    Harmless = 17,
    Noble = 18,
    Commoner = 19,
    Lucky = 20,
    Unlucky = 21,
}

function CaptainUtility.PerkProperties()
    local properties = {}

    properties[CaptainUtility.PerkType.Educated] =
    {
        displayName = "Educated /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Educated /* Captain Perk Type of a female captain*/"%_t,
        description = "The captain is highly educated and will learn new things very quickly. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain is highly educated and will learn new things very quickly. /* sentence referring to a female captain */"%_t,
        summary = "Gains more experience when fulfilling commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Humble] =
    {
        displayName = "Humble /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Humble /* Captain Perk Type of a female captain*/"%_t,
        description = "Out of modesty, this captain demands less payment./* sentence referring to a male captain */"%_t,
        descriptionFemale = "Out of modesty, this captain demands less payment./* sentence referring to a female captain */"%_t,
        summary = "Demands lower salary "%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Reckless] =
    {
        displayName = "Reckless /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Reckless /* Captain Perk Type of a female captain*/"%_t,
        description = "Due to his ruthlessness, this captain is more likely to be attacked, but he also manages to travel through the galaxy faster. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "Due to her ruthlessness, this captain is more likely to be attacked, but she also manages to travel through the galaxy faster. /* sentence referring to a female captain */"%_t,
        summary = "Higher risk of being ambushed, faster completion of commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Connected] =
    {
        displayName = "Connected /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Connected /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain can negotiate significantly better prices thanks to his connections. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain can negotiate significantly better prices thanks to her connections. /* sentence referring to a female captain */"%_t,
        summary = "Negotiates better prices"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Navigator] =
    {
        displayName = "Navigator /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Navigator /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain has excellent knowledge of the galaxy. He finds what he is looking for much faster than others. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain has excellent knowledge of the galaxy. She finds what she is looking for much faster than others. /* sentence referring to a female captain */"%_t,
        summary = "Faster completion of commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Stealthy] =
    {
        displayName = "Stealthy /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Stealthy /* Captain Perk Type of a female captain*/"%_t,
        description = "The captain remains under the radar and is therefore less likely to be spotted by enemies. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain remains under the radar and is therefore less likely to be spotted by enemies. /* sentence referring to a female captain */"%_t,
        summary = "Lower risk of being ambushed"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.MarketExpert] =
    {
        displayName = "Market Expert /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Market Expert /* Captain Perk Type of a female captain*/"%_t,
        description = "The captain is familiar with the market and prices in the galaxy. He always finds the best offers. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The captain is familiar with the market and prices in the galaxy. She always finds the best offers. /* sentence referring to a female captain */"%_t,
        summary = "Higher profits and faster completion of trade commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Uneducated] =
    {
        displayName = "Uneducated /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Uneducated /* Captain Perk Type of a female captain*/"%_t,
        description = "The lack of education of this captain means that he learns much more slowly than others. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The lack of education of this captain means that she learns much more slowly than others. /* sentence referring to a female captain */"%_t,
        summary = "Gains less experience when fulfilling commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Greedy] =
    {
        displayName = "Greedy /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Greedy /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain is so greedy that he is not satisfied with the normal salary but always wants a bonus. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain is so greedy that she is not satisfied with the normal salary but always wants a bonus. /* sentence referring to a female captain */"%_t,
        summary = "Demands higher salary"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Careful] =
    {
        displayName = "Careful /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Careful /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain is very careful and is therefore less likely to be attacked, but slower when executing commands. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain is very careful and is therefore less likely to be attacked, but slower when executing commands. /* sentence referring to a female captain */"%_t,
        summary = "Lower risk of being ambushed, slower completion of commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Disoriented] =
    {
        displayName = "Disoriented /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Disoriented /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain has a tendency to get lost in the vastness of the galaxy. It takes him significantly longer to execute commands successfully. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain has a tendency to get lost in the vastness of the galaxy. It takes her significantly longer to execute commands successfully. /* sentence referring to a female captain */"%_t,
        summary = "Slower completion of commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Gambler] =
    {
        displayName = "Gambler /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Gambler /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain has a gambling problem. He always has debts, which he tries to pay back using the budget of commands, among other things, even if it is not his. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain has a gambling problem. She always has debts, which she tries to pay back using the budget of commands, among other things, even if it is not hers. /* sentence referring to a female captain */"%_t,
        summary = "Reduced profits, smaller yields when refining"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Addict] =
    {
        displayName = "Addict /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Addict /* Captain Perk Type of a female captain*/"%_t,
        description = "He enjoys his nights of partying a little too much. The obligatory hangover slows down everything he does. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "She enjoys her nights of partying a little too much. The obligatory hangover slows down everything she does. /* sentence referring to a female captain */"%_t,
        summary = "Slower completion of commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Intimidating] =
    {
        displayName = "Intimidating /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Intimidating /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain looks very menacing. Potential enemies avoid him, and traders prefer getting a worse deal over messing with him. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain looks very menacing. Potential enemies avoid her, and traders prefer getting a worse deal over messing with her. /* sentence referring to a female captain */"%_t,
        summary = "Lower risk of being ambushed, reduced costs for commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Arrogant] =
    {
        displayName = "Arrogant /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Arrogant /* Captain Perk Type of a female captain*/"%_t,
        description = "The arrogant demeanor of this captain regularly provokes angry attacks on him. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "The arrogant demeanor of this captain regularly provokes angry attacks on her. /* sentence referring to a female captain */"%_t,
        summary = "Higher risk of being ambushed"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Cunning] =
    {
        displayName = "Cunning /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Cunning /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain usually manages to evade his enemies. If they do manage to catch him, they attack in large groups. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain usually manages to evade her enemies. If they do manage to catch her, they attack in large groups. /* sentence referring to a female captain */"%_t,
        summary = "Lower risk of being ambushed, increased strength of enemies"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Harmless] =
    {
        displayName = "Harmless /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Harmless /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain seems very harmless. Therefore, he gets attacked frequently, but most of those attackers are easily dealt with. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain seems very harmless. Therefore, she gets attacked frequently, but most of those attackers are easily dealt with. /* sentence referring to a female captain */"%_t,
        summary = "Higher risk of being ambushed, reduced strength of enemies"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Noble] =
    {
        displayName = "Noble /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Noble /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain's family has always put much emphasis on military training. His openly displayed prosperity causes traders to raise their prices. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain's family has always put much emphasis on military training. Her openly displayed prosperity causes traders to raise their prices. /* sentence referring to a female captain */"%_t,
        summary = "Lower risk of being ambushed, reduced profits"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Commoner] =
    {
        displayName = "Commoner /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Commoner /* Captain Perk Type of a female captain*/"%_t,
        description = "This captain's family has had to work their way up through honest trade. The captain has good negotiating talents, but very little skill when it comes to fighting. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "This captain's family has had to work their way up through honest trade. The captain has good negotiating talents, but very little skill when it comes to fighting. /* sentence referring to a female captain */"%_t,
        summary = "Increased risk of being ambushed, increased profits"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Lucky] =
    {
        displayName = "Lucky /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Lucky /* Captain Perk Type of a female captain*/"%_t,
        description = "Downright pursued by luck, this captain keeps stumbling over lost objects, which he sometimes shares with his client. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "Downright pursued by luck, this captain keeps stumbling over lost objects, which she sometimes shares with her client. /* sentence referring to a female captain */"%_t,
        summary = "May find turrets or subsystems"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }
    properties[CaptainUtility.PerkType.Unlucky] =
    {
        displayName = "Unlucky /* Captain Perk Type of a male captain*/"%_t,
        displayNameFemale = "Unlucky /* Captain Perk Type of a female captain*/"%_t,
        description = "Bad luck sticks to this captain. Again and again he collides with asteroids or damages the ship in other ways. /* sentence referring to a male captain */"%_t,
        descriptionFemale = "Bad luck sticks to this captain. Again and again she collides with asteroids or damages the ship in other ways. /* sentence referring to a female captain */"%_t,
        summary = "Ship may suffer damages while on commands"%_t,
        color = ColorRGB(0.9, 0.9, 0.9)
    }

    return properties
end

function CaptainUtility.makeTooltip(captain, commandType)
    local iconColor = ColorRGB(0.5, 0.5, 0.5)

    local headLineSize = 25
    local headLineFont = 15

    local tooltip = Tooltip()

    local classProperties = CaptainUtility.ClassProperties()
    local primary = classProperties[captain.primaryClass]
    local secondary = classProperties[captain.secondaryClass]

    -- create tooltip
    tooltip.icon = primary.icon
    tooltip.price = captain.salary

    -- head line
    local line = TooltipLine(headLineSize, headLineFont)
    if captain.genderId == CaptainGenderId.Male then
        line.ctext = "Captain /*male*/"%_t
    else
        line.ctext = "Captain /*female*/"%_t
    end
    tooltip:addLine(line)

    -- class name
    local classDescription

    if captain.genderId == CaptainGenderId.Male then
        classDescription = "Tier ${tier} ${captainclass} /* Resolves to something like 'Tier 3 Smuggler' */"%_t
                                    % {tier = captain.tier, captainclass = primary.displayName}
    else
        classDescription = "Tier ${tier} ${captainclass} /* Resolves to something like 'Tier 3 Smuggler' */"%_t
                                    % {tier = captain.tier, captainclass = primary.displayNameFemale}
    end

    if classDescription ~= "" then
        local line = TooltipLine(15, 12)
        line.ctext = string.upper(classDescription)
        line.ccolor = primary.primaryColor
        tooltip:addLine(line)
    end

    if captain.tier == 0 and captain.level < 4 then
        local line = TooltipLine(15, 10)
        line.ctext = "Specializes when reaching level 5"%_t
        line.ccolor = ColorRGB(0.8, 0.8, 0.8),
        tooltip:addLine(line)
    end

    local fontSize = 13;
    local lineHeight = 16;

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    if secondary.displayName ~= "" then

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Secondary Class"%_t

        if captain.genderId == CaptainGenderId.Male then
            line.rtext = secondary.displayName
        else
            line.rtext = secondary.displayNameFemale
        end

        line.rcolor = secondary.primaryColor
        line.icon = "data/textures/icons/captain.png";
        line.iconColor = secondary.secondaryColor
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Name"%_t

    line.rtext = captain.displayName

    line.icon = "data/textures/icons/captain.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    if captain.factionIndex ~= 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Faction Affiliation"%_t
        line.rtext = "${faction:"..captain.factionIndex.."}"
        line.icon = "data/textures/icons/captain.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Tier"%_t
    line.rtext = captain.tier
    line.icon = "data/textures/icons/captain.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    local classLinesAdded

    -- Commodore gives +armed turrets
    if captain:hasClass(CaptainClass.Commodore) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Armed Turret Slots"%_t
        line.rtext = "+2"
        line.icon = "data/textures/icons/turret.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Auto-Turret Slots"%_t
        line.rtext = "+4"
        line.icon = "data/textures/icons/turret.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    -- Scavenger gives +mining turrets and detects hidden asteroids
    if captain:hasClass(CaptainClass.Scavenger) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Unarmed Turret Slots"%_t
        line.rtext = "+2"
        line.icon = "data/textures/icons/turret.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Highlights"%_t
        line.rtext = "Valuable Wreckage"%_t
        line.icon = "data/textures/icons/indicator.png";
        line.iconColor = ColorRGB(1, 1, 1)
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Salvaging Duration"%_t
        line.rtext = string.format("%+gh", 0.5 + captain.tier + captain.level * 0.5)
        line.icon = "data/textures/icons/hourglass.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    -- Miner gives +unarmed turrets and detects valuable wreckages
    if captain:hasClass(CaptainClass.Miner) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Unarmed Turret Slots"%_t
        line.rtext = "+2"
        line.icon = "data/textures/icons/turret.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Highlights"%_t
        line.rtext = "Hidden Ores"%_t
        line.icon = "data/textures/icons/indicator.png";
        line.iconColor = ColorRGB(1, 1, 1)
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Mining Duration"%_t
        line.rtext = string.format("%+gh", 0.5 + captain.tier + captain.level * 0.5)
        line.icon = "data/textures/icons/hourglass.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    -- Explorer gives +hidden sector radar reach
    if captain:hasClass(CaptainClass.Explorer) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Deep Scan Range"%_t
        line.rtext = "+3"
        line.icon = "data/textures/icons/radar-sweep.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    -- Daredevil gives +fire rate
    if captain:hasClass(CaptainClass.Daredevil) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Turret Fire Rate"%_t
        line.rtext = "+10%"
        line.icon = "data/textures/icons/bullets.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    -- Smuggler has a "License" for everything
    if captain:hasClass(CaptainClass.Smuggler) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Cargo \"License\""%_t
        line.rtext = "Everything"%_t
        line.icon = "data/textures/icons/crate.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    -- Merchant has a "License" for dangerous and suspicious goods
    if captain:hasClass(CaptainClass.Merchant) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Cargo License"%_t
        line.rtext = "Suspicious"%_t
        line.icon = "data/textures/icons/crate.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = ""
        line.rtext = "Dangerous"%_t
        line.icon = "data/textures/icons/nothing.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    -- Scientists help getting out of rifts and finding points of interest in rifts
    if captain:hasClass(CaptainClass.Scientist) then
        tooltip:addLine(TooltipLine(8, 8))

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Rift Research"%_t
        line.rtext = "Yes"%_t
        line.icon = "data/textures/icons/info-chip.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        local line = TooltipLine(15, 11)
        line.ltext = "Collects Research Data in Rifts"
        line.icon = "data/textures/icons/nothing.png"
        line.lcolor = ColorRGB(0.5, 0.5, 0.5)
        line.fontType = FontType.Normal
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize-1)
        line.ltext = "Data Gathered"%_t
        line.rtext = "Every ${interval}s"%_t % {interval = 80 - (captain.tier + captain.level) * 5}
        line.icon = "data/textures/icons/info-chip.png";
        line.iconColor = iconColor
        line.fontType = FontType.Normal
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize-1)
        line.ltext = "Data Dropped"%_t
        line.rtext = "+200%"%_t
        line.icon = "data/textures/icons/info-chip.png";
        line.iconColor = iconColor
        line.fontType = FontType.Normal
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize-1)
        line.ltext = "Highlights"
        line.rtext = "Rift Research Data"%_t
        line.icon = "data/textures/icons/indicator.png";
        line.iconColor = iconColor
        line.fontType = FontType.Normal
        tooltip:addLine(line)


        classLinesAdded = true
    end

    -- Xsotan Hunters motivate crew and attract special xsotan
    if captain:hasClass(CaptainClass.Hunter) then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Attracts Rare Rift Xsotan"%_t
        line.rtext = "Yes"%_t
        line.icon = "data/textures/icons/james-bond-aperture.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Rare Rift Xsotan Loot"%_t
        line.rtext = "Yes"%_t
        line.icon = "data/textures/icons/turret.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        classLinesAdded = true
    end

    if classLinesAdded then
        tooltip:addLine(TooltipLine(8, 8))
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Level"%_t
    line.rtext = captain.level + 1
    line.icon = "data/textures/icons/captain.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    if captain.level < 5 then
        local line = TooltipLine(lineHeight-2, fontSize-1)
        line.ltext = "EXP Progress"%_t
        line.rtext = captain.experiencePercentage .. "%"
        line.icon = "data/textures/icons/nothing.png";
        line.iconColor = iconColor
        line.lcolor = ColorRGB(0.75, 0.75, 0.75)
        line.rcolor = ColorRGB(0.75, 0.75, 0.75)
        line.fontType = FontType.Normal
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Salary"%_t
    line.rtext = "${salary}¢" % {salary = createMonetaryString(captain.salary)}
    line.icon = "data/textures/icons/captain.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    if commandType then
        if captain.primaryClass ~= CaptainUtility.ClassType.None then
            -- empty line
            tooltip:addLine(TooltipLine(8, 8))

            local line = TooltipLine(lineHeight, fontSize)

            if captain.genderId == CaptainGenderId.Male then
                line.ltext = primary.displayName
            else
                line.ltext = primary.displayNameFemale
            end

            line.lcolor = primary.primaryColor
            line.icon = "data/textures/icons/captain.png";
            line.iconColor = primary.primaryColor
            line.fontType = FontType.Normal
            tooltip:addLine(line)

            local line = TooltipLine(lineHeight-2, fontSize-1)
            line.ltext = CaptainUtility.getCaptainClassSummary(captain.primaryClass, commandType)
            line.icon = "data/textures/icons/nothing.png";
            line.iconColor = iconColor
            line.fontType = FontType.Normal
            tooltip:addLine(line)
        end

        if captain.secondaryClass and captain.secondaryClass ~= CaptainUtility.ClassType.None then
            -- empty line
            tooltip:addLine(TooltipLine(8, 8))

            local line = TooltipLine(lineHeight, fontSize)

            if captain.genderId == CaptainGenderId.Male then
                line.ltext = secondary.displayName
            else
                line.ltext = secondary.displayNameFemale
            end

            line.lcolor = secondary.primaryColor
            line.icon = "data/textures/icons/captain.png";
            line.iconColor = secondary.primaryColor
            line.fontType = FontType.Normal
            tooltip:addLine(line)

            local line = TooltipLine(lineHeight-2, fontSize-1)
            line.ltext = CaptainUtility.getCaptainClassSummary(captain.secondaryClass, commandType)
            line.icon = "data/textures/icons/nothing.png";
            line.iconColor = iconColor
            line.fontType = FontType.Normal
            tooltip:addLine(line)
        end
    end

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    local icons = {"data/textures/ui/captain/ring-black-bg.png", primary.tooltipIcon}

    if captain.level == 1 then
        table.insert(icons, "data/textures/ui/captain/star-black-bg.png")
    elseif captain.level == 2 then
        table.insert(icons, "data/textures/ui/captain/star2-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star3-black-bg.png")
    elseif captain.level == 3 then
        table.insert(icons, "data/textures/ui/captain/star-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star2-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star3-black-bg.png")
    elseif captain.level == 4 then
        table.insert(icons, "data/textures/ui/captain/star2-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star3-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star4-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star5-black-bg.png")
    elseif captain.level == 5 then
        table.insert(icons, "data/textures/ui/captain/star-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star2-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star3-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star4-black-bg.png")
        table.insert(icons, "data/textures/ui/captain/star5-black-bg.png")
    end

    if captain.tier >= 1 then
        table.insert(icons, "data/textures/ui/captain/wing2-black-bg.png")
    end

    if captain.tier >= 2 then
        table.insert(icons, "data/textures/ui/captain/wing3-black-bg.png")
    end

    if captain.tier >= 3 then
        table.insert(icons, "data/textures/ui/captain/wing1-black-bg.png")
    end

    tooltip:setIcons(unpack(icons))
    tooltip.borderColor = primary.primaryColor
    tooltip.backgroundFadeColor = primary.primaryColor

    local numPerks = 0
    local perkProperties = CaptainUtility.PerkProperties()
    for _, perk in pairs({captain:getPerks()}) do
        local fontSize = 11
        local lineHeight = 15

        local properties = perkProperties[perk]

        local line = TooltipLine(lineHeight, fontSize)

        if captain.genderId == CaptainGenderId.Male then
            line.ltext = properties.displayName
        else
            line.ltext = properties.displayNameFemale
        end

        line.icon = "data/textures/icons/captain.png";
        line.iconColor = iconColor
        line.fontType = FontType.Normal
        tooltip:addLine(line)

        local summaryLine = CaptainUtility.makePerkSummaryLine(captain, perk, commandType, properties)
        tooltip:addLine(summaryLine)

        numPerks = numPerks + 1
    end

    for i = 1, 2 - numPerks do
        tooltip:addLine(TooltipLine(15, 11))
        tooltip:addLine(TooltipLine(15, 11))
    end

    replaceTooltipFactionNames(tooltip)

    return tooltip
end

function CaptainUtility.makeCredentialsWindow(captain, yesNoWindow)
    local window = {}

    local res = getResolution()
    local size = vec2(320, 400)

    if yesNoWindow then
        size = vec2(320, 450)
    end

    window = Hud():createWindow(Rect(size))

    window.caption = "Captain's Certificate"%_t
    window.moveable = true
    window:center()

    local hsplitBottom = UIHorizontalSplitter(Rect(size), 10, 10, 0.5)
    if yesNoWindow then
        -- two options
        hsplitBottom.bottomSize = 100
        local hsplit = UIHorizontalSplitter(hsplitBottom.bottom, 10, 10, 0.5)
        window:createButton(hsplit.top, "Accept"%_t, "onAcceptPressed")
        window:createButton(hsplit.bottom, "Decline"%_t, "onDeclinePressed")
    else
        -- close button => reopens dialog where player can decide
        hsplitBottom.bottomSize = 40
        window:createButton(hsplitBottom.bottom, "Close"%_t, "onClosePressed")
    end

    -- icon
    local hsplitTop = UIHorizontalSplitter(hsplitBottom.top, 10, 10, 0.5)
    hsplitTop.topSize = 120
    local captainRect = hsplitTop.top
    captainRect.height = captainRect.height + 30
    captainRect.width = captainRect.height
    local icon = window:createCaptainIcon(captainRect)
    icon:setCaptain(captain)

    -- captain stats
    local classProperties = CaptainUtility.ClassProperties()
    local primary = classProperties[captain.primaryClass]
    local secondary = classProperties[captain.secondaryClass]
    local classDescription = "Tier ${tier} ${captainclass} /* Resolves to something like 'Tier 3 Smuggler' */"%_t
                                % {tier = captain.tier, captainclass = primary.displayName}

    local statSplit = UIVerticalLister(hsplitTop.bottom, 0, 0)
    local classLabel = window:createLabel(statSplit:nextRect(15), string.upper(classDescription), 14)
    classLabel:setCenterAligned()
    classLabel.color = primary.primaryColor

    statSplit:nextRect(15) -- empty line

    -- name
    local vsplit = UIVerticalSplitter(statSplit:nextRect(15), 10, 10, 0.5)
    local labelLeft = window:createLabel(vsplit.left, "Name:"%_t, 12)
    labelLeft:setLeftAligned()
    local labelRight = window:createLabel(vsplit.right, captain.name, 12)
    labelRight:setRightAligned()

    statSplit:nextRect(15) -- empty line

    -- primary class
    local vsplit = UIVerticalSplitter(statSplit:nextRect(15), 10, 10, 0.5)
    local labelLeft = window:createLabel(vsplit.left, "Primary:"%_t, 12)
    labelLeft:setLeftAligned()
    local labelRight = window:createLabel(vsplit.right, primary.displayName, 12)
    labelRight:setRightAligned()

    -- secondary class
    local vsplit = UIVerticalSplitter(statSplit:nextRect(15), 10, 10, 0.5)
    local labelLeft = window:createLabel(vsplit.left, "Secondary:"%_t, 12)
    labelLeft:setLeftAligned()
    local labelRight = window:createLabel(vsplit.right, secondary.displayName, 12)
    labelRight:setRightAligned()

    statSplit:nextRect(15) -- empty line

    -- tier
    local vsplit = UIVerticalSplitter(statSplit:nextRect(15), 10, 10, 0.5)
    local labelLeft = window:createLabel(vsplit.left, "Tier:"%_t, 12)
    labelLeft:setLeftAligned()
    local labelRight = window:createLabel(vsplit.right, captain.tier, 12)
    labelRight:setRightAligned()

    -- level
    local vsplit = UIVerticalSplitter(statSplit:nextRect(15), 10, 10, 0.5)
    local labelLeft = window:createLabel(vsplit.left, "Level:"%_t, 12)
    labelLeft:setLeftAligned()
    local labelRight = window:createLabel(vsplit.right, captain.level + 1, 12)
    labelRight:setRightAligned()

    statSplit:nextRect(15) -- empty line
    statSplit:nextRect(15) -- empty line

    -- expected salary?
    local vsplit = UIVerticalSplitter(statSplit:nextRect(15), 10, 10, 0.5)
    local labelLeft = window:createLabel(vsplit.left, "Expected Salary:"%_t, 12)
    labelLeft:setLeftAligned()
    local labelRight = window:createLabel(vsplit.right, string.format("¢%s", createMonetaryString(captain.salary)), 12)
    labelRight:setRightAligned()

    return window
end

function CaptainUtility.generateLuckyFinishingItems(items, captain, coordinates, duration)
    items = items or {}
    duration = duration or 1

    -- captain can only be lucky after being away for 9 minutes to prevent exploit by immediate recall (shortest regular command is 10 minutes)
    local minimumDuration = 9 / 60

    -- chance increases the longer the captain is on their way
    local chance = lerp(duration, 0, 3, 0.3, 1.0)

    -- there's a chance for each level of the captain to drop an item
    for i = 0, captain.level do
        if duration >= minimumDuration and random():test(chance) then

            local item = {}
            item.x = coordinates.x
            item.y = coordinates.y
            item.seed = tostring(random():createSeed())

            if random():test(0.5) then
                items.turrets = items.turrets or {}
                table.insert(items.turrets, item)
            else
                items.subsystems = items.subsystems or {}
                table.insert(items.subsystems, item)
            end

            -- diminish drop chance a little for each drop
            -- we want the chances to not be 100% for each drop after 3h
            chance = chance - 0.1
        end
    end

    return items
end

function CaptainUtility.setRequiredLevelUpExperience(captain)
    local experiences = {}
    experiences[0] = 50
    experiences[1] = 100
    experiences[2] = 150
    experiences[3] = 200
    experiences[4] = 250
    experiences[5] = 300

    local fallback = 350
    captain.requiredLevelUpExperience = experiences[captain.level] or fallback

    return captain
end

function CaptainUtility.applyLeveling(captain, minutesAway)

    -- adds some robustness to the leveling process
    CaptainUtility.setRequiredLevelUpExperience(captain)

    local gain = math.max(0, minutesAway) / 2
    if captain:hasPerk(CaptainUtility.PerkType.Educated) then gain = gain * 1.2 end
    if captain:hasPerk(CaptainUtility.PerkType.Uneducated) then gain = gain * 0.9 end

    local experience = captain.experience + gain

    if experience >= captain.requiredLevelUpExperience then
        if captain.level < 5 then
            captain.level = captain.level + 1
            captain.experience = 0
            CaptainUtility.setRequiredLevelUpExperience(captain)
        end
    else
        captain.experience = experience
    end

    return captain
end

function CaptainUtility.getMiningPerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 20
    navigatorImpacts[1] = 30
    navigatorImpacts[2] = 40
    navigatorImpacts[3] = 50
    navigatorImpacts[4] = 60
    navigatorImpacts[5] = 70

    local recklessImpacts = {}
    recklessImpacts[0] = 20
    recklessImpacts[1] = 30
    recklessImpacts[2] = 40
    recklessImpacts[3] = 50
    recklessImpacts[4] = 60
    recklessImpacts[5] = 70

    local carefulImpacts = {}
    carefulImpacts[0] = 75
    carefulImpacts[1] = 65
    carefulImpacts[2] = 65
    carefulImpacts[3] = 45
    carefulImpacts[4] = 35
    carefulImpacts[5] = 25

    local disorientedImpacts = {}
    disorientedImpacts[0] = 70
    disorientedImpacts[1] = 60
    disorientedImpacts[2] = 50
    disorientedImpacts[3] = 40
    disorientedImpacts[4] = 30
    disorientedImpacts[5] = 20

    local addictImpacts = {}
    addictImpacts[0] = 70
    addictImpacts[1] = 60
    addictImpacts[2] = 50
    addictImpacts[3] = 40
    addictImpacts[4] = 30
    addictImpacts[5] = 20

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction in time
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction in time
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase in time
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase in time
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase in time
    elseif perk == CaptainUtility.PerkType.Gambler then
        return -0.1 -- reduced ressources
    elseif perk == CaptainUtility.PerkType.Commoner then
        return 0.5 -- reduced refinetax
    elseif perk == CaptainUtility.PerkType.Noble then
        return 2 -- increased refinetax
    elseif perk == CaptainUtility.PerkType.Connected then
        return 0.5 -- reduced refinetax
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getSalvagingPerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 20
    navigatorImpacts[1] = 30
    navigatorImpacts[2] = 40
    navigatorImpacts[3] = 50
    navigatorImpacts[4] = 60
    navigatorImpacts[5] = 70

    local recklessImpacts = {}
    recklessImpacts[0] = 20
    recklessImpacts[1] = 30
    recklessImpacts[2] = 40
    recklessImpacts[3] = 50
    recklessImpacts[4] = 60
    recklessImpacts[5] = 70

    local carefulImpacts = {}
    carefulImpacts[0] = 75
    carefulImpacts[1] = 65
    carefulImpacts[2] = 65
    carefulImpacts[3] = 45
    carefulImpacts[4] = 35
    carefulImpacts[5] = 25

    local disorientedImpacts = {}
    disorientedImpacts[0] = 70
    disorientedImpacts[1] = 60
    disorientedImpacts[2] = 50
    disorientedImpacts[3] = 40
    disorientedImpacts[4] = 30
    disorientedImpacts[5] = 20

    local addictImpacts = {}
    addictImpacts[0] = 70
    addictImpacts[1] = 60
    addictImpacts[2] = 50
    addictImpacts[3] = 40
    addictImpacts[4] = 30
    addictImpacts[5] = 20

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Commoner then
        return 0.5
    elseif perk == CaptainUtility.PerkType.Noble then
        return 2
    elseif perk == CaptainUtility.PerkType.Connected then
        return 0.5
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getRefineTimePerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.02
    navigatorImpacts[1] = 0.06
    navigatorImpacts[2] = 0.10
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.20
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.10
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.20
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.30
    recklessImpacts[5] = 0.35

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.12
    carefulImpacts[2] = 0.10
    carefulImpacts[3] = 0.07
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.03

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.12
    disorientedImpacts[1] = 0.10
    disorientedImpacts[2] = 0.07
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.02
    disorientedImpacts[5] = 0.0

    local addictImpacts = {}
    addictImpacts[0] = 0.12
    addictImpacts[1] = 0.10
    addictImpacts[2] = 0.07
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.02
    addictImpacts[5] = 0.0

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    end

    return 0 -- fallback
end

function CaptainUtility.getRefineTaxPerkImpact(captain, perk)
    if perk == CaptainUtility.PerkType.Noble then
        return 2.0 -- increase multiplicator
    elseif perk == CaptainUtility.PerkType.Commoner then
        return 0.5 -- reduction multiplicator
    elseif perk == CaptainUtility.PerkType.Gambler then
        return 0.05 -- increase
    elseif perk == CaptainUtility.PerkType.Connected then
        return -0.02 -- reduction
    end

    return 0 -- fallback
end

function CaptainUtility.getProcureTimePerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.02
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.10
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local marketExpertImpacts = {}
    marketExpertImpacts[0] = 0
    marketExpertImpacts[1] = 0.1
    marketExpertImpacts[2] = 0.2
    marketExpertImpacts[3] = 0.3
    marketExpertImpacts[4] = 0.4
    marketExpertImpacts[5] = 0.5

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        return -marketExpertImpacts[captain.level] or 0 -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase multiplier
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase multiplier
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase multiplier
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getProcurePricePerkImpact(captain, perk)
    if perk == CaptainUtility.PerkType.Connected then
        return -0.02 -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.Intimidating then
        return -0.02 -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.Commoner then
        return -0.02 -- reduction multiplier
    elseif perk == CaptainUtility.PerkType.Gambler then
        return 0.01 -- increase multiplier
    elseif perk == CaptainUtility.PerkType.Noble then
        return 0.01 -- increase multiplier
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getSellTimePerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.02
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.1
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local marketExpertImpacts = {}
    marketExpertImpacts[0] = 0
    marketExpertImpacts[1] = 0.1
    marketExpertImpacts[2] = 0.2
    marketExpertImpacts[3] = 0.3
    marketExpertImpacts[4] = 0.4
    marketExpertImpacts[5] = 0.5

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        return -marketExpertImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getSellPricePerkImpact(captain, perk)
    if perk == CaptainUtility.PerkType.Connected then
        return 0.02 -- increase
    elseif perk == CaptainUtility.PerkType.Intimidating then
        return 0.02 -- increase
    elseif perk == CaptainUtility.PerkType.Commoner then
        return 0.02 -- increase
    elseif perk == CaptainUtility.PerkType.Gambler then
        return -0.01 -- reduction
    elseif perk == CaptainUtility.PerkType.Noble then
        return -0.01 -- reduction
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getTradeTimePerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.01
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.1
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local marketExpertImpacts = {}
    marketExpertImpacts[0] = 0
    marketExpertImpacts[1] = 0.1
    marketExpertImpacts[2] = 0.2
    marketExpertImpacts[3] = 0.3
    marketExpertImpacts[4] = 0.4
    marketExpertImpacts[5] = 0.5

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        return -marketExpertImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getTradeSellPricePerkImpact(captain, perk)
    if perk == CaptainUtility.PerkType.Connected then
        return 0.02 -- increase
    elseif perk == CaptainUtility.PerkType.Intimidating then
        return 0.02 -- increase
    elseif perk == CaptainUtility.PerkType.Commoner then
        return 0.02 -- increase
    elseif perk == CaptainUtility.PerkType.Gambler then
        return -0.01 -- reduction
    elseif perk == CaptainUtility.PerkType.Noble then
        return -0.01 -- reduction
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getTradeBuyPricePerkImpact(captain, perk)
    if perk == CaptainUtility.PerkType.Connected then
        return -0.02 -- reduction
    elseif perk == CaptainUtility.PerkType.Intimidating then
        return -0.02 -- reduction
    elseif perk == CaptainUtility.PerkType.Commoner then
        return -0.02 -- reduction
    elseif perk == CaptainUtility.PerkType.Gambler then
        return 0.01 -- increase
    elseif perk == CaptainUtility.PerkType.Noble then
        return 0.01 -- increase
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getTravelPerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.01
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.1
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getMaintenanceTimePerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.01
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.1
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local marketExpertImpacts = {}
    marketExpertImpacts[0] = 0
    marketExpertImpacts[1] = 0.1
    marketExpertImpacts[2] = 0.2
    marketExpertImpacts[3] = 0.3
    marketExpertImpacts[4] = 0.4
    marketExpertImpacts[5] = 0.5

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        return -marketExpertImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getMaintenancePricePerkImpact(captain, perk)
    if perk == CaptainUtility.PerkType.Connected then
        return -0.1 -- reduction
    elseif perk == CaptainUtility.PerkType.Intimidating then
        return -0.1 -- reduction
    elseif perk == CaptainUtility.PerkType.Commoner then
        return -0.1 -- reduction
    elseif perk == CaptainUtility.PerkType.Gambler then
        return 0.1 -- increase
    elseif perk == CaptainUtility.PerkType.Noble then
        return 0.1 -- increase
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getScoutPerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.01
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.1
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    else
        return 0 -- fallback
    end
end

-- no perks besides attack related
-- function is here for completeness
-- function CaptainUtility.getExpeditionPerkImpact(captain, perk)
-- end

function CaptainUtility.getSupplyPerkImpact(captain, perk)
    local navigatorImpacts = {}
    navigatorImpacts[0] = 0.01
    navigatorImpacts[1] = 0.05
    navigatorImpacts[2] = 0.1
    navigatorImpacts[3] = 0.15
    navigatorImpacts[4] = 0.2
    navigatorImpacts[5] = 0.25

    local recklessImpacts = {}
    recklessImpacts[0] = 0.1
    recklessImpacts[1] = 0.15
    recklessImpacts[2] = 0.2
    recklessImpacts[3] = 0.25
    recklessImpacts[4] = 0.3
    recklessImpacts[5] = 0.35

    local disorientedImpacts = {}
    disorientedImpacts[0] = 0.125
    disorientedImpacts[1] = 0.1
    disorientedImpacts[2] = 0.075
    disorientedImpacts[3] = 0.05
    disorientedImpacts[4] = 0.025
    disorientedImpacts[5] = 0.01

    local addictImpacts = {}
    addictImpacts[0] = 0.125
    addictImpacts[1] = 0.1
    addictImpacts[2] = 0.075
    addictImpacts[3] = 0.05
    addictImpacts[4] = 0.025
    addictImpacts[5] = 0.01

    local carefulImpacts = {}
    carefulImpacts[0] = 0.15
    carefulImpacts[1] = 0.125
    carefulImpacts[2] = 0.1
    carefulImpacts[3] = 0.075
    carefulImpacts[4] = 0.05
    carefulImpacts[5] = 0.025

    if perk == CaptainUtility.PerkType.Navigator then
        return -navigatorImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Reckless then
        return -recklessImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Disoriented then
        return disorientedImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Addict then
        return addictImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Careful then
        return carefulImpacts[captain.level] or 0 -- increase
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getPerkAttackProbabilities(captain, perk)
    local stealthyImpacts = {}
    stealthyImpacts[0] = 0.02
    stealthyImpacts[1] = 0.04
    stealthyImpacts[2] = 0.06
    stealthyImpacts[3] = 0.08
    stealthyImpacts[4] = 0.1
    stealthyImpacts[5] = 0.12

    local intimidatingImpacts = {}
    intimidatingImpacts[0] = 0.02
    intimidatingImpacts[1] = 0.04
    intimidatingImpacts[2] = 0.06
    intimidatingImpacts[3] = 0.08
    intimidatingImpacts[4] = 0.1
    intimidatingImpacts[5] = 0.12

    local cunningImpacts = {}
    cunningImpacts[0] = 0.02
    cunningImpacts[1] = 0.04
    cunningImpacts[2] = 0.06
    cunningImpacts[3] = 0.08
    cunningImpacts[4] = 0.1
    cunningImpacts[5] = 0.12

    local arrogantImpacts = {}
    arrogantImpacts[0] = 0.06
    arrogantImpacts[1] = 0.05
    arrogantImpacts[2] = 0.04
    arrogantImpacts[3] = 0.03
    arrogantImpacts[4] = 0.02
    arrogantImpacts[5] = 0.01

    local harmlessImpacts = {}
    harmlessImpacts[0] = 0.06
    harmlessImpacts[1] = 0.05
    harmlessImpacts[2] = 0.04
    harmlessImpacts[3] = 0.03
    harmlessImpacts[4] = 0.02
    harmlessImpacts[5] = 0.01

    if perk == CaptainUtility.PerkType.Reckless then
        return 0.05 -- increase
    elseif perk == CaptainUtility.PerkType.Stealthy then
        return -stealthyImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Intimidating then
        return -intimidatingImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Cunning then
        return -cunningImpacts[captain.level] or 0 -- reduction
    elseif perk == CaptainUtility.PerkType.Arrogant then
        return arrogantImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Harmless then
        return harmlessImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Careful then
        return -0.1 -- reduction
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getShipStrengthPerks(captain, perk)
    if perk == CaptainUtility.PerkType.Noble then
        return 1.2 -- increase
    elseif perk == CaptainUtility.PerkType.Commoner then
        return 0.9 -- reduction
    else
        return 1 -- fallback
    end
end

function CaptainUtility.getAttackStrengthPerks(captain, perk)
    local cunningImpacts = {}
    cunningImpacts[0] = 1.5
    cunningImpacts[1] = 1.45
    cunningImpacts[2] = 1.4
    cunningImpacts[3] = 1.35
    cunningImpacts[4] = 1.3
    cunningImpacts[5] = 1.25

    local harmlessImpacts = {}
    harmlessImpacts[0] = 0.95
    harmlessImpacts[1] = 0.9
    harmlessImpacts[2] = 0.85
    harmlessImpacts[3] = 0.8
    harmlessImpacts[4] = 0.75
    harmlessImpacts[5] = 0.7

    if perk == CaptainUtility.PerkType.Cunning then
        return cunningImpacts[captain.level] or 0 -- increase
    elseif perk == CaptainUtility.PerkType.Harmless then
        return harmlessImpacts[captain.level] or 0 -- reduction
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getUnluckyPerk(captain, perk)
    local unluckyImpacts = {}
    unluckyImpacts[0] = 0.5
    unluckyImpacts[1] = 0.45
    unluckyImpacts[2] = 0.4
    unluckyImpacts[3] = 0.35
    unluckyImpacts[4] = 0.3
    unluckyImpacts[5] = 0.25

    if perk == CaptainUtility.PerkType.Unlucky then
        return unluckyImpacts[captain.level] or 0
    else
        return 0 -- fallback
    end
end

function CaptainUtility.getLuckyPerkAmount(captain, perk)
    local luckyImpacts = {}
    luckyImpacts[0] = 1
    luckyImpacts[1] = 2
    luckyImpacts[2] = 3
    luckyImpacts[3] = 4
    luckyImpacts[4] = 5
    luckyImpacts[5] = 6

    if perk == CaptainUtility.PerkType.Lucky then
        return luckyImpacts[captain.level] or 0
    else
        return 0 -- fallback
    end
end

function CaptainUtility.makePerkSummaryLine(captain, perk, commandType, properties)
    local lineHeight = 15
    local fontSize = 11
    local line = TooltipLine(lineHeight, fontSize)

    line.ltext = properties.summary
    line.icon = "data/textures/icons/nothing.png"
    line.lcolor = ColorRGB(0.5, 0.5, 0.5)
    line.fontType = FontType.Normal

    if commandType then
        if commandType == CommandType.Travel then
            CaptainUtility.insertTravelPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Scout then
            CaptainUtility.insertScoutPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Mine then
            CaptainUtility.insertMiningPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Salvage then
            CaptainUtility.insertSalvagingPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Refine then
            CaptainUtility.insertRefinePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Trade then
            CaptainUtility.insertTradePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Procure then
            CaptainUtility.insertProcurePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Sell then
            CaptainUtility.insertSellPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Supply then
            CaptainUtility.insertSupplyPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Expedition then
            CaptainUtility.insertExpeditionPerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Maintenance then
            CaptainUtility.insertMaintenancePerkSummaries(line, captain, perk, properties)
        elseif commandType == CommandType.Escort or commandType == CommandType.Prototype then
            -- nothing and that's okay
        else
            -- a new command has entered the arena
            eprint("CaptainUtility.makePerkSummaryLine: unknown command type:", commandType)
        end
    end

    return line
end

function CaptainUtility.getCaptainClassSummary(class, commandType)
    if commandType then
        if commandType == CommandType.Travel then
            return CaptainUtility.getTravelCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Scout then
            return CaptainUtility.getScoutCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Mine then
            return CaptainUtility.getMineCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Salvage then
            return CaptainUtility.getSalvageCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Refine then
            return CaptainUtility.getRefineCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Trade then
            return CaptainUtility.getTradeCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Procure then
            return CaptainUtility.getProcureCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Sell then
            return CaptainUtility.getSellCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Supply then
            return CaptainUtility.getSupplyCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Expedition then
            return CaptainUtility.getExpeditionCommandCaptainClassDescription(class)
        elseif commandType == CommandType.Maintenance then
            return CaptainUtility.getMaintenanceCommandCaptainClassDescription(class)

        elseif commandType == CommandType.Escort or commandType == CommandType.Prototype then
            -- nothing and that's okay
        else
            -- a new command has entered the arena
            eprint("CaptainUtility.getCaptainClassSummary: unknown command type:", commandType)
        end
    end
end

function CaptainUtility.insertMiningPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}s faster at finding asteroids"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getMiningPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "${var}% refinery tax"%_t % {var = CaptainUtility.getMiningPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}s faster at finding asteroids"%_t % {var = math.abs(CaptainUtility.getMiningPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk for ambushes"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}s slower at finding asteroids"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getMiningPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}s slower at finding asteroids"%_t % {var = math.abs(CaptainUtility.getMiningPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "Gains ${var}% less resources"%_t % {var = math.abs(CaptainUtility.getMiningPerkImpact(captain, perk))* 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}s slower at finding asteroids"%_t % {var = math.abs(CaptainUtility.getMiningPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess, ${var2}% refinery tax"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = CaptainUtility.getMiningPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.75, 0.75, 0.75)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess, ${var2}% refinery tax"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = CaptainUtility.getMiningPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertSalvagingPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}s faster at finding wrecks"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getSalvagingPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "${var}% refinery tax"%_t % {var = CaptainUtility.getSalvagingPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}s faster at finding wrecks"%_t % {var = math.abs(CaptainUtility.getSalvagingPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}s slower at finding wrecks"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getSalvagingPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}s slower at finding wrecks"%_t % {var = math.abs(CaptainUtility.getSalvagingPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "Gains ${var}% less resources"%_t % {var = math.abs(CaptainUtility.getSalvagingPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}s slower at finding wrecks"%_t % {var = math.abs(CaptainUtility.getSalvagingPerkImpact(captain, perk))}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess, ${var2}% refinery tax"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = CaptainUtility.getSalvagingPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess, ${var2}% refinery tax"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = CaptainUtility.getSalvagingPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertProcurePerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getProcureTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "Negotiates ${var}% better prices"%_t % {var = math.abs(CaptainUtility.getProcurePricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getProcureTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "${var}% faster, always buys at the lowest price"%_t % {var = math.abs(CaptainUtility.getProcureTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getProcureTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getProcureTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "Loses ${var}% additional credits"%_t % {var = math.abs(CaptainUtility.getProcurePricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getProcureTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var1}% lower risk of being ambushed, negotiates ${var2}% better prices"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getProcurePricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess, negotiates ${var2}% better prices"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = math.abs(CaptainUtility.getProcurePricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess, has to pay ${var2}% more"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = math.abs(CaptainUtility.getProcurePricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertSellPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getSellTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "${var}% more profits"%_t % {var = math.abs(CaptainUtility.getSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getSellTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "${var}% faster, always sells at the highest price"%_t % {var = math.abs(CaptainUtility.getSellTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getSellTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getSellTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "${var}% less profits"%_t % {var = math.abs(CaptainUtility.getSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getSellTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% more profits"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess, ${var2}% more profits"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = math.abs(CaptainUtility.getSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess, ${var2}% less profits"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = math.abs(CaptainUtility.getSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertTradePerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getTradeTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "${var1}% more profits, buys goods for ${var2}% less"%_t % {var1 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getTradeBuyPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getTradeTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "${var}% faster, always sells and buys at the best price"%_t % {var = math.abs(CaptainUtility.getTradeTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getTradeTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getTradeTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "${var1}% less profits, loses ${var2}% of earnings"%_t % {var1 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getTradeBuyPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getTradeTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% more profits, buys goods for ${var3}% less"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100, var3 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess, ${var2}% more profits, buys goods for ${var3}% less"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100, var3 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess, ${var2}% less profits, buys goods for ${var3}% more"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100, var3 = math.abs(CaptainUtility.getTradeSellPricePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertTravelPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getTravelPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getTravelPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getTravelPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getTravelPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getTravelPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertSupplyPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getSupplyPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getSupplyPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getSupplyPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getSupplyPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getSupplyPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertRefinePerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getRefineTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "${var}% less refinery tax"%_t % {var = math.abs(CaptainUtility.getRefineTaxPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getRefineTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getRefineTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getRefineTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "${var}% higher refinery tax"%_t % {var = math.abs(CaptainUtility.getRefineTaxPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getRefineTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var}% refinery tax"%_t % {var = CaptainUtility.getRefineTaxPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var}% refinery tax"%_t % {var = CaptainUtility.getRefineTaxPerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertScoutPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getScoutPerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertMaintenancePerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% faster"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getMaintenanceTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "Negotiates ${var}% better prices"%_t % {var = CaptainUtility.getMaintenancePricePerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "${var}% faster"%_t % {var = math.abs(CaptainUtility.getMaintenanceTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "${var}% faster, always buys at the lowest price"%_t % {var = math.abs(CaptainUtility.getMaintenanceTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% slower"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = math.abs(CaptainUtility.getMaintenanceTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getMaintenanceTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "Loses ${var}% additional Credits"%_t % {var = CaptainUtility.getMaintenancePricePerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "${var}% slower"%_t % {var = math.abs(CaptainUtility.getMaintenanceTimePerkImpact(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var1}% lower risk of being ambushed, negotiates ${var2}% better prices"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100, var2 = CaptainUtility.getMaintenancePricePerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess, negotiates ${var2}% better prices"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = CaptainUtility.getMaintenancePricePerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess, has to pay ${var2}% more"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100), var2 = CaptainUtility.getMaintenancePricePerkImpact(captain, perk) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.insertExpeditionPerkSummaries(line, captain, perk, properties)
    if perk == CaptainUtility.PerkType.Reckless then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Connected then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Navigator then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Stealthy then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.MarketExpert then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Careful then
        line.ltext = "${var}% lower risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Disoriented then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Gambler then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Addict then
        line.ltext = "No effect on this command"%_t
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Intimidating then
        line.ltext = "${var1}% lower risk of being ambushed"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Arrogant then
        line.ltext = "${var}% higher risk of being ambushed"%_t % {var = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Cunning then
        line.ltext = "${var1}% lower risk of being ambushed, ${var2}% stronger enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Harmless then
        line.ltext = "${var1}% higher risk of being ambushed, ${var2}% weaker enemies"%_t % {var1 = math.abs(CaptainUtility.getPerkAttackProbabilities(captain, perk)) * 100; var2 = math.abs(1 - CaptainUtility.getAttackStrengthPerks(captain, perk)) * 100}
        line.lcolor = ColorRGB(0.7, 0.7, 0.7)
    elseif perk == CaptainUtility.PerkType.Commoner then
        line.ltext = "${var1}% less combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Noble then
        line.ltext = "${var1}% more combat prowess"%_t % {var1 = math.abs(CaptainUtility.getShipStrengthPerks(captain, perk) * 100 - 100)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Lucky then
        line.ltext = "Finds up to ${var} items when executing the command"%_t % {var = CaptainUtility.getLuckyPerkAmount(captain, perk)}
        line.lcolor = ColorRGB(0.6, 0.9, 0.6)
    elseif perk == CaptainUtility.PerkType.Unlucky then
        line.ltext = "${var}% chance of damaging the ship"%_t % {var = CaptainUtility.getUnluckyPerk(captain, perk) * 100}
        line.lcolor = ColorRGB(0.9, 0.6, 0.6)
    elseif perk == CaptainUtility.PerkType.Humble or perk == CaptainUtility.PerkType.Greedy
            or perk == CaptainUtility.PerkType.Educated or perk == CaptainUtility.PerkType.Uneducated then
        line.ltext = properties.summary
        line.lcolor = ColorRGB(0.6, 0.6, 0.6)
    else
        eprint("Unknown perk: ", perk)
    end
end

function CaptainUtility.getTravelCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        return "10% faster travel time"%_t
    elseif class == CaptainUtility.ClassType.Scavenger or class == CaptainUtility.ClassType.Miner
            or class == CaptainUtility.ClassType.Daredevil or class == CaptainUtility.ClassType. Scientist
            or class == CaptainUtility.ClassType.Hunter or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getMineCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Miner then
        return "Can mine more resources, can perform longer mining operations"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        return "Reveals asteroid fields in the area"%_t
    elseif class == CaptainUtility.ClassType.Scavenger or class == CaptainUtility.ClassType.Daredevil
            or class == CaptainUtility.ClassType. Scientist or class == CaptainUtility.ClassType.Hunter
            or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getSalvageCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Scavenger then
        return "Can find more loot and resources, can perform longer scrapping operations"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        return "Reveals wreckage fields in the area"%_t
    elseif class == CaptainUtility.ClassType.Miner or class == CaptainUtility.ClassType.Daredevil
            or class == CaptainUtility.ClassType. Scientist or class == CaptainUtility.ClassType.Hunter
            or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getProcureCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        return "Up to four goods, procures all goods traded in the area, lower prices, can procure stolen goods"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Up to five goods, procures all goods, faster, lower prices"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        return "Reveals civilized sectors in the area"%_t
    elseif class == CaptainUtility.ClassType.Miner or class == CaptainUtility.ClassType.Scavenger
            or class == CaptainUtility.ClassType.Daredevil or class == CaptainUtility.ClassType. Scientist
            or class == CaptainUtility.ClassType.Hunter or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getSellCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        return "Can sell all goods traded in the area, has better prices, can sell stolen goods"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Can sell almost all goods, finds offers faster, has better prices"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        return "Reveals civilized sectors in the area"%_t
    elseif class == CaptainUtility.ClassType.Miner or class == CaptainUtility.ClassType.Scavenger
            or class == CaptainUtility.ClassType.Daredevil or class == CaptainUtility.ClassType. Scientist
            or class == CaptainUtility.ClassType.Hunter or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getSupplyCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Smuggler then
        return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Commodore or class == CaptainUtility.ClassType.Miner
            or class == CaptainUtility.ClassType.Scavenger or class == CaptainUtility.ClassType.Explorer
            or class == CaptainUtility.ClassType.Daredevil or class == CaptainUtility.ClassType. Scientist
            or class == CaptainUtility.ClassType.Hunter or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getRefineCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Smuggler then
        return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        return "Reveals civilized sectors in the area"%_t
    elseif class == CaptainUtility.ClassType.Commodore or class == CaptainUtility.ClassType.Miner
            or class == CaptainUtility.ClassType.Scavenger or class == CaptainUtility.ClassType.Daredevil
            or class == CaptainUtility.ClassType. Scientist or class == CaptainUtility.ClassType.Hunter
            or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getExpeditionCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Miner or class == CaptainUtility.ClassType.Scavenger
            or class == CaptainUtility.ClassType.Explorer or class == CaptainUtility.ClassType.Daredevil then
        return "Discovers special loot upon successful completion of the mission"%_t
    elseif class == CaptainUtility.ClassType. Scientist or class == CaptainUtility.ClassType.Hunter
            or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getScoutCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Commodore then
        return "-15% risk of being ambushed"%_t
    elseif class == CaptainUtility.ClassType.Smuggler then
        return "Uncovers smuggler hideouts and is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Miner then
        return "Reveals asteroid fields in the area"%_t
    elseif class == CaptainUtility.ClassType.Scavenger then
        return "Reveals wreckage fields in the area"%_t
    elseif class == CaptainUtility.ClassType.Explorer then
        return "Reveals sectors in the area"%_t
    elseif class == CaptainUtility.ClassType.Daredevil then
        return "Reveals sectors with Xsotan and pirates in the area"%_t
    elseif class == CaptainUtility.ClassType. Scientist or class == CaptainUtility.ClassType.Hunter
            or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getMaintenanceCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Smuggler then
        return "Is not slowed down by questionable goods on board"%_t
    elseif class == CaptainUtility.ClassType.Merchant then
        return "Is not slowed down by suspicious or dangerous goods on board"%_t
    elseif class == CaptainUtility.ClassType.Commodore or class == CaptainUtility.ClassType.Miner
            or class == CaptainUtility.ClassType.Scavenger or class == CaptainUtility.ClassType.Explorer
            or class == CaptainUtility.ClassType.Daredevil or class == CaptainUtility.ClassType. Scientist
            or class == CaptainUtility.ClassType.Hunter or class == CaptainUtility.ClassType.None then
        return "No effect on this command"%_t
    else
        eprint("Unknown class: ", class)
    end
end

function CaptainUtility.getTradeCommandCaptainClassDescription(class)
    if class == CaptainUtility.ClassType.Merchant then
        return "Can trade independently"%_t
    elseif class == CaptainUtility.ClassType.Commodore or class == CaptainUtility.ClassType.Smuggler
            or class == CaptainUtility.ClassType.Miner or class == CaptainUtility.ClassType.Scavenger
            or class == CaptainUtility.ClassType.Explorer or class == CaptainUtility.ClassType.Daredevil
            or class == CaptainUtility.ClassType. Scientist or class == CaptainUtility.ClassType.Hunter
            or class == CaptainUtility.ClassType.None then
        return "Cannot trade independently"%_t
    else
        eprint("Unknown class: ", class)
    end
end

return CaptainUtility
