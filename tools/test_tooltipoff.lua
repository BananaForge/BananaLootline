-- Fundorte im Item-Tooltip sind standardmaessig aus.
--
-- Der Block blitzte in Taschen-Addons kurz auf und verschwand wieder;
-- gewollt war er nie. Eine alte gespeicherte Einstellung "an" wird
-- einmal zurueckgesetzt, /bll tooltip schaltet ihn wieder ein.
string.gmatch = nil; select = nil
local f = io.open("Core.lua"); local src = f:read("*a"); f:close()
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

check(string.find(src, "tooltipSources = false,", 1, true), "Standard ist aus")
check(string.find(src, "tooltipSourcesReset", 1, true), "einmalige Ruecksetzung vorhanden")
check(string.find(src, 'command == "tooltip"', 1, true), "Befehl /bll tooltip vorhanden")

-- Ruecksetzung nachspielen: der Block aus ApplyDefaults
local _, _, block = string.find(src, "(if not BananaLootlineDB%.tooltipSourcesReset then.-\n  end)")
check(block, "Block gefunden")
if block then
  local run = loadstring(block)
  BananaLootlineDB = { tooltipSources = true }
  run()
  check(BananaLootlineDB.tooltipSources == false, "alte Einstellung zurueckgesetzt")
  BananaLootlineDB.tooltipSources = true    -- danach /bll tooltip on
  run()
  check(BananaLootlineDB.tooltipSources == true, "spaeteres Einschalten bleibt erhalten")
end

GetLocale = function() return "deDE" end
BananaLootline = {}
dofile("Locale.lua")
for _, k in ipairs({ "HELP_TOOLTIP", "TOOLTIP_ON", "TOOLTIP_OFF" }) do
  check(BananaLootline.L[k] and BananaLootline.L[k] ~= k, "Text fehlt: " .. k)
end
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
