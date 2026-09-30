--[[----------------------------------------------------------------------
  BananaLootline - Core.lua
  Initialisierung, Events, Slash-Befehle.

  Lua 5.0 / WoW 1.12 Hinweise, die im ganzen Addon gelten:
    - kein '#'-Operator      -> table.getn()
    - kein string.gmatch     -> string.gfind()
    - kein select()/varargs  -> arg1..argN in Event-Handlern
    - Frame-Handler nutzen die globalen 'this' und 'arg1'
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
local L = BLL.L

BLL.VERSION = "0.21.1"

------------------------------------------------------------------
-- Ausgabe
------------------------------------------------------------------

function BLL:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33Banana|cffffffffLootline|r: " .. tostring(msg))
end

function BLL:Debug(msg)
  if BananaLootlineDB and BananaLootlineDB.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[BLL] " .. tostring(msg) .. "|r")
  end
end

------------------------------------------------------------------
-- Defaults
------------------------------------------------------------------

local defaults = {
  debug          = false,
  tooltipSources = true,   -- Quellen an jeden Item-Tooltip anhaengen
  maxSources     = 5,      -- wie viele Quellen maximal im Tooltip
  minDropChance  = 0,      -- Quellen unter dieser Chance ausblenden
  language       = "auto", -- Anzeigesprache: auto, deDE, enUS
}

-- Einmalige Uebernahme der Einstellungen aus der Zeit vor der
-- Umbenennung (bis 0.13.3 hiess das Addon OctoLootline). Der Client
-- laedt die alten Variablen nur, wenn die Datei in WTF umbenannt wurde
-- und die Namen in der .toc stehen. Nach der Uebernahme wird die alte
-- Variable geleert; beim naechsten Logout schreibt der Client sie
-- nicht mehr. Kann entfallen, sobald alle Gildenmitglieder umgestellt
-- haben.
local function MigrateLegacy()
  if type(OctoLootlineDB) == "table" then
    if not BananaLootlineDB or next(BananaLootlineDB) == nil then
      BananaLootlineDB = OctoLootlineDB
      BLL.migrated = true
    end
    OctoLootlineDB = nil
  end
  if type(OctoLootlineChar) == "table" then
    if not BananaLootlineChar or next(BananaLootlineChar) == nil then
      BananaLootlineChar = OctoLootlineChar
      BLL.migrated = true
    end
    OctoLootlineChar = nil
  end
end

local function ApplyDefaults()
  MigrateLegacy()
  BananaLootlineDB = BananaLootlineDB or {}
  for k, v in pairs(defaults) do
    if BananaLootlineDB[k] == nil then
      BananaLootlineDB[k] = v
    end
  end
  BananaLootlineChar = BananaLootlineChar or { gear = {}, wishlist = {} }
  BLL:SetLanguage(BananaLootlineDB.language)
end

------------------------------------------------------------------
-- Spielerinfo
------------------------------------------------------------------

function BLL:UpdatePlayerInfo()
  local _, class    = UnitClass("player")
  local _, race     = UnitRace("player")
  self.player = {
    name  = UnitName("player"),
    class = class,                 -- "WARRIOR", "MAGE", ...
    race  = race,
    level = UnitLevel("player"),
  }
end

------------------------------------------------------------------
-- Init
------------------------------------------------------------------

local frame = CreateFrame("Frame", "BananaLootlineCore")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    ApplyDefaults()

  elseif event == "PLAYER_ENTERING_WORLD" then
    if BLL.initialized then return end
    BLL.initialized = true

    ApplyDefaults()
    BLL:UpdatePlayerInfo()
    if BLL.ItemDB then BLL.ItemDB:Refresh() end
    if BLL.SetDB then BLL.SetDB:Refresh() end
    if BLL.EnchantDB then BLL.EnchantDB:Refresh() end
    BLL.Sources:Init()
    BLL.Gear:ScanEquipped()
    BLL.UI:Init()

    -- Nachscans. Beim Betreten der Welt kennt der Client die Daten der
    -- angelegten Items oft noch nicht - der Tooltip ist dann leer und
    -- der Scan liefert keine Werte. Deshalb nach ein paar Sekunden
    -- noch einmal, und zur Sicherheit spaeter ein drittes Mal.
    BLL.pendingInitialScans = { 4, 12 }
    BLL.initialScanTimer = 0

    BLL:Print(L["LOADED"] .. " |cff666666(v" .. BLL.VERSION .. ")|r")
    if BLL.migrated then
      BLL:Print(L["MIGRATED"])
    end
    if BLL.Sources.available then
      BLL:Print("|cff00ff00" .. L["PFQUEST_OK"] .. "|r")
    else
      BLL:Print("|cffff8800" .. L["NO_PFQUEST"] .. "|r")
    end
    if not BLL.ItemDB then
      BLL:Print("|cffff0000" .. L["ITEMDB_BROKEN"] .. "|r")
    elseif not BLL.ItemDB.loaded then
      BLL:Print("|cffff8800" .. L["NO_ITEMDB"] .. "|r")
    else
      BLL:Print("|cff00ff00" .. string.format(L["ITEMDB_LOADED"], BLL.ItemDB.count) .. "|r")
      if BLL.SetDB and BLL.SetDB.loaded then
        BLL:Print("|cff00ff00" .. string.format(L["SETDB_LOADED"], BLL.SetDB.count) .. "|r")
      end
    end

  elseif event == "PLAYER_LEVEL_UP" then
    BLL:UpdatePlayerInfo()

  elseif event == "UNIT_INVENTORY_CHANGED" then
    -- Dieses Event feuert im Kampf laufend, meist ohne dass sich die
    -- Ausruestung geaendert haette. Deshalb nur vormerken; ob wirklich
    -- gescannt wird, entscheidet der Signaturvergleich im OnUpdate.
    if arg1 == "player" then
      BLL.rescanPending = 1.0
    end

  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Kampf vorbei: jetzt darf nachgeholt werden, was waehrend des
    -- Kampfes aufgeschoben wurde.
    if BLL.rescanDeferred then
      BLL.rescanDeferred = nil
      BLL.rescanPending = 0.5
    end
  end
end)

frame:SetScript("OnUpdate", function()
  local elapsed = arg1 or 0

  -- Nachscans nach dem Login
  if BLL.pendingInitialScans and table.getn(BLL.pendingInitialScans) > 0 then
    BLL.initialScanTimer = (BLL.initialScanTimer or 0) + elapsed
    if BLL.initialScanTimer >= BLL.pendingInitialScans[1] then
      table.remove(BLL.pendingInitialScans, 1)
      if not UnitAffectingCombat("player") then
        -- Erzwungen: die Itemlinks sind unveraendert, aber die WERTE
        -- koennen jetzt erst auslesbar sein. Der Signaturvergleich
        -- wuerde den Scan sonst abwuergen.
        BLL.Scanner:ClearCache()
        BLL.Gear:ScanEquipped()
        BLL.Gear.lastSignature = BLL.Gear:Signature()
        if BLL.UI and BLL.UI.frame and BLL.UI.frame:IsVisible() then
          BLL.UI:Refresh()
        end
      end
    end
  end

  if not BLL.rescanPending then return end

  BLL.rescanPending = BLL.rescanPending - elapsed
  if BLL.rescanPending > 0 then return end

  BLL.rescanPending = nil
  if not BLL.initialized then return end

  -- Im Kampf nichts scannen. Der Tooltipscan ueber 17 Slots kostet
  -- spuerbar Rechenzeit, und ausgerechnet dann feuert das Event am
  -- haeufigsten. Wird nach dem Kampf nachgeholt.
  if UnitAffectingCombat("player") then
    BLL.rescanDeferred = true
    return
  end

  -- Hat sich ueberhaupt etwas geaendert?
  if not BLL.Gear:HasChanged() then return end

  BLL.Gear:ScanEquipped()
  if BLL.UI and BLL.UI.frame and BLL.UI.frame:IsVisible() then
    BLL.UI:Refresh()
  end
end)

------------------------------------------------------------------
-- Selbstpruefung
--
-- Prueft im laufenden Spiel, was sich von aussen nicht feststellen
-- laesst: ob die Tooltipmuster gegen die tatsaechlich angelegte
-- Ausruestung greifen, ob Client- und Anzeigesprache zusammenpassen und
-- ob die Datenquellen da sind. Gedacht als Ausgabe, die ein Tester
-- direkt weitergeben kann.
------------------------------------------------------------------

local function Mark(good) return good and "|cff00ff00OK|r" or "|cffff0000!!|r" end

function BLL:SelfTest()
  local out = DEFAULT_CHAT_FRAME
  local warn = 0

  self:Print("|cffffcc33" .. string.format(L["ST_TITLE"], self.VERSION) .. "|r")

  ----------------------------------------------------------------
  -- Sprachen
  ----------------------------------------------------------------
  out:AddMessage("  " .. string.format(L["ST_LANG"],
    tostring(self.clientLocale), tostring(self.locale)))
  local patLang = (self.clientLocale == "deDE") and "deDE" or "enUS"
  out:AddMessage("  " .. string.format(L["ST_PATTERNS"], patLang)
    .. " " .. Mark(true) .. " |cff888888" .. L["ST_PATTERNS_NOTE"] .. "|r")

  ----------------------------------------------------------------
  -- Datenquellen
  ----------------------------------------------------------------
  local pf = self.Sources and self.Sources.available
  out:AddMessage("  pfQuest " .. Mark(pf)
    .. (pf and "" or (" |cff888888" .. L["ST_PFQUEST_NOTE"] .. "|r")))
  if not pf then warn = warn + 1 end

  local db = self.ItemDB and self.ItemDB.loaded
  out:AddMessage("  ItemDB " .. Mark(db) .. " "
    .. (db and string.format(L["ST_ITEMDB_COUNT"], self.ItemDB.count)
           or L["ITEMDB_NONE"]))
  if not db then warn = warn + 1 end

  ----------------------------------------------------------------
  -- Der Import der Fundorte. Ohne ihn liest das Addon wieder pfQuest,
  -- und dessen Dropchancen stimmen fuer diesen Server nicht.
  ----------------------------------------------------------------

  local function Count(t)
    if type(t) ~= "table" then return nil end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end

  local nSrc  = Count(BananaLootlineSourceData)
  local nNpc  = Count(BananaLootlineNpcNames)
  local nZone = Count(BananaLootlineZoneNames)
  local src   = (nSrc or 0) > 0
  out:AddMessage("  SourceData " .. Mark(src) .. " "
    .. (src and ((nSrc or 0) .. " Items, " .. (nNpc or 0) .. " NPCs, "
                 .. (nZone or 0) .. " Zonen")
            or "fehlt - Fundorte kommen aus pfQuest"))
  if not src then warn = warn + 1 end

  ----------------------------------------------------------------
  -- Die eigentliche Probe: greifen die Muster an der Ausruestung?
  --
  -- Ein belegter Platz, aus dessen Tooltip kein einziger Wert kommt,
  -- ist das Zeichen dafuer, dass die Muster nicht zur Clientsprache
  -- passen. Genau so fiel auf, dass "St[aä]rke" nie greifen konnte.
  ----------------------------------------------------------------
  local worn, parsed, empty = 0, 0, {}
  for i = 1, table.getn(self.Gear.SLOTS) do
    local slot = self.Gear.SLOTS[i]
    local d = self.Gear.equipped[slot.key]
    if d then
      worn = worn + 1
      local any = false
      for _ in pairs(d.stats or {}) do any = true break end
      if any then
        parsed = parsed + 1
      else
        table.insert(empty, d.name or slot.key)
      end
    end
  end

  out:AddMessage("  " .. string.format(L["ST_GEAR"], parsed, worn)
    .. " " .. Mark(worn == 0 or parsed > 0))
  if worn > 0 and parsed == 0 then
    warn = warn + 1
    out:AddMessage("   |cffff0000" .. L["ST_NO_STATS"] .. "|r")
  elseif table.getn(empty) > 0 then
    out:AddMessage("   |cff888888"
      .. string.format(L["ST_WITHOUT"], table.concat(empty, ", ")) .. "|r")
    out:AddMessage("   |cff888888" .. L["ST_WITHOUT_NOTE"] .. "|r")
  end

  ----------------------------------------------------------------
  -- Vollstaendigkeit der Tooltipzeilen
  --
  -- Der Scan-Tooltip liefert nicht zwingend alles, was im Spiel zu
  -- sehen ist. Fehlen Zeilen, bleiben Zugangsbedingungen unsichtbar.
  ----------------------------------------------------------------
  local probe, probeName
  for i = 1, table.getn(self.Gear.SLOTS) do
    local d = self.Gear.equipped[self.Gear.SLOTS[i].key]
    if d and d.id then probe, probeName = d.id, d.name break end
  end
  if probe then
    local lines = self.Scanner:GetLines(probe)
    local n = table.getn(lines or {})
    out:AddMessage("  " .. string.format(L["ST_TOOLTIP"], n,
      tostring(probeName)) .. " " .. Mark(n > 2))
    if n <= 2 then
      warn = warn + 1
      out:AddMessage("   |cffff0000" .. L["ST_TOOLTIP_BAD"] .. "|r")
    end
  end

  ----------------------------------------------------------------
  -- Suchbereich
  ----------------------------------------------------------------
  local lo, hi = self.Candidates:Band()
  out:AddMessage("  " .. string.format(L["ST_BAND"], lo, hi,
    self.Candidates:PlanAhead()))
  if self.Candidates.pool then
    out:AddMessage("  " .. string.format(L["ST_POOL"],
      self.Candidates.poolSize or 0)
      .. " |cff888888" .. string.format(L["ST_POOL_LOC"],
      self.Candidates.pfqCount or 0) .. "|r")
  else
    out:AddMessage("  |cff888888" .. L["ST_NOSEARCH"] .. "|r")
  end

  ----------------------------------------------------------------
  if warn == 0 then
    self:Print("|cff00ff00" .. L["ST_OK"] .. "|r")
  else
    self:Print("|cffff8800" .. string.format(L["ST_WARN"], warn) .. "|r")
  end
end

------------------------------------------------------------------
-- Slash-Befehle
------------------------------------------------------------------

SLASH_BANANALOOTLINE1 = "/bll"
SLASH_BANANALOOTLINE2 = "/bananalootline"

SlashCmdList["BANANALOOTLINE"] = function(msg)
  msg = string.lower(msg or "")
  local cmd, rest = string.find(msg, "^(%a+)")
  local command = cmd and string.sub(msg, 1, rest) or msg
  -- nicht "arg" nennen: in Lua 5.0 ist das die Vararg-Tabelle
  local param = string.gsub(string.sub(msg, (rest or 0) + 1), "^%s+", "")

  if command == "lang" then
    local code = (param == "de" and "deDE") or (param == "en" and "enUS") or "auto"
    BananaLootlineDB.language = code
    BLL:SetLanguage(code)
    if BLL.UI and BLL.UI.ApplyLocale then BLL.UI:ApplyLocale() end
    BLL:Print(L["LANG_SWITCHED"])

  elseif command == "debug" then
    BananaLootlineDB.debug = not BananaLootlineDB.debug
    BLL:Print(string.format(L["DEBUG_STATE"],
      BananaLootlineDB.debug and L["ON"] or L["OFF"]))

  elseif command == "scan" then
    -- Cache leeren: sonst ueberleben falsch geparste Eintraege aus einer
    -- frueheren Sitzung den Scan.
    BLL.Scanner:ClearCache()
    BLL.Gear:ScanEquipped()
    BLL:Print(L["SCAN_DONE"])
    BLL.Gear:DumpEquipped()

  elseif command == "dump" then
    -- Rohe Tooltipzeilen eines Items ausgeben - das Werkzeug, um die
    -- Patterns in Locale.lua gegen den echten Client zu verifizieren.
    local id = tonumber(param)
    if not id then
      BLL:Print(L["USAGE_DUMP"])
    else
      BLL.Scanner:DumpLines(id)
    end

  elseif command == "tip" then
    local id = tonumber(param)
    if not id then
      BLL:Print(L["USAGE_TIP"])
    else
      BLL.Scanner:CompareTooltip(id)
    end

  elseif command == "selftest" then
    BLL:SelfTest()

  elseif command == "item" then
    -- Zeigt, was im gespeicherten Cache zu einem Gegenstand steht.
    -- Damit laesst sich pruefen, ob eine Zugangsbedingung beim
    -- Ueberfahren tatsaechlich angekommen ist.
    local id = tonumber(param)
    if not id then
      BLL:Print(L["USAGE_ITEM"])
    else
      local e = BananaLootlineDB.itemcache and BananaLootlineDB.itemcache[id]
      if not e then
        BLL:Print(string.format(L["ITEM_NOCACHE"], id)
          .. " |cff888888" .. L["ITEM_HINT"] .. "|r")
      else
        BLL:Print(string.format(L["ITEM_HEAD"], id, tostring(e.n)))
        local function row(k, v)
          DEFAULT_CHAT_FRAME:AddMessage("   |cff888888" .. k .. "|r "
            .. tostring(v))
        end
        row(L["ITEM_LEVEL"], e.r)
        row(L["ITEM_SLOT"], e.e)
        row(L["ITEM_ORIGIN"], e.db and L["ITEM_IMPORT"] or L["ITEM_SERVER"])
        row(L["ITEM_LOCK"], e.lock or ("|cff888888" .. L["ITEM_NONE"] .. "|r"))
        local st = ""
        for k, v in pairs(e.st or {}) do st = st .. k .. "=" .. v .. " " end
        row(L["ITEM_STATS"], (st ~= "") and st or ("|cff888888" .. L["ITEM_NONE"] .. "|r"))
      end
    end

  elseif command == "hooks" then
    -- Welche fremden Addons koennen am Tooltip haengen?
    --
    -- Die Rufzeile stammt nicht vom Client, sondern von einem anderen
    -- Addon. Diese Uebersicht engt ein, welches in Frage kommt.
    BLL:Print(L["HOOKS_HEAD"])
    local n = GetNumAddOns and GetNumAddOns() or 0
    local found = 0
    for i = 1, n do
      local name, _, _, enabled = GetAddOnInfo(i)
      if enabled and name and name ~= "BananaLootline" then
        local low = string.lower(name)
        if string.find(low, "atlas") or string.find(low, "pfui")
           or string.find(low, "aux") or string.find(low, "tooltip")
           or string.find(low, "scanner") or string.find(low, "stat")
           or string.find(low, "api") or string.find(low, "loot")
           or string.find(low, "shagu") or string.find(low, "bag") then
          found = found + 1
          DEFAULT_CHAT_FRAME:AddMessage("   |cffffcc33" .. name .. "|r")
        end
      end
    end
    if found == 0 then
      DEFAULT_CHAT_FRAME:AddMessage("   |cff888888" .. L["HOOKS_NONE"] .. "|r")
    end
    DEFAULT_CHAT_FRAME:AddMessage("   |cff888888"
      .. string.format(L["HOOKS_TOTAL"], n) .. "|r")

  elseif command == "src" then
    local id = tonumber(param)
    if not id then
      BLL:Print(L["USAGE_SRC"])
    else
      local list = BLL.Sources:GetItemSources(id)
      if not list or table.getn(list) == 0 then
        BLL:Print(L["NO_SOURCE"])
      else
        BLL:Print(string.format(L["SRC_HEADER"], id))
        for i = 1, table.getn(list) do
          local s = list[i]
          -- Alles, was der Import weiss, gehoert in diese Zeile: die
          -- Stufe des Gegners, ob er Elite ist, was der Haendler
          -- verlangt. Danach wird hier gesucht, wenn ein Fundort
          -- zweifelhaft aussieht.
          local extra = ""
          if s.level then extra = extra .. " |cff888888[" .. s.level .. "]|r" end
          local elite = s.elite and BLL:EliteLabel(s.elite)
          if elite then extra = extra .. " |cffff8800" .. elite .. "|r" end
          if s.cost then
            extra = extra .. " |cffffd100"
              .. math.floor(s.cost / 10000) .. "g"
              .. math.mod(math.floor(s.cost / 100), 100) .. "s"
              .. math.mod(s.cost, 100) .. "k|r"
          end
          if s.tag then extra = extra .. " |cff888888<" .. s.tag .. ">|r" end
          DEFAULT_CHAT_FRAME:AddMessage("   " .. s.typeLabel .. ": " .. s.name
            .. (s.chance and (" (" .. (BLL:FormatChance(s.chance)
               or "?") .. ")") or "")
            .. extra
            .. (s.zone and (" |cff888888- " .. s.zone .. "|r") or "")
            .. (s.imported and "" or " |cff666666(pfQuest)|r"))
        end
      end
    end

  elseif command == "up" or command == "upgrades" then
    local span = tonumber(param)
    BLL.Candidates:Run(span)

  elseif command == "weight" then
    local _, _, stat, value = string.find(param, "^(%a+)%s*(%-?%d*%.?%d*)$")
    if param == "reset" then
      BLL.Weights:Reset()
      BLL:Print(L["WEIGHTS_RESET"])
    elseif stat then
      BLL.Weights:Set(string.upper(stat), tonumber(value))
      BLL:Print(string.format(L["WEIGHT_SET"], string.upper(stat),
        (value ~= "") and value or L["WEIGHT_REMOVED"]))
    else
      local w = BLL.Weights:Get()
      BLL:Print(L["WEIGHTS_CURRENT"])
      for i = 1, table.getn(BLL.STATS) do
        local k = BLL.STATS[i]
        if w[k] then
          DEFAULT_CHAT_FRAME:AddMessage("   " .. k .. " = " .. w[k])
        end
      end
    end

  elseif command == "set" then
    local id = tonumber(param)
    if not id then
      BLL:Print(L["USAGE_SET"])
    elseif not BLL.SetDB.loaded then
      BLL:Print(L["NO_SETDATA"])
    else
      local setID, set = BLL.SetDB:GetSetOf(id)
      if not setID then
        BLL:Print(string.format(L["ITEM_NO_SET"], id))
      else
        local worn = BLL.SetDB:CountEquipped(setID)
        BLL:Print(string.format(L["SET_WORN"], set.name, worn, table.getn(set.items)))
        for i = 1, table.getn(set.bonuses) do
          local b = set.bonuses[i]
          local aktiv = (worn >= b.p)
            and ("|cff00ff00[" .. L["SET_ACTIVE"] .. "]|r")
            or  ("|cff888888[" .. L["SET_INACTIVE"] .. "]|r")
          DEFAULT_CHAT_FRAME:AddMessage("   " .. aktiv .. " (" .. b.p .. ") " .. (b.t or ""))
        end
      end
    end

  elseif command == "usecd" then
    local n = tonumber(param)
    if n and n > 0 then
      BananaLootlineDB.useCooldown = n
      BLL:Print(string.format(L["USECD_SET"], n))
    else
      BLL:Print(string.format(L["USECD_INFO"],
        BananaLootlineDB.useCooldown or BLL.Weights.DEFAULT_COOLDOWN))
    end

  elseif command == "stop" then
    BLL.Candidates:Stop()

  elseif command == "rate" then
    local n = tonumber(param)
    if n and n >= 1 and n <= 30 then
      BananaLootlineDB.queryRate = n
      BLL:Print(string.format(L["RATE_SET"], n))
    else
      BLL:Print(string.format(L["RATE_INFO"], BananaLootlineDB.queryRate or 8))
    end

  elseif command == "forget" then
    BananaLootlineDB.itemcache = {}
    BLL.Candidates.pool = nil
    BLL.Candidates.state = "idle"
    BLL:Print(L["CACHE_CLEARED"])

  elseif command == "locked" then
    BananaLootlineDB.showLocked = not BananaLootlineDB.showLocked
    BLL:Print(string.format(L["LOCKED_STATE"],
      BananaLootlineDB.showLocked and L["LOCKED_SHOWN"] or L["LOCKED_HIDDEN"]))
    BLL:Print(L["REOPEN_WINDOW"])

  elseif command == "unused" then
    BananaLootlineDB.showUnreachable = not BananaLootlineDB.showUnreachable
    -- string.format, nicht Verkettung: das doppelte Prozentzeichen im
    -- Text wird sonst woertlich ausgegeben.
    BLL:Print(string.format(L["UNUSED_STATE"],
      BananaLootlineDB.showUnreachable and L["UNUSED_SHOWN"] or L["UNUSED_HIDDEN"]))
    BLL:Print(L["REOPEN_WINDOW"])

  elseif command == "cat" then
    local _, _, zone, cat = string.find(param, "^(.-)%s+(%a+)$")
    -- Beide Sprachen gelten immer. Ein englischer Spieler tippt "vendor",
    -- ein deutscher "haendler" - beide muessen ankommen, unabhaengig
    -- davon, welche Anzeigesprache gerade eingestellt ist.
    local VALID = { dungeon="DUNGEON", raid="RAID",
                    welt="WELT",           world="WELT",
                    weltboss="WELTBOSS",   worldboss="WELTBOSS",
                    schlachtfeld="SCHLACHTFELD", battleground="SCHLACHTFELD",
                    quest="QUEST",
                    haendler="HAENDLER",   vendor="HAENDLER",
                    objekt="OBJEKT",       object="OBJEKT" }
    if not zone or zone == "" then
      BLL:Print(L["USAGE_CAT"])
      BLL:Print(L["CAT_EXAMPLE"])
      local own = BananaLootlineDB.zoneCategory
      if own then
        BLL:Print(L["CAT_OWN"])
        for k, v in pairs(own) do
          DEFAULT_CHAT_FRAME:AddMessage("   " .. k .. " -> " .. v)
        end
      end
    elseif not VALID[string.lower(cat)] then
      BLL:Print(string.format(L["CAT_UNKNOWN"], cat))
    else
      BLL.Candidates:SetZoneCategory(zone, VALID[string.lower(cat)])
      BLL:Print(string.format(L["CAT_SET"], zone, VALID[string.lower(cat)]))
    end

  elseif command == "ahead" then
    local n = tonumber(param)
    if n and n >= 0 and n <= 60 then
      BananaLootlineDB.planAhead = n
      -- Das Band gleich mit ausgeben. Frueher war nicht erkennbar, dass
      -- die Einstellung ueberhaupt etwas an der Suche aendert.
      local lo, hi = BLL.Candidates:Band()
      BLL:Print(string.format(L["AHEAD_SET"], n, lo, hi))
    else
      BLL:Print(string.format(L["AHEAD_INFO"], BLL.Candidates:PlanAhead()))
    end

  elseif command == "spec" then
    local tab, name, total = BLL.Weights:DetectSpec()
    BLL.Weights:Get()
    if not tab then
      BLL:Print(string.format(L["SPEC_NONE"], total or 0, BLL.Weights.MIN_POINTS))
    else
      BLL:Print(string.format(L["SPEC_FOUND"],
        BLL.Weights.activeSpec or name or "?", total or 0))
    end
    for i = 1, GetNumTalentTabs() do
      local n, _, p = GetTalentTabInfo(i)
      DEFAULT_CHAT_FRAME:AddMessage("   " .. (n or i) .. ": " .. (p or 0))
    end

  elseif command == "info" then
    BLL:Print(string.format(L["INFO_LINE"],
      BLL.Sources.available and L["YES"] or L["NO"],
      (BLL.ItemDB and BLL.ItemDB.loaded)
        and (BLL.ItemDB.count .. " Items") or L["ITEMDB_NONE"],
      BLL.locale))

  elseif command == "help" then
    -- Befehl und Beschreibung getrennt: der Befehl ist sprachneutral,
    -- nur die Beschreibung wird uebersetzt.
    local HELP = {
      { "/bll",                 "HELP_MAIN"       },
      { "/bll lang de|en|auto", "HELP_LANG"       },
      { "/bll up [n]",          "HELP_UP"         },
      { "/bll stop",            "HELP_STOP"       },
      { "/bll rate <n>",        "HELP_RATE"       },
      { "/bll forget",          "HELP_FORGET"     },
      { "/bll spec",            "HELP_SPEC"       },
      { "/bll ahead <n>",       "HELP_AHEAD"      },
      { "/bll cat <zone> <cat>","HELP_CAT"        },
      { "/bll unused",          "HELP_UNUSED"     },
      { "/bll locked",          "HELP_LOCKED"     },
      { "/bll weight",          "HELP_WEIGHT"     },
      { "/bll weight STR 3",    "HELP_WEIGHT_SET" },
      { "/bll weight reset",    "HELP_WEIGHT_RST" },
      { "/bll scan",            "HELP_SCAN"       },
      { "/bll dump <id>",       "HELP_DUMP"       },
      { "/bll tip <id>",        "HELP_TIP"        },
      { "/bll item <id>",       "HELP_ITEM"       },
      { "/bll hooks",           "HELP_HOOKS"      },
      { "/bll selftest",        "HELP_SELFTEST"   },
      { "/bll src <id>",        "HELP_SRC"        },
      { "/bll set <id>",        "HELP_SET"        },
      { "/bll usecd <s>",       "HELP_USECD"      },
      { "/bll info",            "HELP_INFO"       },
      { "/bll debug",           "HELP_DEBUG"      },
    }
    BLL:Print(L["HELP_HEADER"])
    for i = 1, table.getn(HELP) do
      local cmdText = HELP[i][1]
      -- auf feste Breite auffuellen, damit die Beschreibungen untereinander
      -- stehen. string.rep statt %-20s: Lua 5.0 formatiert das zuverlaessig,
      -- aber so bleibt es auch mit Farbcodes berechenbar.
      local pad = 22 - string.len(cmdText)
      if pad < 1 then pad = 1 end
      DEFAULT_CHAT_FRAME:AddMessage("   |cffffcc33" .. cmdText .. "|r"
        .. string.rep(" ", pad) .. "- " .. L[HELP[i][2]])
    end

  else
    BLL.UI:Toggle()
  end
end
