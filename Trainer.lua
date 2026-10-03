--[[----------------------------------------------------------------------
  BananaLootline - Trainer.lua

  Erinnerung an neue Zauber beim Klassenlehrer und neue Rezepte beim
  Berufslehrer, dazu das Seitenmenue "Extras" rechts am Hauptfenster.

  Woher die Daten kommen: vom Lehrer selbst. Oeffnet man sein Fenster,
  liefert der Client die komplette Liste - auch was man noch nicht
  lernen kann, mit Stufe, Fertigkeit und Preis. Das wird pro Charakter
  gemerkt. Steigt danach die Stufe oder die Berufsfertigkeit, prueft
  das Addon die Liste und meldet, was jetzt lernbar ist. Die Angaben
  stammen damit direkt von diesem Server, auch fuer eigene Zauber.

  Einmal muss man beim Lehrer gewesen sein. Bis dahin gilt beim
  Klassenlehrer die Faustregel: auf geraden Stufen gibt es in Vanilla
  fast immer etwas Neues.
------------------------------------------------------------------------]]

local BLL = BananaLootline
BLL.Trainer = {}
local T = BLL.Trainer

local function Store()
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.trainer = BananaLootlineChar.trainer or { prof = {} }
  BananaLootlineChar.trainer.prof = BananaLootlineChar.trainer.prof or {}
  return BananaLootlineChar.trainer
end

-- Kupfer als "1g 20s 5c"
function BLL:FormatMoney(c)
  c = math.floor(c or 0)
  local g, si, cu = math.floor(c / 10000), math.mod(math.floor(c / 100), 100), math.mod(c, 100)
  local out = {}
  if g > 0 then table.insert(out, g .. "g") end
  if si > 0 then table.insert(out, si .. "s") end
  if cu > 0 or table.getn(out) == 0 then table.insert(out, cu .. "c") end
  return table.concat(out, " ")
end

local function PlayerLevel()
  return (BLL.player and BLL.player.level) or (UnitLevel and UnitLevel("player")) or 1
end

-- Fertigkeitsstufe eines Berufs aus dem Fertigkeitenfenster
function T:SkillRank(name)
  if not name or not GetNumSkillLines then return nil end
  for i = 1, GetNumSkillLines() do
    local n, isHeader, _, rank = GetSkillLineInfo(i)
    if n == name and not isHeader then return rank end
  end
  return nil
end

------------------------------------------------------------------
-- Lehrerfenster lesen
------------------------------------------------------------------

-- Liest alle Eintraege des offenen Lehrerfensters. Damit auch die noch
-- nicht lernbaren erscheinen, wird der Filter "nicht verfuegbar" kurz
-- eingeschaltet und danach wiederhergestellt.
function T:Scan()
  if not GetNumTrainerServices then return end
  local oldFilter = GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter("unavailable")
  if SetTrainerServiceTypeFilter and not oldFilter then
    SetTrainerServiceTypeFilter("unavailable", 1)
  end
  if ExpandTrainerSkillLine then pcall(ExpandTrainerSkillLine, 0) end

  local isProf = IsTradeskillTrainer and IsTradeskillTrainer()
  local entries, skillLine = {}, nil
  for i = 1, GetNumTrainerServices() do
    local name, sub, category = GetTrainerServiceInfo(i)
    if name and category ~= "header" then
      local e = { n = name, r = (sub and sub ~= "") and sub or nil, used = (category == "used") or nil }
      if GetTrainerServiceLevelReq then
        local lvl = GetTrainerServiceLevelReq(i)
        if lvl and lvl > 0 then e.l = lvl end
      end
      if GetTrainerServiceCost then e.c = GetTrainerServiceCost(i) end
      if isProf and GetTrainerServiceSkillReq then
        local sname, srank = GetTrainerServiceSkillReq(i)
        if sname and sname ~= "" then skillLine = skillLine or sname end
        if srank and srank > 0 then e.s = srank end
      end
      table.insert(entries, e)
    end
  end

  if SetTrainerServiceTypeFilter and not oldFilter then
    SetTrainerServiceTypeFilter("unavailable", 0)
  end

  local store = Store()
  local where = GetZoneText and GetZoneText() or nil
  if isProf then
    skillLine = skillLine or (GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(1)) or "?"
    store.prof[skillLine] = { list = entries, level = PlayerLevel(), zone = where, t = time and time() }
  else
    store.class = { list = entries, level = PlayerLevel(), zone = where, t = time and time() }
  end
  self:Remember()
  if BLL.Extras then BLL.Extras:Refresh() end
end

------------------------------------------------------------------
-- Auswertung
------------------------------------------------------------------

