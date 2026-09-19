--[[----------------------------------------------------------------------
  BananaLootline - Scanner.lua

  Liest Stats aus einem Item, indem der Tooltip in einen unsichtbaren
  Frame gerendert und zeilenweise geparst wird. Das ist im 1.12-Client
  der einzige Weg an die Werte zu kommen (kein GetItemStats).

  Ergebnis: flache Tabelle { STR = 10, STA = 15, ARMOR = 115, ... }
  Nicht vorhandene Stats fehlen (nicht 0), damit man leicht pruefen kann,
  ob ein Item ueberhaupt geparst wurde.

  Achtung: GetItemInfo() liefert im 1.12-Client KEIN Itemlevel - nur
  Name, Link, Qualitaet, benoetigte Stufe, Typ, Subtyp, Stackgroesse,
  EquipLoc und Textur. Itemlevel kommt aus der importierten ItemDB.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Scanner = {}
local Scanner = BLL.Scanner

------------------------------------------------------------------
-- Versteckter Scan-Tooltip
------------------------------------------------------------------

local scanTip = CreateFrame("GameTooltip", "BananaLootlineScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

Scanner.tooltip = scanTip

-- Cache, damit dasselbe Item nicht bei jedem Tooltip-Hover neu geparst wird.
local cache = {}

function Scanner:ClearCache()
  cache = {}
end

------------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------------

-- Akzeptiert itemID (Zahl), vollen Itemlink oder nackten "item:1234:0:0:0"
--
-- WICHTIG: GetInventoryItemLink() und GetContainerItemLink() liefern den
-- VOLLSTAENDIGEN Link inklusive Farbcode und Klammertext:
--
--   |cffffffff|Hitem:12345:0:0:0|h[Schwert]|h|r
--
-- SetHyperlink() im 1.12-Client akzeptiert aber nur den nackten Teil
-- zwischen |H und |h. Alles andere wirft "Unknown link type".
-- Deshalb hier IMMER reduzieren, bevor der Link weitergereicht wird.
function Scanner:NormalizeLink(item)
  if type(item) == "number" then
    return "item:" .. item .. ":0:0:0"
  end

  if type(item) ~= "string" or item == "" then
    return nil
  end

  -- Vollen Link auf den Hyperlink-Teil reduzieren
  local _, _, inner = string.find(item, "|H(.-)|h")
  if inner then
    return inner
  end

  -- Bereits nackt uebergeben
  if string.find(item, "^item:") then
    return item
  end

  -- Reine Zahl als String
  local id = tonumber(item)
  if id then
    return "item:" .. id .. ":0:0:0"
  end

  return nil
end

local function ToHyperlink(item)
  return Scanner:NormalizeLink(item)
end

-- Suffix-IDs koennen negativ sein (Items mit Zufallsverzauberung),
-- deshalb das Vorzeichen im Pattern zulassen.
function Scanner:GetItemID(link)
  if not link then return nil end
  if type(link) == "number" then return link end
  local _, _, id = string.find(link, "item:(%-?%d+)")
  return tonumber(id)
end

local function ShouldSkip(line)
  for i = 1, table.getn(BLL.SKIP_PREFIX) do
    if string.find(line, BLL.SKIP_PREFIX[i], 1, true) then
      return true
    end
  end
  return false
end

------------------------------------------------------------------
-- Rohe Tooltipzeilen holen
------------------------------------------------------------------

-- ClearLines() setzt im 1.12-Client nur den internen Zeilenzaehler zurueck,
-- laesst die Texte der FontStrings aber stehen. Hat das naechste Item
-- weniger Zeilen als das vorherige, liefert NumLines() die alten Zeilen mit
-- und wir parsen Werte, die dem Item gar nicht gehoeren. Genau so bekam ein
-- Off-Hand-Schmuckstueck das Tempo des zuvor gescannten Dolches.
--
-- Deshalb vor jedem Scan alle FontStrings explizit leeren.
local MAX_TOOLTIP_LINES = 40

local function WipeScanTooltip()
  for i = 1, MAX_TOOLTIP_LINES do
    local left  = getglobal("BananaLootlineScanTooltipTextLeft" .. i)
    local right = getglobal("BananaLootlineScanTooltipTextRight" .. i)
    if left  then left:SetText("")  end
    if right then right:SetText("") end
  end
end

function Scanner:GetLines(item)
  local link = ToHyperlink(item)
  if not link then return nil end

  -- Der Scanner ist ausschliesslich fuer Items zustaendig. Quest-, Spell-
  -- oder Enchant-Links koennen ueber GetItem()/Chatlinks hereinkommen und
  -- haetten hier nichts verloren.
  if not string.find(link, "^item:") then return nil end

  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:ClearLines()
  WipeScanTooltip()

  -- Zusaetzlich abgesichert: selbst wenn doch mal ein kaputter Link
  -- durchrutscht, soll das den Aufrufer nicht abbrechen und vor allem
  -- nicht das Fehlerfenster fluten.
  local ok = pcall(function() scanTip:SetHyperlink(link) end)
  if not ok then
    BLL:Debug("SetHyperlink fehlgeschlagen fuer: " .. tostring(link))
    scanTip:Hide()
    return nil
  end

  local lines = {}
  local n = scanTip:NumLines()
  for i = 1, n do
    local left = getglobal("BananaLootlineScanTooltipTextLeft" .. i)
    local right = getglobal("BananaLootlineScanTooltipTextRight" .. i)
    local lt = left and left:GetText()
    local rt = right and right:GetText()
    if lt and lt ~= "" then table.insert(lines, lt) end
    if rt and rt ~= "" then table.insert(lines, rt) end
  end

  scanTip:Hide()
  return lines
end

------------------------------------------------------------------
-- Stats parsen
------------------------------------------------------------------

function Scanner:GetStats(item)
  local id = (type(item) == "number") and item or self:GetItemID(item)
  if id and cache[id] then return cache[id] end

  local lines = self:GetLines(item)
  if not lines or table.getn(lines) == 0 then return nil end

  local stats = {}
  local patterns = BLL.PATTERNS
  local pcount = table.getn(patterns)

  for i = 1, table.getn(lines) do
    local line = lines[i]

    if not ShouldSkip(line) then
      -- Schadensbereich zuerst (zwei Captures)
      local _, _, dmin, dmax = string.find(line, BLL.DMG_PATTERN)
      if dmin then
        stats["WEAPON_MIN"] = tonumber(dmin)
        stats["WEAPON_MAX"] = tonumber(dmax)
      else
        for p = 1, pcount do
          local entry = patterns[p]
          local key, pat, sign = entry[1], entry[2], entry[3] or 1
          local _, _, value = string.find(line, pat)
          if value then
            local num = tonumber(value)
            if num then
              stats[key] = (stats[key] or 0) + (num * sign)
            end
            break   -- eine Zeile liefert maximal einen Stat
          end
        end
      end
    end
  end

  if id then cache[id] = stats end
  return stats
end

------------------------------------------------------------------
-- Kompakte Iteminfo (Name, Qualitaet, Slot, ...)
------------------------------------------------------------------

function Scanner:GetItemInfoSafe(item)
  local id = (type(item) == "number") and item or self:GetItemID(item)
  if not id then return nil end

  -- 1.12: name, link, quality, reqLevel, type, subType, stackCount, equipLoc, texture
  local name, link, quality, reqLevel, itype, subtype, stack, equipLoc, texture = GetItemInfo(id)

  if not name then
    -- Item ist nicht im Client-Cache. Der Tooltip-Aufruf oben stoesst die
    -- Serverabfrage an; beim naechsten Versuch ist es meist da.
    self:GetLines(id)
    name, link, quality, reqLevel, itype, subtype, stack, equipLoc, texture = GetItemInfo(id)
  end

  if not name then return nil end

  local info = {
    id       = id,
    name     = name,
    link     = link,
    quality  = quality,
    reqLevel = reqLevel,
    itype    = itype,
    subtype  = subtype,
    equipLoc = equipLoc,
    texture  = texture,
  }

  -- Itemlevel und weitere Felder aus der importierten DB anreichern
  if BLL.ItemDB and BLL.ItemDB.loaded then
    local extra = BLL.ItemDB:Get(id)
    if extra then
      info.ilvl        = extra.ilvl
      info.classMask   = extra.classmask
      info.raceMask    = extra.racemask
      info.slotDB      = extra.slot
    end
  end

  return info
end

------------------------------------------------------------------
-- Debughilfe: rohe Zeilen ins Chatfenster
------------------------------------------------------------------

function Scanner:DumpLines(item)
  local lines = self:GetLines(item)
  if not lines then
    BLL:Print("Keine Tooltipdaten (Item nicht gecached?)")
    return
  end

  BLL:Print("Tooltipzeilen:")
  for i = 1, table.getn(lines) do
    DEFAULT_CHAT_FRAME:AddMessage("  |cff888888[" .. i .. "]|r " .. lines[i])
  end

  local stats = self:GetStats(item)
  local found = ""
  for k, v in pairs(stats or {}) do
    found = found .. k .. "=" .. v .. "  "
  end
  BLL:Print("Erkannt: " .. (found ~= "" and found or "|cffff0000nichts|r"))
end

------------------------------------------------------------------
-- Stats zweier Items vergleichen -> Differenztabelle
------------------------------------------------------------------

function Scanner:Diff(itemA, itemB)
  local a = self:GetStats(itemA) or {}
  local b = self:GetStats(itemB) or {}
  local diff = {}

  for k, v in pairs(a) do diff[k] = (diff[k] or 0) + v end
  for k, v in pairs(b) do diff[k] = (diff[k] or 0) - v end

  -- Nulldifferenzen entfernen
  for k, v in pairs(diff) do
    if v == 0 then diff[k] = nil end
  end
  return diff
end
