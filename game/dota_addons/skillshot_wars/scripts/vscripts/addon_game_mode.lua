-- This is the entry-point to your game mode and should be used primarily to precache models/particles/sounds/etc

-- Creating a global gamemode class variable;
if barebones == nil then
    _G.barebones = class({})
else
    DebugPrint("[BAREBONES] barebones class name is already in use, change the name if this is the first time you launch the game!")
    DebugPrint("[BAREBONES] If this is not your first time, you probably used script_reload in console.")
end

require('util')
require('libraries/timers')                      -- Core lua library
require('libraries/player_resource')             -- Core lua library
require('gamemode')                              -- Core barebones file

function Precache(context)
    --[[
      This function is used to precache resources/units/items/abilities that will be needed
      for sure in your game and that will not be precached by hero selection.  When a hero
      is selected from the hero selection screen, the game will precache that hero's assets,
      any equipped cosmetics, and perform the data-driven precaching defined in that hero's
      precache{} block, as well as the precache{} block for any equipped abilities.

      See barebones:PostLoadPrecache() in gamemode.lua for more information
      ]]

    DebugPrint("[BAREBONES] Performing pre-load precache")

    -- Particles can be precached individually or by folder
    -- It it likely that precaching a single particle system will precache all of its children, but this may not be guaranteed
    --PrecacheResource("particle", "particles/econ/generic/generic_aoe_explosion_sphere_1/generic_aoe_explosion_sphere_1.vpcf", context)
    --PrecacheResource("particle_folder", "particles/test_particle", context)

    -- Models can also be precached by folder or individually
    -- PrecacheModel should generally used over PrecacheResource for individual models

    --PrecacheResource("model_folder", "particles/heroes/antimage", context)
    --PrecacheResource("model", "particles/heroes/viper/viper.vmdl", context)
    --PrecacheModel("models/heroes/viper/viper.vmdl", context)
    --PrecacheModel("models/props_gameplay/treasure_chest001.vmdl", context)
    --PrecacheModel("models/props_debris/merchant_debris_chest001.vmdl", context)
    --PrecacheModel("models/props_debris/merchant_debris_chest002.vmdl", context)

    -- Sounds can precached here likie anything else
    PrecacheResource("soundfile", "*.vsndevts", context)

    -- Entire items can be precached by name
    -- Abilities can also be precached in this way despite the name
    PrecacheItemByNameSync("item_tpscroll", context)
    PrecacheItemByNameSync("item_ward_observer", context)
    PrecacheItemByNameSync("item_ward_sentry", context)
    PrecacheItemByNameSync("item_smoke_of_deceit", context)
    PrecacheItemByNameSync("item_flask", context)
    PrecacheItemByNameSync("item_citrulline_malate", context)
    PrecacheItemByNameSync("item_boots", context)
    PrecacheItemByNameSync("item_scout_bot", context)
    PrecacheItemByNameSync("item_glimmer_cape_dummy", context)
    PrecacheItemByNameSync("item_manta_dummy", context)
    PrecacheItemByNameSync("item_gem_of_vengeance", context)
    PrecacheItemByNameSync("item_blink", context)
    PrecacheItemByNameSync("item_travel_boots_2_dummy", context)
    PrecacheItemByNameSync("item_refresher_dummy", context)
    PrecacheItemByNameSync("item_bloodstone_dummy", context)

    -- Entire heroes (sound effects/voice/models/particles) can be precached with PrecacheUnitByNameSync
    -- Custom units from npc_units_custom.txt can also have all of their abilities and precache{} blocks precached in this way
    PrecacheUnitByNameSync("npc_dota_hero_pudge", context)
    PrecacheUnitByNameSync("npc_dota_hero_mirana", context)
    PrecacheUnitByNameSync("npc_dota_hero_rattletrap", context)
    PrecacheUnitByNameSync("npc_dota_hero_invoker", context)

    -- Needed for scout bot.
    PrecacheUnitByNameSync("npc_dota_hero_tinker", context)

    -- Needed for gem of vengance.
    PrecacheUnitByNameSync("npc_dota_hero_vengefulspirit", context)

    -- Not sure why techies is needed.
    PrecacheUnitByNameSync("npc_dota_hero_techies", context)
end

-- Create the game mode when we activate
function Activate()
    DebugPrint("[BAREBONES] Activating ...")
    print("Your custom game is activating.")
    barebones:InitGameMode()
end