-- Klassenlehrer: lernbar jetzt, und die naechsten Stufen
function T:ClassStatus()
  local c = Store().class
  if not c then return nil end
  local lvl = PlayerLevel()
  local now, later, cost = {}, {}, 0
  for _, e in ipairs(c.list) do
    if not e.used then
      if not e.l or e.l <= lvl then
        table.insert(now, e); cost = cost + (e.c or 0)
      else
        later[e.l] = later[e.l] or {}
        table.insert(later[e.l], e)
      end
    end
  end
  return { now = now, later = later, cost = cost, visit = c }
end

-- Berufslehrer: je Beruf lernbar jetzt und die naechsten Rezepte
function T:ProfStatus()
  local out = {}
  for line, p in pairs(Store().prof) do
    local rank = self:SkillRank(line) or 0
    local lvl = PlayerLevel()
    local now, next, cost = {}, {}, 0
    for _, e in ipairs(p.list) do
      if not e.used then
        if (not e.s or e.s <= rank) and (not e.l or e.l <= lvl) then
          table.insert(now, e); cost = cost + (e.c or 0)
        else
          table.insert(next, e)
        end
      end
    end
    table.sort(next, function(a, b) return (a.s or 0) < (b.s or 0) end)
    table.insert(out, { line = line, rank = rank, now = now, next = next, cost = cost, visit = p })
  end
  table.sort(out, function(a, b) return a.line < b.line end)
  return out
end

-- Wie viel ist insgesamt jetzt lernbar? Fuer die Lasche am Fenster.
function T:LearnableCount()
  local n = 0
  local c = self:ClassStatus()
  if c then n = n + table.getn(c.now) end
  for _, p in ipairs(self:ProfStatus()) do n = n + table.getn(p.now) end
  return n
end

------------------------------------------------------------------
-- Meldungen
------------------------------------------------------------------

-- Merkt sich den gemeldeten Stand, damit nur Neues gemeldet wird.
function T:Remember()
  local store = Store()
  local c = self:ClassStatus()
  store.seenClass = c and table.getn(c.now) or 0
  store.seenProf = {}
  for _, p in ipairs(self:ProfStatus()) do store.seenProf[p.line] = table.getn(p.now) end
end

local function Announce(text)
  BLL:Print("|cff00ff00" .. text .. "|r")
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(text, 1, 0.82, 0, 1, 5)
  end
end

function T:CheckLevel(newLevel)
  local L = BLL.L
  local store = Store()
  local c = self:ClassStatus()
  if c then
    local n = table.getn(c.now)
    if n > (store.seenClass or 0) then
      Announce(string.format(L["TR_CLASS_NEW"], n, BLL:FormatMoney(c.cost)))
    end
  elseif newLevel and math.mod(newLevel, 2) == 0 then
    -- Noch nie beim Lehrer gewesen: Faustregel
    Announce(L["TR_CLASS_GUESS"])
  end
  self:CheckProfessions(true)
  self:Remember()
  if BLL.Extras then BLL.Extras:Refresh() end
end

function T:CheckProfessions(silentRemember)
  local L = BLL.L
  local store = Store()
  store.seenProf = store.seenProf or {}
  for _, p in ipairs(self:ProfStatus()) do
    local n = table.getn(p.now)
    if n > (store.seenProf[p.line] or 0) then
      Announce(string.format(L["TR_PROF_NEW"], p.line, n))
    end
  end
  if not silentRemember then
    self:Remember()
    if BLL.Extras then BLL.Extras:Refresh() end
  end
end

------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("TRAINER_SHOW")
ev:RegisterEvent("TRAINER_UPDATE")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("CHAT_MSG_SKILL")
local scanning, lastScan = false, -100
ev:SetScript("OnEvent", function()
  if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
    -- Der Scan schaltet den Filter um und loest damit selbst
    -- TRAINER_UPDATE aus, oft erst im naechsten Bild. Das darf keinen
    -- weiteren Scan anstossen, sonst schaukelt es sich auf. Nach dem
    -- Lernen eines Zaubers kommt TRAINER_UPDATE spaeter und zaehlt.
    local now = GetTime and GetTime() or 0
    if scanning or (event == "TRAINER_UPDATE" and now - lastScan < 1) then return end
    scanning = true
    pcall(T.Scan, T)
    lastScan = GetTime and GetTime() or 0
    scanning = false
  elseif event == "PLAYER_LEVEL_UP" then
    if BLL.player then BLL.player.level = arg1 or BLL.player.level end
    T:CheckLevel(arg1)
  elseif event == "CHAT_MSG_SKILL" then
    T:CheckProfessions()
  end
end)

------------------------------------------------------------------
-- Seitenmenue "Extras"
--
-- Eine Lasche mit Pfeil am rechten Rand des Hauptfensters klappt ein
-- schmales Menue daneben auf. Platz fuer weitere Zusaetze spaeter.
------------------------------------------------------------------

BLL.Extras = {}
local X = BLL.Extras

local WIDTH = 270

