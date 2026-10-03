-- Lehrer-Erinnerung: Klassenlehrer und Berufslehrer, nachgebaut mit
-- einem simulierten Lehrerfenster.
string.gmatch = nil; select = nil
GetLocale = function() return "deDE" end
BananaLootline = {}
dofile("Locale.lua")
local BLL = BananaLootline
local chat, screen = {}, {}
BLL.Print = function(self, m) table.insert(chat, m) end
UIErrorsFrame = { AddMessage = function(self, m) table.insert(screen, m) end }
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
GetZoneText = function() return "Ironforge" end
time = os.time
BananaLootlineDB, BananaLootlineChar = {}, {}
BLL.player = { level = 15 }

-- Simuliertes Lehrerfenster
local services, filterUnavail, isProf = {}, 0, false
GetNumTrainerServices = function()
  local n = 0
  for _, s in ipairs(services) do if s[3] ~= "unavailable" or filterUnavail == 1 then n = n + 1 end end
  return n
end
local function visible(i)
  local k = 0
  for _, s in ipairs(services) do
    if s[3] ~= "unavailable" or filterUnavail == 1 then k = k + 1; if k == i then return s end end
  end
end
GetTrainerServiceInfo = function(i) local s = visible(i); return s[1], s[2], s[3] end
GetTrainerServiceLevelReq = function(i) return visible(i)[4] end
GetTrainerServiceCost = function(i) return visible(i)[5] end
GetTrainerServiceSkillReq = function(i) local s = visible(i); return s[6], s[7] end
GetTrainerServiceTypeFilter = function(t) return filterUnavail == 1 end
SetTrainerServiceTypeFilter = function(t, v) filterUnavail = v end
IsTradeskillTrainer = function() return isProf end
local skills = { { "Leatherworking", false, nil, 90 } }
GetNumSkillLines = function() return table.getn(skills) end
GetSkillLineInfo = function(i) local s = skills[i]; return s[1], s[2], s[3], s[4] end

dofile("Trainer.lua")
local T = BLL.Trainer
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

-- 1. Vor dem ersten Besuch: Faustregel auf geraden Stufen
T:CheckLevel(16)
check(string.find(screen[1] or "", "vermutlich", 1, true), "Faustregel ohne Besuch")
screen = {}
T:CheckLevel(17)
check(table.getn(screen) == 0, "auf ungerader Stufe ohne Besuch keine Meldung")

-- 2. Besuch beim Klassenlehrer auf Stufe 17
BLL.player.level = 17
services = {
  { "Serpent Sting", "Rang 1", "used",        4,  0 },
  { "Arcane Shot",   "Rang 2", "available",   16, 1200 },
  { "Serpent Sting", "Rang 2", "unavailable", 18, 1500 },
  { "Multi-Shot",    "Rang 1", "unavailable", 18, 2000 },
  { "Aspect of the Cheetah", "", "unavailable", 20, 2500 },
}
T:Scan()
check(filterUnavail == 0, "Filter wird wiederhergestellt")
local c = T:ClassStatus()
check(c and table.getn(c.now) == 1 and c.now[1].n == "Arcane Shot", "jetzt lernbar: Arcane Shot")
check(c.later[18] and table.getn(c.later[18]) == 2, "Stufe 18 bringt zwei Zauber")
check(T:LearnableCount() == 1, "Zaehler 1")

-- 3. Aufstieg auf 18: Meldung mit Anzahl und Preis
screen = {}
BLL.player.level = 18
T:CheckLevel(18)
check(string.find(screen[1] or "", "3 Zauber", 1, true), "Meldung nennt 3 Zauber, ist " .. tostring(screen[1]))
check(string.find(screen[1] or "", "47s", 1, true), "Meldung nennt den Preis 47s")
-- Keine Wiederholung ohne Neues
screen = {}
T:CheckLevel(18)
check(table.getn(screen) == 0, "keine doppelte Meldung")

-- 4. Berufslehrer: Lederverarbeitung 90
isProf = true
services = {
  { "Dark Leather Boots", "", "available",   0, 800, "Leatherworking", 90 },
  { "Hillman's Shoulders", "", "unavailable", 0, 1000, "Leatherworking", 100 },
  { "Guardian Pants",     "", "unavailable", 0, 1200, "Leatherworking", 125 },
}
T:Scan()
local p = T:ProfStatus()
check(p[1] and p[1].line == "Leatherworking", "Beruf erkannt")
check(p[1] and table.getn(p[1].now) == 1, "ein Rezept jetzt lernbar")
check(p[1] and p[1].next[1].n == "Hillman's Shoulders", "naechstes Rezept bei 100")

-- 5. Fertigkeit steigt auf 100: Meldung
screen = {}
skills[1][4] = 100
T:CheckProfessions()
check(string.find(screen[1] or "", "Leatherworking: 2", 1, true), "Berufsmeldung bei 100, ist " .. tostring(screen[1]))

-- 6. Text des Seitenmenues
local txt = BLL.Extras:Text()
check(string.find(txt, "Klassenlehrer", 1, true) and string.find(txt, "Berufslehrer", 1, true), "Menue hat beide Abschnitte")
check(string.find(txt, "Stufe 20", 1, true), "naechste Stufe im Menue")
check(BLL:FormatMoney(14700) == "1g 47s", "Geld formatiert")

-- 7. Aufklappen: Stufen und Berufe starten zu, "jetzt lernbar" offen
local function find(list, pat)
  for _, e in ipairs(list) do if e.text and string.find(e.text, pat, 1, true) then return e end end
end
local list = BLL.Extras:Entries()
local h20 = find(list, "Stufe 20")
check(h20 and h20.kind == "head" and not h20.open, "Stufe 20 ist eine zugeklappte Kopfzeile")
check(not find(list, "Aspect of the Cheetah"), "Zauber zugeklappter Stufen sind nicht sichtbar")
local hp = find(list, "Leatherworking")
check(hp and hp.kind == "head" and not hp.open and hp.right, "Beruf zu, mit Lernbar-Hinweis rechts")
BLL.Extras:ToggleKey("c:20")
list = BLL.Extras:Entries()
check(find(list, "Aspect of the Cheetah"), "nach Klick sind die Zauber der Stufe 20 sichtbar")
BLL.Extras:ToggleKey("p:Leatherworking")
list = BLL.Extras:Entries()
check(find(list, "Guardian Pants"), "nach Klick sind die Rezepte sichtbar")
check(BananaLootlineDB.extrasKeys["c:20"] == true, "Zustand gespeichert")
BLL.Extras:ToggleKey("c:20")
check(not find(BLL.Extras:Entries(), "Aspect of the Cheetah"), "zweiter Klick klappt wieder zu")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
