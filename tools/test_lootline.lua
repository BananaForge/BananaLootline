-- Der Wegplan beantwortet eine einzige Frage: wohin als naechstes?
--
-- Zwei Dinge standen dem im Weg:
--   1. Haendlerware gilt als sicher und bekommt den vollen Zuwachs
--      angerechnet, ein Dungeondrop nur seinen Anteil nach Dropchance.
--      Ungefiltert stand der Haendler deshalb immer oben.
--   2. Eine Sammelgruppe "kein Fundort" beantwortet die Frage nicht.
string.gmatch = nil; select = nil

BananaLootline = {
  locale = "enUS", clientLocale = "enUS",
  L = setmetatable({}, { __index = function(t, k) return k end }),
}
BananaLootlineDB = { planAhead = 6, itemcache = {} }
CreateFrame = function()
  return { SetScript = function() end, RegisterEvent = function() end }
end

local BLL = BananaLootline
BLL.Print = function() end
BLL.Weights = {
  Score = function(self, s) local t = 0; for _, v in pairs(s or {}) do t = t + v end return t end,
  UseEffectScore = function() return 0, false end,
}
BLL.SetDB = { loaded = false }

-- Vier Kandidaten auf vier Plaetzen: Haendler, Dungeon, Quest und
-- einer ganz ohne Fundort.
local SOURCES = {
  [10] = { { stype = "V", name = "Haendler Hargunth", zone = "The Barrens" } },
  [20] = { { stype = "U", name = "Boss", zone = "Wailing Caverns", chance = 5 } },
  [30] = { { stype = "Q", name = "Eine Quest", id = 777 } },
  [40] = { },
}
BLL.Sources = {
  available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end,
  GetItemSources = function(self, id) return SOURCES[id] or {} end,
}

local SLOTS = { { key = "HeadSlot" }, { key = "HandsSlot" },
                { key = "FeetSlot" }, { key = "WaistSlot" } }
BLL.Gear = { SLOTS = SLOTS, SlotLabel = function(s, x) return x.key end, equipped = {} }
BLL.ItemDB = { loaded = false, Get = function() return nil end,
               MaskAllows = function() return true end }

dofile("Candidates.lua")
local Cand = BLL.Candidates
BLL.player = { class = "HUNTER", level = 15 }
Cand.skills = { known = {}, dualWield = true }
Cand.skillsDirty = false

BananaLootlineDB.itemcache = {
  [10] = { e = "INVTYPE_HEAD", st = { AGI = 30 }, r = 15, q = 3, n = "Vom Haendler" },
  [20] = { e = "INVTYPE_HAND", st = { AGI = 20 }, r = 15, q = 3, n = "Aus dem Dungeon" },
  [30] = { e = "INVTYPE_FEET", st = { AGI = 20 }, r = 15, q = 3, n = "Aus der Quest" },
  [40] = { e = "INVTYPE_WAIST", st = { AGI = 25 }, r = 15, q = 3, n = "Ohne Fundort" },
}
Cand.pool = { [10] = 15, [20] = 15, [30] = 15, [40] = 15 }
Cand.fromImport = { [40] = 1 }

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local function zones()
  local groups = Cand:GetLootline(3)
  local out = {}
  for i = 1, table.getn(groups or {}) do out[groups[i].zone] = groups[i] end
  return out, groups
end

------------------------------------------------------------------
-- 1. Standard: kein Haendler, kein ortloser Eintrag
------------------------------------------------------------------

BananaLootlineDB.showVendors = nil
local z, groups = zones()

check(z["The Barrens"] == nil, "Haendlerzone erscheint nicht ohne Haken")
check(z["Wailing Caverns"] ~= nil, "der Dungeon erscheint")
check(z["Quests"] ~= nil, "Quests erscheinen als eigene Gruppe")
for k in pairs(z) do
  check(k ~= "No location" and k ~= "Ohne Ortsangabe",
    "Sammelgruppe ohne Fundort erscheint nicht: " .. k)
end

------------------------------------------------------------------
-- 2. Mit Haken erscheint der Haendler
------------------------------------------------------------------

BananaLootlineDB.showVendors = true
z = zones()
check(z["The Barrens"] ~= nil, "mit Haken erscheint die Haendlerzone")
check(z["Wailing Caverns"] ~= nil, "der Dungeon bleibt daneben bestehen")

------------------------------------------------------------------
-- 3. Der Haken aendert nichts an der Einzelansicht
--
-- Dort geht es um "was ist fuer diesen Platz besser", nicht um einen
-- Weg. Haendlerware gehoert da weiterhin hin.
------------------------------------------------------------------

BananaLootlineDB.showVendors = nil
local ups = Cand:GetUpgrades("HeadSlot", 5)
local found = false
for i = 1, table.getn(ups or {}) do if ups[i].id == 10 then found = true end end
check(found, "Haendlerware bleibt in der Einzelansicht sichtbar")

-- Und das Teil ohne Fundort ebenfalls
ups = Cand:GetUpgrades("WaistSlot", 5)
found = false
for i = 1, table.getn(ups or {}) do if ups[i].id == 40 then found = true end end
check(found, "Teil ohne Fundort bleibt in der Einzelansicht sichtbar")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