function X:Init()
  local main = BananaLootlineFrame
  if self.panel or not main then return end
  local L = BLL.L

  local tab = CreateFrame("Button", "BananaLootlineExtrasTab", main)
  tab:SetWidth(22); tab:SetHeight(64)
  tab:SetPoint("LEFT", main, "RIGHT", -4, 40)
  tab:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = false, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  tab:SetBackdropColor(0.45, 0.05, 0.05, 1)
  local arrow = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  arrow:SetPoint("CENTER", tab, "CENTER", 1, 6)
  tab.arrow = arrow
  local count = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  count:SetPoint("CENTER", tab, "CENTER", 0, -14)
  tab.count = count
  tab:SetScript("OnClick", function() X:Toggle() end)
  tab:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(BLL.L["EX_TITLE"])
    GameTooltip:AddLine(BLL.L["EX_TIP"], 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.tab = tab

  local p = CreateFrame("Frame", "BananaLootlineExtras", main)
  p:SetWidth(WIDTH); p:SetHeight(main:GetHeight() - 40)
  p:SetPoint("TOPLEFT", main, "TOPRIGHT", 14, -20)
  p:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  p:SetBackdropColor(0, 0, 0, 1)
  p:Hide()

  local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)
  title:SetTextColor(1, 0.82, 0)
  p.title = title

  local body = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -42)
  body:SetWidth(WIDTH - 28)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  p.body = body

  self.panel = p
  if BananaLootlineDB and BananaLootlineDB.extrasOpen then p:Show() end
  self:Refresh()
end

function X:Toggle()
  if not self.panel then return end
  if self.panel:IsVisible() then self.panel:Hide() else self.panel:Show() end
  BananaLootlineDB.extrasOpen = self.panel:IsVisible() and true or nil
  self:Refresh()
end

-- Text des Menues
function X:Text()
  local L = BLL.L
  local lines = {}
  local function add(s) table.insert(lines, s) end
  local MAXLATER, MAXPROF = 3, 5

  add("|cffffd100" .. L["TR_CLASS"] .. "|r")
  local c = T:ClassStatus()
  if not c then
    add("|cff888888" .. L["TR_NOVISIT"] .. "|r")
  else
    if table.getn(c.now) > 0 then
      add("|cff44ff44" .. string.format(L["TR_NOW"], table.getn(c.now), BLL:FormatMoney(c.cost)) .. "|r")
      for _, e in ipairs(c.now) do
        add("  |cffffffff" .. e.n .. "|r" .. (e.r and (" |cff888888" .. e.r .. "|r") or ""))
      end
    else
      add("|cff888888" .. L["TR_NOTHING"] .. "|r")
    end
    local lv = {}
    for l in pairs(c.later) do table.insert(lv, l) end
    table.sort(lv)
    for i = 1, math.min(MAXLATER, table.getn(lv)) do
      add(" ")
      add("|cffffd100" .. string.format(L["TR_LEVEL"], lv[i]) .. "|r")
      for _, e in ipairs(c.later[lv[i]]) do
        add("  |cffaaaaaa" .. e.n .. "|r" .. (e.r and (" |cff666666" .. e.r .. "|r") or ""))
      end
    end
    add(" ")
    add("|cff888888" .. string.format(L["TR_VISIT"], c.visit.level or 0, c.visit.zone or "?") .. "|r")
  end

  local profs = T:ProfStatus()
  add(" ")
  add("|cffffd100" .. L["TR_PROF"] .. "|r")
  if table.getn(profs) == 0 then
    add("|cff888888" .. L["TR_PROF_NOVISIT"] .. "|r")
  end
  for _, p in ipairs(profs) do
    add(" ")
    add("|cffffffff" .. p.line .. "|r |cff888888(" .. p.rank .. ")|r")
    if table.getn(p.now) > 0 then
      add("  |cff44ff44" .. string.format(L["TR_NOW"], table.getn(p.now), BLL:FormatMoney(p.cost)) .. "|r")
      for i = 1, math.min(MAXPROF, table.getn(p.now)) do
        add("    " .. p.now[i].n)
      end
    end
    for i = 1, math.min(MAXPROF, table.getn(p.next)) do
      local e = p.next[i]
      add("  |cffaaaaaa" .. e.n .. "|r |cff666666"
        .. (e.s and string.format(L["TR_SKILL"], e.s) or "")
        .. (e.l and (" " .. string.format(L["TR_LEVEL"], e.l)) or "") .. "|r")
    end
  end
  return table.concat(lines, "\n")
end

function X:Refresh()
  if not self.tab then return end
  local n = T:LearnableCount()
  local open = self.panel and self.panel:IsVisible()
  self.tab.arrow:SetText(open and "<" or ">")
  self.tab.count:SetText(n > 0 and ("|cff44ff44" .. n .. "|r") or "")
  if open then
    self.panel.title:SetText(BLL.L["EX_TITLE"])
    self.panel.body:SetText(self:Text())
  end
end
