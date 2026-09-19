--[[----------------------------------------------------------------------
  BananaLootline - Candidates.lua

  Hier entstehen die eigentlichen Vorschlaege. Drei Schritte:

  1. POOL BAUEN
     Ueber pfDB["items"]["data"] laufen und fuer jedes Item die Stufe seiner
     Quelle bestimmen. Units haben ["lvl"] = "24-25", Quests haben ["lvl"].
     Was von einer Quelle im eigenen Stufenbereich kommt, ist ein Kandidat.
     Das ist der Trick, der uns die Itemdatenbank vorerst erspart: wir
     brauchen keine Itemwerte, um zu entscheiden, WELCHE Items ueberhaupt
     interessant sind.

  2. DATEN HOLEN
     Fuer die Kandidaten Slot, Qualitaet und Werte besorgen. Ist ein Item
     nicht im Clientcache, stoesst der Tooltip-Aufruf eine Serverabfrage an
     und beim naechsten Durchlauf sind die Daten da. Streng gedrosselt -
     zu schnelle Abfragen quittiert der 1.12-Server mit Disconnect.
     Ergebnis landet in BananaLootlineDB.itemcache und ueberlebt Reloads,
     der Aufwand faellt also einmal pro Stufenbereich an.

  3. BEWERTEN
     Kandidaten pro Slot gegen das angelegte Item scoren (Weights.lua) und
     die besseren mit Quelle ausgeben.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Candidates = {}
local Cand = BLL.Candidates

-- Hochzaehlen, wenn sich aendert, WELCHE Felder ein Cache-Eintrag braucht.
-- Eintraege aelterer Fassungen werden dann beim naechsten Lauf neu
-- aufgebaut, statt stillschweigend mit fehlenden Feldern weiterzulaufen.
-- 3: Scanner liest RAP, Verteidigung und Schulschaden jetzt richtig.
-- 4: Dauerhafte Aussortier-Markierungen werden neu bewertet.
-- Aeltere Eintraege werden verworfen und neu eingelesen.
Cand.CACHE_VERSION = 4

Cand.pool     = nil     -- [itemID] = sourceLevel
Cand.poolSize = 0
Cand.state    = "idle"  -- idle | indexing | querying | ready

------------------------------------------------------------------
-- Slotzuordnung
------------------------------------------------------------------

-- INVTYPE aus GetItemInfo -> unsere Slotkeys (Ringe/Schmuck/Waffen
-- passen in mehrere).
Cand.INVTYPE_SLOTS = {
  ["INVTYPE_HEAD"]            = { "HeadSlot" },
  ["INVTYPE_NECK"]            = { "NeckSlot" },
  ["INVTYPE_SHOULDER"]        = { "ShoulderSlot" },
  ["INVTYPE_CLOAK"]           = { "BackSlot" },
  ["INVTYPE_CHEST"]           = { "ChestSlot" },
  ["INVTYPE_ROBE"]            = { "ChestSlot" },
  ["INVTYPE_WRIST"]           = { "WristSlot" },
  ["INVTYPE_HAND"]            = { "HandsSlot" },
  ["INVTYPE_WAIST"]           = { "WaistSlot" },
  ["INVTYPE_LEGS"]            = { "LegsSlot" },
  ["INVTYPE_FEET"]            = { "FeetSlot" },
  ["INVTYPE_FINGER"]          = { "Finger0Slot", "Finger1Slot" },
  ["INVTYPE_TRINKET"]         = { "Trinket0Slot", "Trinket1Slot" },
  ["INVTYPE_WEAPON"]          = { "MainHandSlot", "SecondaryHandSlot" },
  ["INVTYPE_2HWEAPON"]        = { "MainHandSlot" },
  ["INVTYPE_WEAPONMAINHAND"]  = { "MainHandSlot" },
  ["INVTYPE_WEAPONOFFHAND"]   = { "SecondaryHandSlot" },
  ["INVTYPE_SHIELD"]          = { "SecondaryHandSlot" },
  ["INVTYPE_HOLDABLE"]        = { "SecondaryHandSlot" },
  ["INVTYPE_RANGED"]          = { "RangedSlot" },
  ["INVTYPE_RANGEDRIGHT"]     = { "RangedSlot" },
  ["INVTYPE_THROWN"]          = { "RangedSlot" },
  ["INVTYPE_RELIC"]           = { "RangedSlot" },
}

local WEAPON_SLOTS = {
  ["MainHandSlot"] = true, ["SecondaryHandSlot"] = true, ["RangedSlot"] = true,
}

------------------------------------------------------------------
-- Ruestungsarten
--
-- GetItemInfo liefert den Subtyp lokalisiert, deshalb pro Sprache.
-- Unbekannter Subtyp wird durchgelassen statt verworfen - lieber ein
-- Vorschlag zu viel als ein fehlender.
------------------------------------------------------------------

local ARMOR_NAMES = {
  enUS = { CLOTH = "Cloth", LEATHER = "Leather", MAIL = "Mail", PLATE = "Plate", SHIELD = "Shields" },
  deDE = { CLOTH = "Stoff", LEATHER = "Leder", MAIL = "Schwere R\195\188stung", PLATE = "Plattenpanzer", SHIELD = "Schilde" },
}

local function ArmorKey(subtype)
  if not subtype then return nil end
  -- Clientsprache, nicht Anzeigesprache: GetItemInfo liefert die
  -- Ruestungsart in der Sprache des Clients.
  local map = ARMOR_NAMES[BLL.clientLocale] or ARMOR_NAMES.enUS
  for key, name in pairs(map) do
    if subtype == name then return key end
  end
  return nil
end

-- Ruestungskompetenzen. Kettenruestung gibt es fuer Jaeger und Schamanen
-- erst ab Stufe 40, Platte fuer Krieger und Paladine ebenfalls.
local function AllowedArmor(class, level)
  if class == "WARRIOR" or class == "PALADIN" then
    if level >= 40 then
      return { CLOTH = 1, LEATHER = 1, MAIL = 1, PLATE = 1, SHIELD = 1 }
    end
    return { CLOTH = 1, LEATHER = 1, MAIL = 1, SHIELD = 1 }
  elseif class == "HUNTER" or class == "SHAMAN" then
    local t = { CLOTH = 1, LEATHER = 1 }
    if level >= 40 then t.MAIL = 1 end
    if class == "SHAMAN" then t.SHIELD = 1 end
    return t
  elseif class == "ROGUE" or class == "DRUID" then
    return { CLOTH = 1, LEATHER = 1 }
  end
  return { CLOTH = 1 }   -- Priester, Magier, Hexenmeister
end

------------------------------------------------------------------
-- Waffenkompetenzen
--
-- Der Ruestungsfilter allein reicht nicht: ein Zauberstab landet im
-- Distanzslot und wurde deshalb einem Jaeger vorgeschlagen, obwohl er
-- ihn nie fuehren kann. Dasselbe haette einem Magier eine Streitaxt
-- empfohlen.
--
-- Subklassen der Itemklasse 2, wie im Menue der Datenbank:
--   0 Einhandaxt   1 Zweihandaxt  2 Bogen        3 Schusswaffe
--   4 Einhandkolben 5 Zweihandkolben 6 Stangenwaffe
--   7 Einhandschwert 8 Zweihandschwert 10 Stab
--  13 Faustwaffe   14 Sonstiges   15 Dolch       16 Wurfwaffe
--  18 Armbrust     19 Zauberstab  20 Angelrute
------------------------------------------------------------------

local WEAPON_PROFICIENCY = {
  WARRIOR = { [0]=1,[1]=1,[2]=1,[3]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1,
              [10]=1,[13]=1,[14]=1,[15]=1,[16]=1,[18]=1,[20]=1 },
  PALADIN = { [0]=1,[1]=1,[4]=1,[5]=1,[6]=1,[7]=1,[8]=1,[14]=1,[20]=1 },
  HUNTER  = { [0]=1,[1]=1,[2]=1,[3]=1,[6]=1,[7]=1,[8]=1,[10]=1,
              [13]=1,[14]=1,[15]=1,[16]=1,[18]=1,[20]=1 },
  -- Keine Einhandaexte: Icy Veins nennt fuer Schurken Dolche, Faust-
  -- waffen, Schwerter, Streitkolben sowie Bogen, Armbrust, Schusswaffe
  -- und Wurfwaffe.
  ROGUE   = { [2]=1,[3]=1,[4]=1,[7]=1,[13]=1,[14]=1,[15]=1,
              [16]=1,[18]=1,[20]=1 },
  PRIEST  = { [4]=1,[10]=1,[14]=1,[15]=1,[19]=1,[20]=1 },
  -- Keine Faustwaffen: Wowhead nennt fuer Classic-Schamanen Ein- und
  -- Zweihandaexte und -kolben, Dolche und Staebe. Zweihandaexte und
  -- -kolben (1, 5) gibt es nur ueber ein Verstaerkungstalent - siehe
  -- TALENT_WEAPON.
  SHAMAN  = { [0]=1,[1]=1,[4]=1,[5]=1,[10]=1,[14]=1,[15]=1,[20]=1 },
  MAGE    = { [7]=1,[10]=1,[14]=1,[15]=1,[19]=1,[20]=1 },
  WARLOCK = { [7]=1,[10]=1,[14]=1,[15]=1,[19]=1,[20]=1 },
  DRUID   = { [4]=1,[5]=1,[6]=1,[10]=1,[13]=1,[14]=1,[15]=1,[20]=1 },
}

-- Ab welcher Stufe eine Klasse Beidhaendigkeit beim Klassenlehrer
-- lernen kann. Quelle: Allakhazam-Wiki "Dual Wield (WoW)": Schurken 10,
-- Krieger und Jaeger 20. Gilt nur, solange der Client die Fertigkeit
-- nicht schon meldet - dann zaehlt der tatsaechliche Stand.
local DUAL_WIELD_LEVEL = { ROGUE = 10, WARRIOR = 20, HUNTER = 20 }

-- Ab welcher Stufe der Waffenmeister eine fehlende Fertigkeit lehrt.
-- Quelle: Wowhead "Best Hunter Weapons - WoW Classic": ab 10, Stangen-
-- waffen ab 20. Die Schamanen-Seite nennt ebenfalls Stufe 10.
local LEARN_LEVEL_DEFAULT = 10
local LEARN_LEVEL = { [6] = 20 }

-- Waffenarten, die eine Klasse nur ueber ein Talent bekommt. Fehlt die
-- Fertigkeit, ist das Talent nicht gewaehlt - dann kein Vorschlag, denn
-- ein Waffenmeister hilft hier nicht.
local TALENT_WEAPON = { SHAMAN = { [1] = true, [5] = true } }

-- Fertigkeitsnamen im Client -> Waffensubklasse. Nur die Sprache des
-- Clients zaehlt, nicht die Anzeigesprache. Deutsche Namen sind nicht
-- im Spiel gegengeprueft; passt keiner, faellt das Addon auf die reine
-- Klassentabelle zurueck statt falsch zu sperren.
local SKILL_SUBCLASS = {
  enUS = {
    ["Axes"] = 0, ["Two-Handed Axes"] = 1, ["Bows"] = 2, ["Guns"] = 3,
    ["Maces"] = 4, ["Two-Handed Maces"] = 5, ["Polearms"] = 6,
    ["Swords"] = 7, ["Two-Handed Swords"] = 8, ["Staves"] = 10,
    ["Fist Weapons"] = 13, ["Daggers"] = 15, ["Thrown"] = 16,
    ["Crossbows"] = 18, ["Wands"] = 19,
  },
  deDE = {
    ["\195\132xte"] = 0, ["Zweihand\195\164xte"] = 1, ["Bogen"] = 2,
    ["Schusswaffen"] = 3, ["Streitkolben"] = 4, ["Zweihandstreitkolben"] = 5,
    ["Stangenwaffen"] = 6, ["Schwerter"] = 7, ["Zweihandschwerter"] = 8,
    ["St\195\164be"] = 10, ["Faustwaffen"] = 13, ["Dolche"] = 15,
    ["Wurfwaffen"] = 16, ["Armbr\195\188ste"] = 18, ["Zauberst\195\164be"] = 19,
  },
}
local DUAL_WIELD_SKILL = { enUS = "Dual Wield", deDE = "Beidh\195\164ndigkeit" }

-- Gelernte Waffenfertigkeiten aus dem Fertigkeitenfenster lesen.
-- Eingeklappte Ueberschriften verbergen ihre Zeilen, deshalb wird kurz
-- alles aufgeklappt und danach der alte Zustand wiederhergestellt.
function Cand:ScanWeaponSkills()
  self.skillsDirty = nil
  if not GetNumSkillLines or not GetSkillLineInfo then self.skills = nil; return end

  local loc = BLL.clientLocale or "enUS"
  local names = SKILL_SUBCLASS[loc] or SKILL_SUBCLASS.enUS
  local dwName = DUAL_WIELD_SKILL[loc] or DUAL_WIELD_SKILL.enUS

  local collapsed = {}
  for i = 1, GetNumSkillLines() do
    local name, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and not isExpanded then collapsed[name] = true end
  end
  local anyCollapsed = next(collapsed) ~= nil
  if anyCollapsed and ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end

  local known, any, dw = {}, false, false
  for i = 1, GetNumSkillLines() do
    local name, isHeader = GetSkillLineInfo(i)
    if name and not isHeader then
      local sc = names[name]
      if sc then known[sc] = true; any = true end
      if name == dwName then dw = true end
    end
  end

  if anyCollapsed and CollapseSkillHeader then
    for i = GetNumSkillLines(), 1, -1 do
      local name, isHeader = GetSkillLineInfo(i)
      if isHeader and collapsed[name] then pcall(CollapseSkillHeader, i) end
    end
  end

  -- Keine einzige Waffenfertigkeit erkannt: Sprache unbekannt oder
  -- Namen weichen ab. Dann lieber gar nicht pruefen als alles sperren.
  self.skills = any and { known = known, dualWield = dw } or nil
end

function Cand:WeaponSkills()
  if self.skills == nil or self.skillsDirty then self:ScanWeaponSkills() end
  return self.skills
end

function Cand:DualWieldLevel(class)
  return DUAL_WIELD_LEVEL[class or ""]
end

function Cand:CanUseWeapon(itemclass, subclass, class)
  if itemclass ~= 2 then return true end          -- keine Waffe
  if subclass == nil then return true end          -- unbekannt, durchlassen
  local prof = WEAPON_PROFICIENCY[class or ""]
  if not prof then return true end
  return prof[subclass] == 1
end

------------------------------------------------------------------
-- Quellenstufe bestimmen
------------------------------------------------------------------

-- "24-25" -> 24 ; "60" -> 60
local function ParseLevel(str)
  if not str then return nil end
  if type(str) == "number" then return str end
  local _, _, low = string.find(str, "^(%d+)")
  return tonumber(low)
end

-- Niedrigste Quellenstufe eines Items. Niedrigste, weil ein Item, das auch
-- ein Stufe-25-Mob droppt, fuer einen Stufe-25-Charakter erreichbar ist -
-- selbst wenn es woanders von etwas Hoeherem faellt.
function Cand:SourceLevel(itemID, entry)
  local best = nil
  local S = BLL.Sources

  if entry["U"] then
    for unitID in pairs(entry["U"]) do
      local lvl = ParseLevel(S:UnitLevel(unitID))
      if lvl and (not best or lvl < best) then best = lvl end
    end
  end

  if entry["Q"] and S.quests then
    for questID in pairs(entry["Q"]) do
      local q = S.quests[questID]
      if type(q) == "table" then
        local lvl = ParseLevel(q["lvl"]) or ParseLevel(q["min"])
        if lvl and (not best or lvl < best) then best = lvl end
      end
    end
  end

  return best
end

------------------------------------------------------------------
-- Schritt 1: Pool bauen (gestueckelt, damit das Spiel nicht einfriert)
------------------------------------------------------------------

local CHUNK = 1500        -- Eintraege pro Frame
local indexKey = nil
local indexBand = nil

function Cand:StartIndex(minLvl, maxLvl)
  if not BLL.Sources.available then
    BLL:Print("|cffff0000pfQuest fehlt - ohne die Datenbank keine Vorschlaege.|r")
    return false
  end

  self.pool     = {}
  self.poolSize = 0
  self.state    = "indexing"
  indexKey  = nil
  indexBand = { min = minLvl, max = maxLvl }

  BLL:Print(string.format("Suche Kandidaten fuer Stufe %d-%d ...", minLvl, maxLvl))
  return true
end

function Cand:IndexChunk()
  local items = BLL.Sources.items
  if not items then self.state = "idle" return end

  local processed = 0
  local key, entry = next(items, indexKey)

  while key and processed < CHUNK do
    if type(entry) == "table" then
      local lvl = self:SourceLevel(key, entry)
      if lvl and lvl >= indexBand.min and lvl <= indexBand.max then
        self.pool[key] = lvl
        self.poolSize = self.poolSize + 1
      end
    end
    indexKey = key
    key, entry = next(items, indexKey)
    processed = processed + 1
  end

  if not key then
    BLL:Print(string.format("%d Kandidaten gefunden. Hole Itemdaten ...", self.poolSize))
    self:StartQuery()
  end
end

------------------------------------------------------------------
-- Schritt 2: Itemdaten besorgen (gedrosselt)
--
-- Wichtig: eine Serverantwort kommt NICHT sofort. Wer anfragt und im
-- selben Moment liest, bekommt nichts und fragt beim naechsten Durchlauf
-- erneut an - doppelte Last ohne Nutzen. Deshalb saubere Trennung:
--
--   requesting -> jedes unbekannte Item GENAU EINMAL anfragen
--   waiting    -> kurz warten, damit die Antworten eintreffen
--   collecting -> nur noch lesen, nie anfragen
--
-- Erst wenn nach dem Einsammeln noch etwas fehlt, gibt es eine zweite
-- Runde. Maximal zwei, danach wird der Rest als nicht auffindbar vermerkt.
------------------------------------------------------------------

local queue       = {}    -- aktuell abzuarbeitende IDs
local queueIndex  = 1
local queryTimer  = 0
local waitTimer   = 0
local resolved    = 0
local round       = 1
local MAX_ROUNDS  = 2
local WAIT_SECONDS = 4

------------------------------------------------------------------
-- Vorbefuellung aus der importierten ItemDB
--
-- Das ist der eigentliche Gewinn des Imports: liegen Slot, Qualitaet und
-- Werte lokal vor, braucht es fuer diese Items KEINE Serverabfrage mehr.
-- Von 658 Kandidaten bleiben so nur die uebrig, die der Import nicht
-- kennt - meist eine Handvoll statt mehrerer hundert.
------------------------------------------------------------------

-- InventoryType des Servers -> INVTYPE-String, wie GetItemInfo ihn liefert
local SLOTNUM_INVTYPE = {
  [1]  = "INVTYPE_HEAD",           [2]  = "INVTYPE_NECK",
  [3]  = "INVTYPE_SHOULDER",       [5]  = "INVTYPE_CHEST",
  [6]  = "INVTYPE_WAIST",          [7]  = "INVTYPE_LEGS",
  [8]  = "INVTYPE_FEET",           [9]  = "INVTYPE_WRIST",
  [10] = "INVTYPE_HAND",           [11] = "INVTYPE_FINGER",
  [12] = "INVTYPE_TRINKET",        [13] = "INVTYPE_WEAPON",
  [14] = "INVTYPE_SHIELD",         [15] = "INVTYPE_RANGED",
  [16] = "INVTYPE_CLOAK",          [17] = "INVTYPE_2HWEAPON",
  [20] = "INVTYPE_ROBE",           [21] = "INVTYPE_WEAPONMAINHAND",
  [22] = "INVTYPE_WEAPONOFFHAND",  [23] = "INVTYPE_HOLDABLE",
  [25] = "INVTYPE_THROWN",         [26] = "INVTYPE_RANGEDRIGHT",
  [28] = "INVTYPE_RELIC",
}

-- Ruestungsart aus der Subklasse des Servers (itemclass 4 = Ruestung)
local SUBCLASS_ARMOR = {
  [1] = "CLOTH", [2] = "LEATHER", [3] = "MAIL", [4] = "PLATE", [6] = "SHIELD",
}

function Cand:PreloadFromItemDB()
  if not BLL.ItemDB or not BLL.ItemDB.loaded then return 0, 0 end

  local cache = BananaLootlineDB.itemcache
  local player = BLL.player or {}
  local level = player.level or 60
  local allowedArmor = AllowedArmor(player.class, level)

  local skipped, needStats = 0, 0

  for itemID in pairs(self.pool) do
    local cached = cache[itemID]
    if cached and cached.cv ~= Cand.CACHE_VERSION and not cached.skip then
      cache[itemID] = nil
      cached = nil
    end
    -- Aussortiert wegen Stufe, Ruestungsart oder Klasse haengt vom
    -- aktuellen Charakter ab: nach einem Aufstieg darf Kette ab 40 oder
    -- ein Teil fuer Stufe 18 wieder rein. Solche Markierungen werden
    -- jedes Mal neu aus dem Import berechnet - das kostet keine
    -- Serveranfrage. Aeltere Markierungen ohne "pre" stammen aus
    -- Fassungen, in denen sie nie wieder verschwanden; sie werden fuer
    -- Items aus dem Import ebenfalls neu bewertet.
    if cached and cached.skip and not cached.fail
       and (cached.pre or cached.cv ~= Cand.CACHE_VERSION)
       and BLL.ItemDB:Get(itemID) then
      cache[itemID] = nil
      cached = nil
    end
    if not cached then
      local e = BLL.ItemDB:Get(itemID)
      if e then
        local invtype = SLOTNUM_INVTYPE[e.slot or 0]
        local armor = (e.itemclass == 4) and SUBCLASS_ARMOR[e.subclass or 0] or nil

        -- Aussortieren, was der Charakter ohnehin nicht tragen kann.
        -- Genau das spart die Masse der Serverabfragen.
        local usable = true
        if not invtype then usable = false end
        if armor and not allowedArmor[armor] then usable = false end
        -- Stufe mit Vorausplanung: sonst fehlen genau die Teile, die
        -- die Planung mit "ab 18" zeigen soll.
        if e.reqlevel and e.reqlevel > level + self:PlanAhead() then usable = false end
        if e.classmask and not BLL.ItemDB:MaskAllows(e.classmask, player.class) then
          usable = false
        end
        if not self:CanUseWeapon(e.itemclass, e.subclass, player.class) then
          usable = false
        end

        if not usable then
          cache[itemID] = { skip = 1, pre = 1 }
          skipped = skipped + 1
        else
          local stats = e.stats
          local hasStats = false
          if stats then
            for _ in pairs(stats) do hasStats = true break end
          end

          if hasStats then
            -- Vollstaendig aus dem Import bedienbar, keine Abfrage noetig.
            cache[itemID] = {
              n = e.name or ("Item " .. itemID),
              q = e.quality, r = e.reqlevel, e = invtype, a = armor,
              cm = e.classmask, ic = e.itemclass, sc = e.subclass,
              st = stats, use = e.use, db = 1, cv = Cand.CACHE_VERSION,
            }
          else
            -- Der Export kennt das Item, aber ohne Werte. Wir schreiben
            -- es bewusst NICHT in den Cache: dadurch bleibt es in der
            -- Warteschlange und der Tooltipscan holt die Werte nach.
            -- Wuerden wir es mit leeren Stats eintragen, bekaeme es
            -- fuer immer Score 0 und taeuchte nie als Upgrade auf.
            needStats = needStats + 1
          end
        end
      end
    end
  end

  return skipped, needStats
end

function Cand:StartQuery()
  queue = {}
  queueIndex = 1
  resolved = 0
  round = 1

  BananaLootlineDB.itemcache = BananaLootlineDB.itemcache or {}
  local cache = BananaLootlineDB.itemcache

  -- Erst aus dem Import bedienen, dann erst den Server fragen.
  local skipped, needStats = self:PreloadFromItemDB()
  if skipped > 0 or needStats > 0 then
    BLL:Print(string.format("Import ausgewertet: %d Items aussortiert "
      .. "(falscher Slot, falsche Ruestungsart oder Stufe zu hoch).",
      skipped))
  end

  for itemID in pairs(self.pool) do
    -- Bereits bekannte Items (auch als nicht auffindbar vermerkte)
    -- ueberspringen. Nach einem Disconnect setzt der naechste Lauf
    -- deshalb dort an, wo der letzte aufgehoert hat.
    if not cache[itemID] then
      table.insert(queue, itemID)
    end
  end

  local total = table.getn(queue)
  if total == 0 then
    self.state = "ready"
    BLL:Print("Alle Itemdaten bereits im Cache. Fertig.")
    if BLL.UI and BLL.UI.frame and BLL.UI.frame:IsVisible() then BLL.UI:Refresh() end
    return
  end

  self.state = "requesting"
  local rate = (BananaLootlineDB and BananaLootlineDB.queryRate) or 8
  BLL:Print(string.format("%d unbekannte Items, frage sie an (ca. %d Sekunden). "
    .. "Laeuft im Hintergrund, /bll stop bricht ab.", total, math.ceil(total / rate)))
end

-- Daten eines Items uebernehmen. true = erledigt.
function Cand:StoreItem(itemID)
  local name, link, quality, reqLevel, itype, subtype, stack, equipLoc = GetItemInfo(itemID)
  if not name then return false end

  if not equipLoc or equipLoc == "" or not self.INVTYPE_SLOTS[equipLoc] then
    BananaLootlineDB.itemcache[itemID] = { skip = 1 }
    return true
  end

  BananaLootlineDB.itemcache[itemID] = {
    n  = name,
    q  = quality,
    r  = reqLevel,
    e  = equipLoc,
    a  = ArmorKey(subtype),
    st = BLL.Scanner:GetStats(itemID) or {},
  }
  return true
end

-- Anfragephase: pro Tick ein Item beim Server anfragen.
function Cand:RequestTick(elapsed)
  queryTimer = queryTimer - elapsed
  if queryTimer > 0 then return end

  local rate = (BananaLootlineDB and BananaLootlineDB.queryRate) or 8
  queryTimer = 1 / rate

  local total = table.getn(queue)
  if queueIndex > total then
    self.state = "waiting"
    waitTimer = WAIT_SECONDS
    return
  end

  local itemID = queue[queueIndex]
  queueIndex = queueIndex + 1

  -- Schon im Clientcache? Dann direkt uebernehmen, keine Anfrage noetig.
  if self:StoreItem(itemID) then
    resolved = resolved + 1
  else
    -- Genau eine Anfrage. Die Antwort holen wir uns spaeter ab.
    BLL.Scanner:GetLines(itemID)
  end
end

-- Sammelphase: nur lesen, niemals anfragen.
function Cand:CollectTick()
  local pending = {}

  for i = 1, table.getn(queue) do
    local itemID = queue[i]
    if not BananaLootlineDB.itemcache[itemID] then
      if self:StoreItem(itemID) then
        resolved = resolved + 1
      else
        table.insert(pending, itemID)
      end
    end
  end

  local left = table.getn(pending)

  if left > 0 and round < MAX_ROUNDS then
    round = round + 1
    queue = pending
    queueIndex = 1
    self.state = "requesting"
    BLL:Print(string.format("%d Items noch offen, zweite Runde.", left))
    return
  end

  -- Endgueltig nicht auffindbar: vermerken, damit der naechste Lauf sie
  -- nicht erneut beim Server anfragt.
  for i = 1, left do
    BananaLootlineDB.itemcache[pending[i]] = { skip = 1, fail = 1 }
  end

  self.state = "ready"
  BLL:Print(string.format("Fertig: %d Items eingelesen%s.",
    resolved, (left > 0) and (", " .. left .. " nicht auffindbar") or ""))
  if BLL.UI and BLL.UI.frame and BLL.UI.frame:IsVisible() then BLL.UI:Refresh() end
end

function Cand:Stop()
  if self.state == "idle" or self.state == "ready" then
    BLL:Print("Es laeuft gerade nichts.")
    return
  end
  self.state = "ready"
  BLL:Print(string.format("Abgebrochen. %d Items sind gespeichert und "
    .. "bleiben erhalten.", resolved))
end

function Cand:Progress()
  if self.state == "indexing" then
    return "Durchsuche Datenbank ..."
  elseif self.state == "requesting" then
    return string.format("Frage Items an: %d/%d (Runde %d)",
      queueIndex - 1, table.getn(queue), round)
  elseif self.state == "waiting" then
    return string.format("Warte auf Serverantworten (%.0fs)", waitTimer)
  elseif self.state == "collecting" then
    return "Werte Antworten aus ..."
  end
  return nil
end

function Cand:Progress()
  if self.state == "indexing" then
    return "Durchsuche Datenbank ..."
  elseif self.state == "querying" then
    return string.format("Hole Itemdaten: %d/%d", queueIndex, table.getn(queue))
  end
  return nil
end

------------------------------------------------------------------
-- Schritt 3: Vorschlaege berechnen
------------------------------------------------------------------

-- Wie viele Stufen vorausgeplant wird. Eine Lootline ist ein Wegplan,
-- kein Momentaufnahme-Vergleich: ein Teil, dem zwei Stufen fehlen,
-- gehoert auf die Liste - sonst sieht man das lohnendste Ziel nicht.
-- Solche Items werden im Fenster als gesperrt gekennzeichnet.
function Cand:PlanAhead()
  local n = BananaLootlineDB and BananaLootlineDB.planAhead
  if n == nil then return 6 end
  return n
end

function Cand:IsUsable(entry, class, level, allowedArmor, itemID)
  if entry.skip then return false end

  -- Aeltere Cache-Eintraege stammen aus einer Fassung ohne Waffenpruefung
  -- und fuehren keine Subklasse. Da unbekannte Subklassen durchgelassen
  -- werden, rutschte dadurch weiterhin ein Zauberstab zum Jaeger durch.
  -- Also aus der Itemdatenbank nachtragen, statt den Cache zu verwerfen.
  if entry.sc == nil and itemID and BLL.ItemDB and BLL.ItemDB.loaded then
    local db = BLL.ItemDB:Get(itemID)
    if db then
      entry.ic = db.itemclass
      entry.sc = db.subclass
      if entry.cm == nil then entry.cm = db.classmask end
    end
  end
  if entry.r and entry.r > (level + self:PlanAhead()) then return false end

  -- Ruestungsart pruefen. Schmuck, Ringe, Halsketten und Waffen haben
  -- keinen Ruestungsschluessel und werden durchgelassen.
  if entry.a and not allowedArmor[entry.a] then return false end

  -- Klassenbeschraenkung aus dem Import. Ein "Arcanist Circlet" ist
  -- magierexklusiv - ohne diese Pruefung wuerde es jedem Stoffträger
  -- vorgeschlagen.
  if entry.cm and entry.cm ~= 0 and entry.cm ~= -1 then
    if BLL.ItemDB and not BLL.ItemDB:MaskAllows(entry.cm, class) then
      return false
    end
  end

  if not self:CanUseWeapon(entry.ic, entry.sc, class) then
    return false
  end

  return true
end

function Cand:GetUpgrades(slotKey, maxResults)
  if not self.pool then return nil end

  maxResults = maxResults or 5
  local cache = BananaLootlineDB.itemcache or {}
  local player = BLL.player or {}
  local level = player.level or 60
  local class = player.class
  local allowedArmor = AllowedArmor(class, level)
  local isWeapon = WEAPON_SLOTS[slotKey]

  ----------------------------------------------------------------
  -- Score des angelegten Items, inklusive seiner eigenen Zusaetze.
  -- Sonst gewaenne jeder Kandidat allein dadurch, dass beim
  -- Vergleichsstueck Setbonus und Use-Effekt unter den Tisch fallen.
  ----------------------------------------------------------------
  local equipped = BLL.Gear.equipped[slotKey]
  local baseScore = 0
  if equipped then
    baseScore = BLL.Weights:Score(equipped.stats, isWeapon)

    local eqEntry = equipped.id and cache[equipped.id]
    if eqEntry and eqEntry.use then
      baseScore = baseScore + BLL.Weights:UseEffectScore(eqEntry.use)
    end

    -- Setbonus des angelegten Teils: es zaehlt als getragen, deshalb
    -- wird es beim Zaehlen NICHT ausgelassen.
    if BLL.SetDB and BLL.SetDB.loaded and equipped.id then
      local setID = BLL.SetDB:GetSetOf(equipped.id)
      if setID then
        local worn = BLL.SetDB:CountEquipped(setID, slotKey)
        local gained = BLL.SetDB:BonusGain(setID, worn)
        if gained then
          baseScore = baseScore + BLL.Weights:Score(nil, isWeapon, gained)
        end
      end
    end
  end

  local out = {}

  for itemID, srcLevel in pairs(self.pool) do
    local entry = cache[itemID]
    if entry and not entry.skip then
      local slots = self.INVTYPE_SLOTS[entry.e or ""]
      local fits = false
      if slots then
        for i = 1, table.getn(slots) do
          if slots[i] == slotKey then fits = true break end
        end
      end

      -- Waffe in der Schildhand verlangt Beidhaendigkeit. Schilde und
      -- Nebenhandgegenstaende sind davon nicht betroffen.
      local reqEff = entry.r
      local skills = self:WeaponSkills()
      local dualWieldNeeded, learnSkill

      if fits and slotKey == "SecondaryHandSlot"
         and (entry.e == "INVTYPE_WEAPON" or entry.e == "INVTYPE_WEAPONOFFHAND") then
        -- Meldet der Client Beidhaendigkeit, gilt sie ab sofort. Sonst
        -- entscheidet die Stufe, ab der der Klassenlehrer sie anbietet.
        if not (skills and skills.dualWield) then
          local dw = self:DualWieldLevel(class)
          if not dw then
            fits = false
          elseif dw > level then
            -- Noch nicht lernbar: gesperrt bis zur Stufe des Lehrers
            dualWieldNeeded = true
            if dw > (reqEff or 0) then reqEff = dw end
          elseif skills then
            -- Lernbar, laut Client aber nicht gelernt: Hinweis
            learnSkill = true
          end
        end
      end

      -- Waffenfertigkeit: fehlt sie, kann sie der Waffenmeister lehren
      -- (ab 10, Stangenwaffen ab 20). Talentwaffen lehrt er nicht.
      if fits and skills and entry.ic == 2 and entry.sc ~= nil
         and entry.sc ~= 14 and entry.sc ~= 20 and not skills.known[entry.sc] then
        local talent = TALENT_WEAPON[class or ""]
        if talent and talent[entry.sc] then
          fits = false
        else
          learnSkill = true
          local ll = LEARN_LEVEL[entry.sc] or LEARN_LEVEL_DEFAULT
          if ll > (reqEff or 0) then reqEff = ll end
        end
      end

      -- Wie jedes Teil ueber der eigenen Stufe: nur innerhalb der
      -- Vorausplanung zeigen, dann mit Vermerk.
      if fits and reqEff and reqEff > level + self:PlanAhead() then fits = false end

      if fits and self:IsUsable(entry, class, level, allowedArmor, itemID) then
        local statScore = BLL.Weights:Score(entry.st, isWeapon)

        -- Zweihaender kosten die Schildhand. Ohne diese Verrechnung
        -- schlaegt das Addon einem Schutzpaladin einen Zweihaender vor
        -- und verschweigt, dass dabei Schild samt Block, Ruestung und
        -- Ausdauer wegfallen.
        local twoHand, offHandLoss = nil, 0
        if slotKey == "MainHandSlot" and entry.e == "INVTYPE_2HWEAPON" then
          twoHand = true
          local off = BLL.Gear.equipped["SecondaryHandSlot"]
          if off then
            offHandLoss = BLL.Weights:Score(off.stats, true)
            local offEntry = off.id and cache[off.id]
            if offEntry and offEntry.use then
              offHandLoss = offHandLoss + BLL.Weights:UseEffectScore(offEntry.use)
            end
          end
        end

        local useScore, estimated = 0, false
        if entry.use then
          useScore, estimated = BLL.Weights:UseEffectScore(entry.use)
        end

        local setInfo, setScore = nil, 0
        if BLL.SetDB and BLL.SetDB.loaded then
          setInfo = BLL.SetDB:EvaluateCandidate(itemID, slotKey)
          if setInfo and setInfo.stats then
            setScore = BLL.Weights:Score(nil, isWeapon, setInfo.stats)
          end
        end

        local score = statScore + useScore + setScore - offHandLoss
        if score > baseScore then
          -- Tatsaechliche Wertaenderung gegenueber dem angelegten Teil.
          -- Der Punktevorsprung allein sagt nicht, WAS sich aendert -
          -- und verschweigt vor allem, was man verliert.
          local diff = {}
          local seen = {}
          local eqStats = (equipped and equipped.stats) or {}
          for k in pairs(eqStats) do seen[k] = true end
          for k in pairs(entry.st or {}) do seen[k] = true end
          for k in pairs(seen) do
            local d = ((entry.st and entry.st[k]) or 0) - (eqStats[k] or 0)
            if d ~= 0 then diff[k] = d end
          end
          table.insert(out, {
            id        = itemID,
            locked    = (reqEff and reqEff > level) or nil,
            twoHand   = twoHand,
            offHandLoss = (offHandLoss > 0) and offHandLoss or nil,
            name      = entry.n,
            quality   = entry.q,
            reqLevel  = reqEff,
            dualWield  = dualWieldNeeded or nil,
            learnSkill = learnSkill or nil,
            srcLevel  = srcLevel,
            stats     = entry.st,
            diff      = diff,
            use       = entry.use,
            setInfo   = setInfo,
            statScore = statScore,
            useScore  = useScore,
            setScore  = setScore,
            estimated = estimated,
            score     = score,
            gain      = score - baseScore,
          })
        end
      end
    end
  end

  table.sort(out, function(a, b) return a.gain > b.gain end)

  -- Nur die besten behalten und erst dafuer die Quellen aufloesen,
  -- weil die Quellensuche pro Item spuerbar kostet.
  local trimmed = {}
  for i = 1, math.min(maxResults, table.getn(out)) do
    local u = out[i]
    u.sources = BLL.Sources:GetItemSources(u.id)
    table.insert(trimmed, u)
  end

  return trimmed, baseScore
end

------------------------------------------------------------------
-- Lootline: nach Fundort gebuendelt
--
-- Die Slotansicht beantwortet "was ist fuer diesen Slot besser".
-- Diese hier beantwortet die praktischere Frage: "wohin soll ich
-- gehen" - alle Verbesserungen nach Ort gebuendelt, Orte nach Ertrag
-- sortiert. Ein Dungeon mit drei Upgrades schlaegt einen mit einem.
--
-- Gruppiert wird nach Zone. Quellen ohne Zone (Haendler, Quests ohne
-- Ortsangabe) landen in einer Sammelgruppe statt unter den Tisch zu
-- fallen.
------------------------------------------------------------------

------------------------------------------------------------------
-- Kategorie eines Fundorts
--
-- pfQuest fuehrt kein Kennzeichen "Instanz". Deshalb eine Liste der
-- bekannten Instanzen; alles andere gilt als Welt. Eigene Instanzen
-- des Servers fehlen darin zwangslaeufig und landen unter "Welt" -
-- lieber ein zu allgemeines Etikett als ein falsches.
------------------------------------------------------------------

-- Vergleich ueber eine normalisierte Form: Kleinschreibung, ohne
-- Leerzeichen und Sonderzeichen. Damit passen "Zul'Farrak",
-- "ZulFarrak" und "zul farrak" auf denselben Eintrag, egal wie
-- pfQuest die Zone schreibt.
local function normZone(name)
  if not name then return nil end
  local n = string.lower(name)
  n = string.gsub(n, "[^a-z0-9]", "")
  return n
end

-- Stammdaten aus Data/ZoneData.lua. Die frueher hier gepflegte Liste
-- ist entfallen: sie hatte zwei falsche Eintraege und kannte keine
-- Stufenbereiche.
BananaLootlineZoneData = BananaLootlineZoneData or {}

function Cand:ZoneInfo(zone)
  local key = normZone(zone)
  if not key then return nil end
  return BananaLootlineZoneData[key]
end

function Cand:Category(zone, stype)
  -- Eigene Zuordnung des Nutzers hat Vorrang. Die Liste unten kann
  -- serverspezifische Orte nicht vollstaendig kennen - mit /bll cat
  -- laesst sich jeder Ort korrigieren, ohne den Code anzufassen.
  local key = normZone(zone)
  if key and BananaLootlineDB and BananaLootlineDB.zoneCategory then
    local own = BananaLootlineDB.zoneCategory[key]
    if own then return own end
  end

  if stype == "V" then return "HAENDLER" end
  if stype == "Q" then return "QUEST" end

  if key then
    local info = BananaLootlineZoneData[key]
    if info and info.c then return info.c end
  end

  if stype == "O" or stype == "C" then return "OBJEKT" end
  return "WELT"
end

-- Fuer den Korrekturbefehl
function Cand:SetZoneCategory(zone, cat)
  local key = normZone(zone)
  if not key then return false end
  BananaLootlineDB.zoneCategory = BananaLootlineDB.zoneCategory or {}
  if cat then
    BananaLootlineDB.zoneCategory[key] = cat
  else
    BananaLootlineDB.zoneCategory[key] = nil
  end
  return true
end

-- Wahrscheinlichkeit, das Teil bei einem Besuch der Quelle zu bekommen.
-- Quest und Haendler: sicher. Ohne Angabe: als sicher behandeln statt
-- auf null zu setzen - unbekannt ist nicht unmoeglich, und
-- Unerreichbares filtert Sources bereits heraus.
function Cand:ChanceFactor(stype, chance)
  if stype == "Q" or stype == "V" then return 1 end
  if not chance then return 1 end
  local p = chance / 100
  if p > 1 then p = 1 end
  return p
end

function Cand:GetLootline(maxPerSlot)
  if not self.pool then return nil end
  maxPerSlot = maxPerSlot or 3

  local groups, order = {}, {}
  local seenItem = {}

  -- Bester bisher gezaehlter Zuwachs je Quest. pfQuest trennt feste
  -- Belohnungen nicht von Auswahlbelohnungen. Bei einer Auswahl bekommt
  -- man genau ein Teil - zaehlten alle, stuende eine Quest mit vier
  -- Wahlmoeglichkeiten viermal so hoch wie sie wert ist. Deshalb zaehlt
  -- je Quest nur das beste Teil. Seltene Quests mit mehreren festen
  -- Belohnungen werden damit unterschaetzt; das ist der kleinere Fehler.
  local questBest = {}
  local questItems = {}

  for i = 1, table.getn(BLL.Gear.SLOTS) do
    local slot = BLL.Gear.SLOTS[i]
    local ups, baseScore = self:GetUpgrades(slot.key, maxPerSlot)

    for u = 1, table.getn(ups or {}) do
      local item = ups[u]

      -- Ein Item kann in zwei Slots passen (Ringe, Schmuck, Waffen).
      -- Nur einmal zaehlen, sonst wird der Ort doppelt gewichtet.
      -- Ein Item, dessen einzige Quelle ein Entwicklereintrag ist,
      -- gehoert nicht in einen Wegplan: man kann es nicht bekommen.
      local hasSource = item.sources and table.getn(item.sources) > 0

      if not seenItem[item.id] and hasSource then
        seenItem[item.id] = true

        local zone, sourceName, chance, stype, questLevel, questID
        if item.sources and table.getn(item.sources) > 0 then
          local best = item.sources[1]
          zone = best.zone
          sourceName = best.name
          chance = best.chance
          stype = best.stype
          questLevel = best.questLevel
          if stype == "Q" then questID = best.id end
        end
        local key = zone or (BLL.locale == "deDE" and "Ohne Ortsangabe" or "No location")

        -- Quests ohne ermittelbaren Ort nicht in denselben Topf wie
        -- ortlose Weltdrops werfen: "Quests" ist eine brauchbare
        -- Auskunft, "Ohne Ortsangabe" ist keine.
        if not zone and stype == "Q" then
          key = (BLL.locale == "deDE") and "Quests" or "Quests"
        end

        if not groups[key] then
          local info = self:ZoneInfo(zone)
          groups[key] = {
            zone     = key,
            category = self:Category(zone, stype),
            lvlRange = info and info.lvl,
            minLevel = info and info.min,
            acronym  = info and info.acr,
            items = {}, priority = 0,
          }
          table.insert(order, groups[key])
        end

        local g = groups[key]
        if questID then
          -- Nur den Teil des Zuwachses addieren, der ueber dem bisher
          -- besten Teil derselben Quest liegt. Die Summe je Quest ist
          -- damit unabhaengig von der Slotreihenfolge ihr Maximum.
          -- Questbelohnungen sind sicher: Faktor 1.
          local prev = questBest[questID] or 0
          if item.gain > prev then
            g.priority = g.priority + (item.gain - prev)
            questBest[questID] = item.gain
          end
        else
          -- Erwarteter Zuwachs pro Besuch: Zuwachs mal Dropchance.
          -- Vorher zaehlte der volle Zuwachs, und ein Ort mit drei 1-%-
          -- Drops schlug einen mit einem 75-%-Drop. Haendler sind sicher.
          g.priority = g.priority + item.gain * self:ChanceFactor(stype, chance)
        end
        local row = {
          id       = item.id,
          locked   = item.locked,
          twoHand  = item.twoHand,
          reqLevel = item.reqLevel,
          learnSkill = item.learnSkill,
          name     = item.name,
          quality  = item.quality,
          slot     = slot.key,
          slotName = BLL.Gear:SlotLabel(slot),
          gain     = item.gain,
          stype    = stype,
          questLevel = questLevel,
          -- Prozentualer Zuwachs gegenueber dem angelegten Teil. Eine
          -- absolute Punktzahl sagt nichts, solange man die Skala nicht
          -- kennt; "+750%" ist sofort verstaendlich. Bei leerem Slot
          -- gibt es keinen Bezugswert, dann steht NEU.
          pct      = (baseScore and baseScore > 0)
                     and (item.gain / baseScore * 100) or nil,
          isNew    = (BLL.Gear.equipped[slot.key] == nil),
          source   = sourceName,
          chance   = chance,
          setInfo  = item.setInfo,
          questID  = questID,
        }
        table.insert(g.items, row)
        if questID then
          questItems[questID] = questItems[questID] or {}
          table.insert(questItems[questID], row)
        end
      end
    end
  end

  -- Auswahl kenntlich machen: bei mehreren Teilen aus derselben Quest
  -- erfaehrt jede Zeile, wie viele zur Wahl stehen und ob sie die
  -- beste ist. Die Anzeige braucht das, sonst wirkt der Ort ergiebiger
  -- als seine Prioritaet.
  for qid, rows in pairs(questItems) do
    local n = table.getn(rows)
    if n > 1 then
      for r = 1, n do
        rows[r].choiceOf = n
        rows[r].choiceBest = (rows[r].gain >= questBest[qid])
      end
    end
  end

  -- Innerhalb eines Ortes das Wertvollste zuerst
  for i = 1, table.getn(order) do
    table.sort(order[i].items, function(a, b) return a.gain > b.gain end)
  end

  -- Orte nach Gesamtertrag
  table.sort(order, function(a, b) return a.priority > b.priority end)

  return order
end

------------------------------------------------------------------
-- Bequemer Einstieg
------------------------------------------------------------------

function Cand:Run(span)
  span = span or 6
  local level = (BLL.player and BLL.player.level) or 60
  local minLvl = math.max(1, level - math.floor(span / 2))
  local maxLvl = math.min(63, level + span)
  return self:StartIndex(minLvl, maxLvl)
end

------------------------------------------------------------------
-- Motor
------------------------------------------------------------------

local driver = CreateFrame("Frame", "BananaLootlineCandidateDriver")

-- Neue Waffenfertigkeit gelernt oder Talent gesetzt: beim naechsten
-- Bewerten neu einlesen.
if driver.RegisterEvent then
  driver:RegisterEvent("SKILL_LINES_CHANGED")
  driver:RegisterEvent("CHARACTER_POINTS_CHANGED")
  driver:SetScript("OnEvent", function() Cand.skillsDirty = true end)
end
driver:SetScript("OnUpdate", function()
  local elapsed = arg1 or 0

  if Cand.state == "indexing" then
    Cand:IndexChunk()

  elseif Cand.state == "requesting" then
    Cand:RequestTick(elapsed)

  elseif Cand.state == "waiting" then
    waitTimer = waitTimer - elapsed
    if waitTimer <= 0 then
      Cand.state = "collecting"
    end

  elseif Cand.state == "collecting" then
    Cand:CollectTick()
  end
end)
