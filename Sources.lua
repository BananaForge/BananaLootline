--[[----------------------------------------------------------------------
  BananaLootline - Sources.lua

  Adapter auf die pfQuest-Datenbank.

  Bewusste Architekturentscheidung: wir BUENDELN die Daten nicht, wir LESEN
  sie zur Laufzeit. Gruende:
    - items-turtle.lua allein ist ~7,5 MB, units ~4,7 MB. Eine zweite Kopie
      im Speicher waere reine Verschwendung.
    - Bei jedem DB-Update von pfQuest-octo profitieren wir automatisch,
      ohne selbst neu releasen zu muessen.
    - Keine Lizenz-/Attributionsfragen, weil wir nichts weiterverteilen.

  pfQuest-Datenformat (verifiziert gegen roby-brok/pfQuest-octo):

    pfDB["items"]["data"][itemID] = {
      ["U"] = { [unitID]   = dropChance },   -- Unit (Mob/Boss)
      ["O"] = { [objectID] = dropChance },   -- Objekt (Truhe etc.)
      ["V"] = { [vendorID] = 0 },            -- Haendler
      ["Q"] = { [questID]  = 1 },            -- Questbelohnung
      ["C"] = { ... },                       -- Container
      ["L"] = { [refID]    = chance },       -- Referenz-Loottabelle
    }
    pfDB["items"]["loc"][itemID]  = "Itemname"
    pfDB["units"]["data"][unitID] = { ["coords"] = { {x, y, zoneID, respawn}, ... }, ["lvl"] = "60" }
    pfDB["units"]["loc"][unitID]  = "Unitname"
    pfDB["zones"]["loc"][zoneID]  = "Zonenname"
    pfDB["refloot"]["data"][refID]= { ["U"] = { [unitID] = chance }, ... }

  Die "-turtle"-Tabellen aus dem Octo-Pack werden von pfQuests patchtable.lua
  vor unserem Start in ["data"] / ["loc"] gemerged. Wir lesen deshalb immer
  die gemergten Tabellen und nie die "-turtle"-Varianten direkt.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Sources = {}
local Sources = BLL.Sources

Sources.available = false

------------------------------------------------------------------
-- Init / Erkennung
------------------------------------------------------------------

function Sources:Init()
  if not pfDB then
    self.available = false
    return false
  end

  self.items   = pfDB["items"]   and pfDB["items"]["data"]
  self.itemloc = pfDB["items"]   and (pfDB["items"]["loc"] or pfDB["items"]["enUS"])
  self.units   = pfDB["units"]   and pfDB["units"]["data"]
  self.unitloc = pfDB["units"]   and (pfDB["units"]["loc"] or pfDB["units"]["enUS"])
  self.objects = pfDB["objects"] and pfDB["objects"]["data"]
  self.objloc  = pfDB["objects"] and (pfDB["objects"]["loc"] or pfDB["objects"]["enUS"])
  self.quests  = pfDB["quests"]  and pfDB["quests"]["data"]
  self.questloc= pfDB["quests"]  and (pfDB["quests"]["loc"] or pfDB["quests"]["enUS"])
  self.zoneloc = pfDB["zones"]   and (pfDB["zones"]["loc"] or pfDB["zones"]["enUS"])
  self.refloot = pfDB["refloot"] and pfDB["refloot"]["data"]

  self.available = (self.items ~= nil)

  -- Octo-Pack erkennen: der Pack setzt eine eigene SavedVariable
  self.octoPack = (pfQuest_turtlecount ~= nil)

  BLL:Debug("Sources init: items=" .. (self.items and "ok" or "fehlt")
    .. " units=" .. (self.units and "ok" or "fehlt")
    .. " octopack=" .. (self.octoPack and "ja" or "nein"))

  return self.available
end

------------------------------------------------------------------
-- Namensaufloesung
------------------------------------------------------------------

function Sources:UnitName(id)
  if not self.unitloc then return "Unit #" .. id end
  local v = self.unitloc[id]
  if type(v) == "table" then return v[1] or ("Unit #" .. id) end
  return v or ("Unit #" .. id)
end

function Sources:ObjectName(id)
  if not self.objloc then return "Objekt #" .. id end
  local v = self.objloc[id]
  if type(v) == "table" then return v[1] or ("Objekt #" .. id) end
  return v or ("Objekt #" .. id)
end

function Sources:QuestName(id)
  if not self.questloc then return "Quest #" .. id end
  local v = self.questloc[id]
  if type(v) == "table" then return v["T"] or ("Quest #" .. id) end
  return v or ("Quest #" .. id)
end

function Sources:ZoneName(id)
  if not self.zoneloc then return nil end
  local name = self.zoneloc[id]
  if name == "_" then return nil end
  return name
end

function Sources:ItemName(id)
  if not self.itemloc then return nil end
  local v = self.itemloc[id]
  if type(v) == "table" then return v[1] end
  return v
end

------------------------------------------------------------------
-- Zone einer Unit bestimmen (haeufigste Zone in den Koordinaten)
------------------------------------------------------------------

function Sources:UnitZone(unitID)
  if not self.units then return nil end
  local unit = self.units[unitID]
  if not unit or type(unit) ~= "table" or not unit["coords"] then return nil end

  local counts, best, bestZone = {}, 0, nil
  local coords = unit["coords"]
  for i = 1, table.getn(coords) do
    local zone = coords[i][3]
    if zone then
      counts[zone] = (counts[zone] or 0) + 1
      if counts[zone] > best then
        best, bestZone = counts[zone], zone
      end
    end
  end
  return bestZone and self:ZoneName(bestZone) or nil
end

function Sources:UnitLevel(unitID)
  if not self.units then return nil end
  local unit = self.units[unitID]
  if type(unit) ~= "table" then return nil end
  return unit["lvl"]
end

------------------------------------------------------------------
-- Hauptfunktion: alle Quellen eines Items
------------------------------------------------------------------

------------------------------------------------------------------
-- Unerreichbare Quellen
--
-- Der Serverdatenbestand enthaelt Entwicklereintraege: Mobs, die im
-- Spiel nicht vorkommen, meist mit "[UNUSED]" im Namen und Dropchance
-- null. pfQuest gibt sie treu wieder - fuer einen Ausruestungsplaner
-- sind sie aber wertlos: ein Item, das nur dort haengt, kann man nicht
-- bekommen.
--
-- Vorsicht bei der Chance: bei Haendlern (V) und Quests (Q) bedeutet
-- eine fehlende Chance NICHT "nie", sondern "nicht zufaellig". Nur bei
-- echten Drops (U, O, C) ist null tatsaechlich unerreichbar.
------------------------------------------------------------------

local UNUSED_MARKERS = {
  "%[UNUSED%]", "%[DEPRECATED%]", "%[OLD%]", "%[PH%]", "%[TEST%]",
  "%[NYI%]", "^UNUSED", "Test Mob", "%(OLD%)", "%(unused%)",
}

------------------------------------------------------------------
-- Fraktionspruefung fuer Quests
--
-- pfQuest fuehrt an jeder Quest eine Rassenmaske. Die beobachteten
-- Werte 589 und 434 sind exakt die Bitsummen der beiden Fraktionen:
--   589 = Mensch 1 + Zwerg 4 + Nachtelf 8 + Gnom 64 + Hochelf 512
--   434 = Ork 2 + Untoter 16 + Tauren 32 + Troll 128 + Goblin 256
--
-- Ohne diese Pruefung landen Questbelohnungen der Gegenfraktion in der
-- Lootline - unerreichbar, aber unauffaellig, weil die Quest existiert.
------------------------------------------------------------------

local RACE_BITS = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 }

local FACTION_MASK = {
  Alliance = 589,
  Horde    = 434,
}

local function maskHas(mask, bit)
  return math.mod(math.floor(mask / bit), 2) == 1
end

function Sources:PlayerRaceMask()
  if self.raceMask then return self.raceMask end
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  self.raceMask = FACTION_MASK[faction or ""] or 0
  return self.raceMask
end

-- Teilen sich Questmaske und Spielerfraktion mindestens ein Volk?
function Sources:RaceAllows(questMask)
  if not questMask or questMask == 0 then return true end
  local mine = self:PlayerRaceMask()
  if mine == 0 then return true end   -- Fraktion unbekannt: durchlassen

  for i = 1, table.getn(RACE_BITS) do
    local b = RACE_BITS[i]
    if maskHas(questMask, b) and maskHas(mine, b) then return true end
  end
  return false
end

function Sources:IsReachable(entry)
  -- Quest der Gegenfraktion: existiert, aber nicht fuer diesen Charakter
  if entry.stype == "Q" and not self:RaceAllows(entry.questRace) then
    return false
  end

  local name = entry.name or ""
  for i = 1, table.getn(UNUSED_MARKERS) do
    if string.find(name, UNUSED_MARKERS[i]) then return false end
  end

  if entry.stype == "U" or entry.stype == "O" or entry.stype == "C" then
    if not entry.chance or entry.chance <= 0 then return false end
  end

  return true
end

local TYPE_LABEL = {
  ["U"] = "DROPS_FROM",
  ["O"] = "OBJECT",
  ["V"] = "VENDOR",
  ["Q"] = "QUEST",
  ["C"] = "OBJECT",
}

function Sources:GetItemSources(itemID, depth)
  if not self.available or not itemID then return nil end
  depth = depth or 0
  if depth > 1 then return nil end   -- Rekursion ueber refloot begrenzen

  local entry = self.items[itemID]
  if not entry or type(entry) ~= "table" then return nil end

  local L = BLL.L
  local out = {}
  local minChance = (BananaLootlineDB and BananaLootlineDB.minDropChance) or 0

  -- Direkte Quellen
  for stype, label in pairs(TYPE_LABEL) do
    local group = entry[stype]
    if group then
      for id, chance in pairs(group) do
        local numChance = tonumber(chance) or 0
        if numChance >= minChance then
          local name, zone, lvl, questLevel, questRace, giverName
          if stype == "U" or stype == "V" then
            name = self:UnitName(id)
            zone = self:UnitZone(id)
            lvl  = self:UnitLevel(id)
          elseif stype == "O" or stype == "C" then
            name = self:ObjectName(id)
          elseif stype == "Q" then
            name = self:QuestName(id)
            local q = self.quests and self.quests[id]
            if type(q) == "table" then
              questLevel = q["lvl"] or q["min"]
              questRace = q["race"]
              -- Ort der Quest ueber ihren Geber bestimmen. Ohne das
              -- landen alle Questbelohnungen in der Sammelgruppe
              -- "Ohne Ortsangabe" und man sieht nicht, wohin man muss.
              if q["start"] and q["start"]["U"] then
                local giver = q["start"]["U"][1]
                if giver then
                  zone = self:UnitZone(giver)
                  giverName = self:UnitName(giver)
                end
              end
            end
          end

          table.insert(out, {
            stype      = stype,
            typeLabel  = L[label],
            id         = id,
            name       = name,
            zone       = zone,
            level      = lvl,
            questLevel = questLevel,
            questRace  = questRace,
            giver      = giverName,
            -- Quest und Haendler sind sichere Quellen. pfQuest fuehrt dort
            -- 1 bzw. 0 - das ist kein Prozentwert. Als 1 % gelesen, verlor
            -- jede Questbelohnung gegen einen Mob-Drop ab 1,1 %.
            chance     = (stype ~= "Q" and stype ~= "V" and numChance > 0) and numChance or nil,
            sure       = (stype == "Q" or stype == "V") or nil,
          })
        end
      end
    end
  end

  -- Referenz-Loottabellen aufloesen: das Item haengt an einer geteilten
  -- Tabelle, die wiederum an Units haengt.
  if entry["L"] and self.refloot then
    for refID, refChance in pairs(entry["L"]) do
      local ref = self.refloot[refID]
      if type(ref) == "table" and ref["U"] then
        for unitID, uChance in pairs(ref["U"]) do
          local combined = (tonumber(refChance) or 100) * (tonumber(uChance) or 100) / 100
          if combined >= minChance then
            table.insert(out, {
              stype     = "U",
              typeLabel = L["DROPS_FROM"],
              id        = unitID,
              name      = self:UnitName(unitID),
              zone      = self:UnitZone(unitID),
              level     = self:UnitLevel(unitID),
              chance    = combined,
              viaRef    = refID,
            })
          end
        end
      end
    end
  end

  -- Unerreichbares aussortieren, bevor sortiert wird. Abschaltbar,
  -- falls jemand den Rohbestand sehen will.
  if not (BananaLootlineDB and BananaLootlineDB.showUnreachable) then
    local keep = {}
    for i = 1, table.getn(out) do
      if self:IsReachable(out[i]) then table.insert(keep, out[i]) end
    end
    out = keep
  end

  -- Nach Dropchance absteigend sortieren, sichere Quellen zuerst
  table.sort(out, function(a, b)
    local ca = a.sure and 100 or (a.chance or 0)
    local cb = b.sure and 100 or (b.chance or 0)
    return ca > cb
  end)

  -- Gleichnamige Quellen zusammenfassen. "Kolkar's Booty" existiert
  -- dreimal mit verschiedenen Objekt-IDs - dreimal dieselbe Zeile im
  -- Tooltip hilft niemandem. Die hoechste Chance gewinnt, die Anzahl
  -- wird vermerkt.
  local merged, byKey = {}, {}
  for i = 1, table.getn(out) do
    local e = out[i]
    local key = (e.name or "?") .. "|" .. (e.zone or "")
    local prev = byKey[key]
    if prev then
      prev.count = (prev.count or 1) + 1
      if (e.chance or 0) > (prev.chance or 0) then prev.chance = e.chance end
    else
      byKey[key] = e
      table.insert(merged, e)
    end
  end

  return merged
end

------------------------------------------------------------------
-- Umkehrung: welche Items droppt diese Unit?
-- (Grundlage fuer spaetere "Was kann ich in Dungeon X holen"-Ansicht.
--  Achtung: linearer Scan ueber die gesamte Itemtabelle, deshalb nur
--  auf Anfrage aufrufen und das Ergebnis cachen.)
------------------------------------------------------------------

local dropCache = {}

function Sources:GetUnitDrops(unitID)
  if not self.available then return nil end
  if dropCache[unitID] then return dropCache[unitID] end

  local out = {}
  for itemID, entry in pairs(self.items) do
    if type(entry) == "table" and entry["U"] and entry["U"][unitID] then
      table.insert(out, {
        id     = itemID,
        name   = self:ItemName(itemID),
        chance = entry["U"][unitID],
      })
    end
  end

  table.sort(out, function(a, b) return (a.chance or 0) > (b.chance or 0) end)
  dropCache[unitID] = out
  return out
end

------------------------------------------------------------------
-- Tooltip-Hook: Quellen an jeden Item-Tooltip anhaengen
------------------------------------------------------------------

-- Der 1.12-Client kennt KEIN GameTooltip:GetItem() - das kam erst in
-- spaeteren Versionen dazu. Der Hook darf den Link also nicht
-- zurueckfragen, sondern muss ihn sich beim Setzen merken.
--
-- Genau daran ist der alte Hook gescheitert: beim Ueberfahren von Items
-- lief jedes Mal "attempt to call method GetItem (a nil value)" in den
-- Chat. Dass es auf einem Charakter zu funktionieren schien, lag nur
-- daran, dass dort ein anderer Pfad griff.

local lastTooltipItem = nil
local pendingLink = nil     -- vom zuletzt gesetzten Tooltip

local function AppendSources(tooltip, knownLink)
  if not BananaLootlineDB or not BananaLootlineDB.tooltipSources then return end
  if not Sources.available then return end
  if not tooltip or not tooltip.AddLine then return end

  local link = knownLink or pendingLink

  -- Falls der Client die Funktion doch mitbringt, nutzen wir sie -
  -- aber nur, wenn sie wirklich existiert.
  if not link and type(tooltip.GetItem) == "function" then
    local _, l = tooltip:GetItem()
    link = l
  end
  if not link then return end

  local itemID = BLL.Scanner:GetItemID(link)
  if not itemID then return end

  if lastTooltipItem == itemID then return end
  lastTooltipItem = itemID

  local list = Sources:GetItemSources(itemID)
  if not list or table.getn(list) == 0 then return end

  local maxN = BananaLootlineDB.maxSources or 5
  local shown = math.min(maxN, table.getn(list))

  tooltip:AddLine(" ")
  tooltip:AddLine("|cffffcc33Banana|cffffffffLootline|r", 1, 1, 1)

  for i = 1, shown do
    local s = list[i]
    local right = ""
    if s.chance then
      right = string.format("%.1f%%", s.chance)
    end
    local left = s.name or "?"
    if s.count and s.count > 1 then
      left = left .. " |cff666666x" .. s.count .. "|r"
    end
    if s.zone then
      left = left .. " |cff888888(" .. s.zone .. ")|r"
    end
    tooltip:AddDoubleLine("  " .. left, right, 0.8, 0.8, 0.8, 0.6, 0.9, 0.6)
  end

  if table.getn(list) > shown then
    tooltip:AddLine("  |cff666666+ " .. (table.getn(list) - shown) .. " weitere|r")
  end

  tooltip:Show()
end

------------------------------------------------------------------
-- Hooks auf die Setter, die den Link liefern
--
-- 1.12 kennt kein HookScript, also klassisches Function-Hooking. Jeder
-- Setter merkt sich den Link, bevor der Tooltip gebaut wird.
------------------------------------------------------------------

local origSetHyperlink = GameTooltip.SetHyperlink
GameTooltip.SetHyperlink = function(self, link)
  pendingLink = link
  origSetHyperlink(self, link)
  AppendSources(self, link)
end

local origSetBagItem = GameTooltip.SetBagItem
if origSetBagItem then
  GameTooltip.SetBagItem = function(self, bag, slot)
    pendingLink = GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
    local a, b = origSetBagItem(self, bag, slot)
    AppendSources(self, pendingLink)
    return a, b
  end
end

local origSetInventoryItem = GameTooltip.SetInventoryItem
if origSetInventoryItem then
  GameTooltip.SetInventoryItem = function(self, unit, slot, a1, a2)
    pendingLink = GetInventoryItemLink and GetInventoryItemLink(unit, slot) or nil
    local r1, r2 = origSetInventoryItem(self, unit, slot, a1, a2)
    AppendSources(self, pendingLink)
    return r1, r2
  end
end

local origSetLootItem = GameTooltip.SetLootItem
if origSetLootItem then
  GameTooltip.SetLootItem = function(self, slot)
    pendingLink = GetLootSlotLink and GetLootSlotLink(slot) or nil
    local r = origSetLootItem(self, slot)
    AppendSources(self, pendingLink)
    return r
  end
end

-- Beim Verstecken zuruecksetzen, sonst bleibt beim erneuten Anfahren
-- desselben Items der Block aus.
local origHide = GameTooltip.Hide
GameTooltip.Hide = function(self)
  lastTooltipItem = nil
  pendingLink = nil
  origHide(self)
end
