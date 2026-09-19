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

BLL.VERSION = "0.18.0"

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
      BLL:Print("Einstellungen aus OctoLootline uebernommen.")
    end
    if BLL.Sources.available then
      BLL:Print("|cff00ff00" .. L["PFQUEST_OK"] .. "|r")
    else
      BLL:Print("|cffff8800" .. L["NO_PFQUEST"] .. "|r")
    end
    if not BLL.ItemDB then
      BLL:Print("|cffff0000ItemDB.lua fehlt oder wurde ueberschrieben. "
        .. "Importziel ist Data/ItemData.lua, nicht ItemDB.lua!|r")
    elseif not BLL.ItemDB.loaded then
      BLL:Print("|cffff8800" .. L["NO_ITEMDB"] .. "|r")
    else
      BLL:Print("|cff00ff00ItemDB: " .. BLL.ItemDB.count .. " Items geladen|r")
      if BLL.SetDB and BLL.SetDB.loaded then
        BLL:Print("|cff00ff00SetDB: " .. BLL.SetDB.count .. " Sets geladen|r")
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
    BLL:Print("Debug: " .. (BananaLootlineDB.debug and "an" or "aus"))

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
      BLL:Print("Nutzung: /bll dump <itemID>")
    else
      BLL.Scanner:DumpLines(id)
    end

  elseif command == "src" then
    local id = tonumber(param)
    if not id then
      BLL:Print("Nutzung: /bll src <itemID>")
    else
      local list = BLL.Sources:GetItemSources(id)
      if not list or table.getn(list) == 0 then
        BLL:Print(L["NO_SOURCE"])
      else
        BLL:Print("Quellen fuer Item " .. id .. ":")
        for i = 1, table.getn(list) do
          local s = list[i]
          DEFAULT_CHAT_FRAME:AddMessage("   " .. s.typeLabel .. ": " .. s.name
            .. (s.chance and (" (" .. s.chance .. "%)") or "")
            .. (s.zone and (" |cff888888- " .. s.zone .. "|r") or ""))
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
      BLL:Print("Statgewichte zurueckgesetzt.")
    elseif stat then
      BLL.Weights:Set(string.upper(stat), tonumber(value))
      BLL:Print("Gewicht " .. string.upper(stat) .. " = " .. (value ~= "" and value or "entfernt"))
    else
      local w = BLL.Weights:Get()
      BLL:Print("Aktuelle Gewichte:")
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
      BLL:Print("Nutzung: /bll set <itemID> - zeigt Set und Boni des Items")
    elseif not BLL.SetDB.loaded then
      BLL:Print("Keine Setdaten geladen.")
    else
      local setID, set = BLL.SetDB:GetSetOf(id)
      if not setID then
        BLL:Print("Item " .. id .. " gehoert zu keinem Set.")
      else
        local worn = BLL.SetDB:CountEquipped(setID)
        BLL:Print(set.name .. " - " .. worn .. "/" .. table.getn(set.items) .. " getragen")
        for i = 1, table.getn(set.bonuses) do
          local b = set.bonuses[i]
          local aktiv = (worn >= b.p) and "|cff00ff00[aktiv]|r" or "|cff888888[inaktiv]|r"
          DEFAULT_CHAT_FRAME:AddMessage("   " .. aktiv .. " (" .. b.p .. ") " .. (b.t or ""))
        end
      end
    end

  elseif command == "usecd" then
    local n = tonumber(param)
    if n and n > 0 then
      BananaLootlineDB.useCooldown = n
      BLL:Print("Angenommene Abklingzeit fuer Use-Effekte: " .. n .. " Sekunden")
    else
      BLL:Print("Angenommene Abklingzeit: "
        .. (BananaLootlineDB.useCooldown or BLL.Weights.DEFAULT_COOLDOWN)
        .. " Sekunden. Aendern mit /bll usecd <sekunden>. "
        .. "Die Datenbank liefert keine, deshalb wird geschaetzt.")
    end

  elseif command == "stop" then
    BLL.Candidates:Stop()

  elseif command == "rate" then
    local n = tonumber(param)
    if n and n >= 1 and n <= 30 then
      BananaLootlineDB.queryRate = n
      BLL:Print("Abfragerate: " .. n .. " Items/Sekunde")
    else
      BLL:Print("Aktuelle Abfragerate: " .. (BananaLootlineDB.queryRate or 8)
        .. " Items/Sekunde. Aendern mit /bll rate <1-30>. "
        .. "Hoehere Werte belasten den Server staerker.")
    end

  elseif command == "forget" then
    BananaLootlineDB.itemcache = {}
    BLL.Candidates.pool = nil
    BLL.Candidates.state = "idle"
    BLL:Print("Itemcache geleert.")

  elseif command == "unused" then
    BananaLootlineDB.showUnreachable = not BananaLootlineDB.showUnreachable
    BLL:Print("Unerreichbare Quellen (Entwicklereintraege, 0%% Drop): "
      .. (BananaLootlineDB.showUnreachable and "werden angezeigt"
                                          or "werden ausgeblendet"))
    BLL:Print("Fenster neu oeffnen, damit es wirkt.")

  elseif command == "cat" then
    local _, _, zone, cat = string.find(param, "^(.-)%s+(%a+)$")
    local VALID = { dungeon="DUNGEON", raid="RAID", welt="WELT",
                    weltboss="WELTBOSS", schlachtfeld="SCHLACHTFELD",
                    quest="QUEST", haendler="HAENDLER", objekt="OBJEKT" }
    if not zone or zone == "" then
      BLL:Print("Nutzung: /bll cat <Zonenname> <dungeon|raid|welt|weltboss|"
        .. "schlachtfeld|quest|haendler|objekt>")
      BLL:Print("Beispiel: /bll cat Concavius weltboss")
      local own = BananaLootlineDB.zoneCategory
      if own then
        BLL:Print("Eigene Zuordnungen:")
        for k, v in pairs(own) do
          DEFAULT_CHAT_FRAME:AddMessage("   " .. k .. " -> " .. v)
        end
      end
    elseif not VALID[string.lower(cat)] then
      BLL:Print("Unbekannte Kategorie: " .. cat)
    else
      BLL.Candidates:SetZoneCategory(zone, VALID[string.lower(cat)])
      BLL:Print(zone .. " gilt jetzt als " .. VALID[string.lower(cat)]
        .. ". Fenster neu oeffnen.")
    end

  elseif command == "ahead" then
    local n = tonumber(param)
    if n and n >= 0 and n <= 60 then
      BananaLootlineDB.planAhead = n
      BLL:Print("Vorausplanung: " .. n .. " Stufen. Neu suchen mit /bll up.")
    else
      BLL:Print("Vorausplanung: " .. BLL.Candidates:PlanAhead()
        .. " Stufen. Teile ueber deiner Stufe erscheinen mit Vermerk. "
        .. "Aendern mit /bll ahead <0-60>, 0 zeigt nur sofort Tragbares.")
    end

  elseif command == "spec" then
    local tab, name, total = BLL.Weights:DetectSpec()
    BLL.Weights:Get()
    if not tab then
      BLL:Print("Keine Spezialisierung erkannt (" .. (total or 0)
        .. " Talentpunkte vergeben, noetig sind "
        .. BLL.Weights.MIN_POINTS .. "). Es gelten die Klassenwerte.")
    else
      BLL:Print("Spezialisierung: " .. (BLL.Weights.activeSpec or name or "?")
        .. " (" .. (total or 0) .. " Punkte gesamt)")
    end
    for i = 1, GetNumTalentTabs() do
      local n, _, p = GetTalentTabInfo(i)
      DEFAULT_CHAT_FRAME:AddMessage("   " .. (n or i) .. ": " .. (p or 0))
    end

  elseif command == "info" then
    BLL:Print("pfQuest: " .. (BLL.Sources.available and "ja" or "nein")
      .. " | ItemDB: " .. ((BLL.ItemDB and BLL.ItemDB.loaded) and (BLL.ItemDB.count .. " Items") or "nicht importiert")
      .. " | Locale: " .. BLL.locale)

  elseif command == "help" then
    BLL:Print("Befehle:")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll            - Fenster oeffnen/schliessen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll lang de|en|auto - Anzeigesprache")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll up [n]     - Upgrades suchen (n = Stufenspanne, Standard 6)")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll stop       - laufende Abfrage abbrechen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll rate <n>   - Abfragerate in Items/Sekunde (Standard 8)")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll forget     - Itemcache leeren")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll spec       - erkannte Spezialisierung zeigen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll ahead <n>  - wie viele Stufen vorausgeplant wird")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll cat <Zone> <Kategorie> - Fundort umsortieren")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll unused     - unerreichbare Quellen ein/ausblenden")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll weight     - Statgewichte zeigen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll weight STR 3   - Gewicht setzen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll weight reset   - Gewichte zuruecksetzen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll scan       - Ausruestung neu scannen + ausgeben")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll dump <id>  - rohe Tooltipzeilen eines Items zeigen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll src <id>   - Quellen eines Items zeigen")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll set <id>   - Set und Boni eines Items")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll usecd <s>  - angenommene Abklingzeit fuer Use-Effekte")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll info       - Statuszeile")
    DEFAULT_CHAT_FRAME:AddMessage("   /bll debug      - Debugausgabe an/aus")

  else
    BLL.UI:Toggle()
  end
end
