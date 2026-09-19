--[[----------------------------------------------------------------------
  BananaLootline - Locale.lua

  Zwei Dinge stecken hier drin:

  1. UI-Strings (deDE / enUS)
  2. Die Tooltip-Patterns, mit denen Scanner.lua Stats aus einem Item liest.

  WICHTIG: Der 1.12-Client hat kein GetItemStats(). Der einzige zuverlaessige
  Weg, an die Werte eines Items zu kommen, ist den Tooltip in einen
  unsichtbaren Frame zu rendern und die Zeilen per String-Pattern zu parsen.
  Das ist zwangslaeufig sprachabhaengig.

  Die deDE-Patterns unten sind ein begruendeter Startsatz und muessen gegen
  einen echten deutschen Client verifiziert werden. Vorgehen: /bll debug
  ueber ein angelegtes Item laufen lassen - der Befehl dumpt alle rohen
  Tooltipzeilen ins Chatfenster. Was nicht gematcht wird, faellt sofort auf.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline

-- Zwei Sprachen, sauber getrennt:
--   clientLocale  Sprache des Spielclients. Bestimmt Tooltip-Muster und
--                 R�stungsnamen, denn die liefert der Client. Nicht
--                 umschaltbar.
--   locale        Anzeigesprache des Addons. Folgt dem Client, bis der
--                 Nutzer oben rechts DE/EN waehlt.
BLL.clientLocale = GetLocale()
BLL.locale = BLL.clientLocale

------------------------------------------------------------------
-- UI-Strings
------------------------------------------------------------------

local L_enUS = {
  ["ADDON_NAME"]      = "BananaLootline",
  ["LOADED"]          = "loaded. Type /bll to open.",
  ["TITLE"]           = "BananaLootline",
  ["EMPTY"]           = "Empty",
  ["SOURCE"]          = "Source",
  ["SOURCES"]         = "Sources",
  ["DROPS_FROM"]      = "Drops from",
  ["OBJECT"]          = "Object",
  ["VENDOR"]          = "Vendor",
  ["QUEST"]           = "Quest",
  ["QUEST_CHOICE"]    = "choice of",
  ["CHANCE"]          = "Chance",
  ["NO_SOURCE"]       = "No source data",
  ["NO_PFQUEST"]      = "pfQuest not found - source lookup disabled.",
  ["PFQUEST_OK"]      = "pfQuest database detected",
  ["NO_ITEMDB"]       = "No item database imported yet (see tools/octodb_import.py).",
  ["SCAN_DONE"]       = "Gear scanned",
  ["TAB_GEAR"]        = "Gear",
  ["TAB_BAGS"]        = "Bags",
  ["TAB_INFO"]        = "Info",
  ["STATS_HEADER"]    = "Summed stats",
  ["NO_SPEC"]         = "no spec detected",
  ["NO_PFQUEST_SHORT"] = "pfQuest missing",
  ["LANG_TOOLTIP"]    = "Switch language",
  ["LANG_SWITCHED"]   = "Language set to English.",
  ["ABOUT_TOOLTIP"]   = "About this addon",
  ["THANKS_TITLE"]    = "Thank you for your support!",
  ["THANKS_BODY"]     = "This addon was built in many hours of spare time and stays free.\n\nIf you would like to say thanks, feel free to send me mail - gold, mats or just a few kind words always make my day.\n\n|cff888888Completely optional - the addon works just fine without it.|r",
  ["CHARACTER"]       = "Character:",
  ["FILL_NAME"]       = "Fill in name",
  ["CLOSE"]           = "Close",
  ["MAILBOX_OPEN"]    = "Mailbox open - one click fills in the name.",
  ["MAILBOX_CLOSED"]  = "Select and press Ctrl+C to copy the name. At a mailbox it is filled in automatically.",
  ["RECIPIENT_SET"]   = "Recipient",
  ["RECIPIENT_THANKS"] = "has been filled in. Thank you very much!",
  ["NEED_MAILBOX"]    = "You need to stand at a",
  ["MAILBOX"]         = "mailbox",
  ["NEED_MAILBOX_2"]  = "for that. You can also select the name and copy it with Ctrl+C.",
}

local L_deDE = {
  ["ADDON_NAME"]      = "BananaLootline",
  ["LOADED"]          = "geladen. /bll zum Oeffnen.",
  ["TITLE"]           = "BananaLootline",
  ["EMPTY"]           = "Leer",
  ["SOURCE"]          = "Quelle",
  ["SOURCES"]         = "Quellen",
  ["DROPS_FROM"]      = "Droppt von",
  ["OBJECT"]          = "Objekt",
  ["VENDOR"]          = "Haendler",
  ["QUEST"]           = "Quest",
  ["QUEST_CHOICE"]    = "Wahl aus",
  ["CHANCE"]          = "Chance",
  ["NO_SOURCE"]       = "Keine Quellendaten",
  ["NO_PFQUEST"]      = "pfQuest nicht gefunden - Quellensuche deaktiviert.",
  ["PFQUEST_OK"]      = "pfQuest-Datenbank erkannt",
  ["NO_ITEMDB"]       = "Noch keine Itemdatenbank importiert (siehe tools/octodb_import.py).",
  ["SCAN_DONE"]       = "Ausruestung gescannt",
  ["TAB_GEAR"]        = "Ausruestung",
  ["TAB_BAGS"]        = "Taschen",
  ["TAB_INFO"]        = "Info",
  ["STATS_HEADER"]    = "Summierte Werte",
  ["NO_SPEC"]         = "keine Spez. erkannt",
  ["NO_PFQUEST_SHORT"] = "pfQuest fehlt",
  ["LANG_TOOLTIP"]    = "Sprache umschalten",
  ["LANG_SWITCHED"]   = "Sprache auf Deutsch gestellt.",
  ["ABOUT_TOOLTIP"]   = "Ueber dieses Addon",
  ["THANKS_TITLE"]    = "Danke fuer die Unterstuetzung!",
  ["THANKS_BODY"]     = "Dieses Addon ist in vielen Stunden Freizeit entstanden und bleibt kostenlos.\n\nWer sich bedanken moechte, kann mir gerne Post schicken - ueber Gold, Mats oder auch nur ein paar nette Worte freue ich mich immer.\n\n|cff888888Voellig freiwillig - das Addon funktioniert auch ohne komplett.|r",
  ["CHARACTER"]       = "Charakter:",
  ["FILL_NAME"]       = "Namen eintragen",
  ["CLOSE"]           = "Schliessen",
  ["MAILBOX_OPEN"]    = "Briefkasten offen - ein Klick traegt den Namen ein.",
  ["MAILBOX_CLOSED"]  = "Markieren und Strg+C kopiert den Namen. Am Briefkasten wird er per Knopfdruck eingetragen.",
  ["RECIPIENT_SET"]   = "Empfaenger",
  ["RECIPIENT_THANKS"] = "wurde eingetragen. Vielen Dank!",
  ["NEED_MAILBOX"]    = "Dafuer musst du an einem",
  ["MAILBOX"]         = "Briefkasten",
  ["NEED_MAILBOX_2"]  = "stehen. Der Name laesst sich aber auch markieren und mit Strg+C kopieren.",
}

-- BLL.L bleibt immer dieselbe Tabelle. Core.lua und Sources.lua halten
-- sie in einer lokalen Variable; eine neue Tabelle beim Umschalten
-- wuerde dort nie ankommen. Deshalb wird der Inhalt ausgetauscht.
BLL.L = {}
setmetatable(BLL.L, { __index = function(t, k) return k end })

-- code: "deDE", "enUS" oder "auto"/nil (= Clientsprache)
function BLL:SetLanguage(code)
  if code ~= "deDE" and code ~= "enUS" then
    code = (BLL.clientLocale == "deDE") and "deDE" or "enUS"
  end
  BLL.locale = code
  local src = (code == "deDE") and L_deDE or L_enUS
  for k in pairs(BLL.L) do BLL.L[k] = nil end
  for k, v in pairs(src) do BLL.L[k] = v end
end

BLL:SetLanguage(nil)

------------------------------------------------------------------
-- Stat-Keys (interne, sprachunabhaengige Bezeichner)
------------------------------------------------------------------

BLL.STATS = {
  "STR", "AGI", "STA", "INT", "SPI",
  "ARMOR", "DEFENSE",
  "HIT", "CRIT", "SPELLHIT", "SPELLCRIT",
  "AP", "RAP", "SPELLPOWER", "HEALPOWER",
  "SPELLPOWER_ARCANE", "SPELLPOWER_FIRE", "SPELLPOWER_FROST",
  "SPELLPOWER_HOLY", "SPELLPOWER_NATURE", "SPELLPOWER_SHADOW",
  "MP5", "HP5", "HEALTH", "MANA",
  "DODGE", "PARRY", "BLOCK", "BLOCKVALUE",
  "RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW", "RES_ARCANE",
  "WEAPON_MIN", "WEAPON_MAX", "WEAPON_SPEED", "WEAPON_DPS",
}

------------------------------------------------------------------
-- Tooltip-Patterns
--
-- Jeder Eintrag: { statkey, luapattern }
-- Das Pattern muss GENAU EINE Zahl capturen (ausser WEAPON_DMG, s.u.).
-- Reihenfolge zaehlt: das erste passende Pattern pro Zeile gewinnt,
-- danach wird die Zeile nicht weiter geprueft.
------------------------------------------------------------------

local P_enUS = {
  -- Grundwerte
  { "STR",         "^%+(%d+) Strength"          },
  { "AGI",         "^%+(%d+) Agility"           },
  { "STA",         "^%+(%d+) Stamina"           },
  { "INT",         "^%+(%d+) Intellect"         },
  { "SPI",         "^%+(%d+) Spirit"            },

  -- Negative Grundwerte (manche Items haben Mali)
  { "STR",         "^%-(%d+) Strength",         -1 },
  { "AGI",         "^%-(%d+) Agility",          -1 },
  { "STA",         "^%-(%d+) Stamina",          -1 },
  { "INT",         "^%-(%d+) Intellect",        -1 },
  { "SPI",         "^%-(%d+) Spirit",           -1 },

  -- Ruestung / Block
  { "ARMOR",       "^(%d+) Armor"               },
  { "BLOCKVALUE",  "^(%d+) Block"               },

  -- Widerstaende
  { "RES_FIRE",    "^%+(%d+) Fire Resistance"    },
  { "RES_FROST",   "^%+(%d+) Frost Resistance"   },
  { "RES_NATURE",  "^%+(%d+) Nature Resistance"  },
  { "RES_SHADOW",  "^%+(%d+) Shadow Resistance"  },
  { "RES_ARCANE",  "^%+(%d+) Arcane Resistance"  },

  -- Equip-Effekte
  -- RAP VOR AP: "ranged attack power by 24" passt auch auf das AP-Muster,
  -- und der Scanner nimmt den ersten Treffer. In umgekehrter Reihenfolge
  -- zaehlte jede Distanz-Angriffskraft als Nahkampf-AP.
  { "RAP",         "[Rr]anged [Aa]ttack [Pp]ower by (%d+)"             },
  { "AP",          "[Aa]ttack [Pp]ower by (%d+)"                       },
  { "SPELLPOWER",  "damage and healing done by magical spells.- (%d+)" },
  -- Schulgebundener Zauberschaden. Fehlte bisher ganz, die Gewichte
  -- fuer Feuer-, Frost- und Schattenmagier liefen damit ins Leere.
  { "SPELLPOWER_ARCANE", "Arcane spells and effects by up to (%d+)" },
  { "SPELLPOWER_FIRE",   "Fire spells and effects by up to (%d+)"   },
  { "SPELLPOWER_FROST",  "Frost spells and effects by up to (%d+)"  },
  { "SPELLPOWER_HOLY",   "Holy spells and effects by up to (%d+)"   },
  { "SPELLPOWER_NATURE", "Nature spells and effects by up to (%d+)" },
  { "SPELLPOWER_SHADOW", "Shadow spells and effects by up to (%d+)" },
  { "HEALPOWER",   "healing done by spells and effects.- (%d+)"        },
  { "CRIT",        "chance to get a critical strike by (%d+)"          },
  { "SPELLCRIT",   "chance to get a critical strike with spells by (%d+)" },
  { "HIT",         "chance to hit by (%d+)"                            },
  { "SPELLHIT",    "chance to hit with spells by (%d+)"                },
  -- "Increased Defense +7.": das Pluszeichen stand dem Muster im Weg
  { "DEFENSE",     "[Dd]efense.- %+?(%d+)"                             },
  { "DODGE",       "chance to dodge.- (%d+)"                           },
  { "PARRY",       "chance to parry.- (%d+)"                           },
  { "BLOCK",       "chance to block.- (%d+)"                           },
  { "MP5",         "(%d+) mana per 5"                                  },
  { "MP5",         "(%d+) mana every 5"                                },
  { "HP5",         "(%d+) health every 5"                              },

  -- Waffe
  { "WEAPON_SPEED", "^Speed (%d+%.%d+)"     },
  { "WEAPON_DPS",   "%((%d+%.%d+) damage per second%)" },
}

local P_deDE = {
  -- Grundwerte
  { "STR",         "^%+(%d+) St[aä]rke"          },
  { "AGI",         "^%+(%d+) Beweglichkeit"      },
  { "STA",         "^%+(%d+) Ausdauer"           },
  { "INT",         "^%+(%d+) Intelligenz"        },
  { "SPI",         "^%+(%d+) Willenskraft"       },

  { "STR",         "^%-(%d+) St[aä]rke",         -1 },
  { "AGI",         "^%-(%d+) Beweglichkeit",     -1 },
  { "STA",         "^%-(%d+) Ausdauer",          -1 },
  { "INT",         "^%-(%d+) Intelligenz",       -1 },
  { "SPI",         "^%-(%d+) Willenskraft",      -1 },

  -- Ruestung / Block
  { "ARMOR",       "^(%d+) R[uü]stung"           },
  { "BLOCKVALUE",  "^(%d+) Block"                },

  -- Widerstaende
  { "RES_FIRE",    "^%+(%d+) Feuerwiderstand"    },
  { "RES_FROST",   "^%+(%d+) Frostwiderstand"    },
  { "RES_NATURE",  "^%+(%d+) Naturwiderstand"    },
  { "RES_SHADOW",  "^%+(%d+) Schattenwiderstand" },
  { "RES_ARCANE",  "^%+(%d+) Arkanwiderstand"    },

  -- Equip-Effekte ("Anlegen: Erhoeht ...")
  { "AP",          "Angriffskraft um (%d+)"                      },
  { "RAP",         "[Dd]istanzangriffskraft um (%d+)"            },
  { "SPELLPOWER",  "Zauberschaden und Heilung.- (%d+)"           },
  { "SPELLPOWER",  "Zaubermacht um.- (%d+)"                      },
  { "HEALPOWER",   "Heilung von Zaubern.- (%d+)"                 },
  { "CRIT",        "kritischen Treffer um (%d+)"                 },
  { "SPELLCRIT",   "kritischen Zaubertreffer um (%d+)"           },
  { "HIT",         "Chance zu treffen um (%d+)"                  },
  { "SPELLHIT",    "Zauber treffen um (%d+)"                     },
  { "DEFENSE",     "Verteidigung.- %+?(%d+)"                     },
  { "DODGE",       "auszuweichen um (%d+)"                       },
  { "PARRY",       "zu parieren um (%d+)"                        },
  { "BLOCK",       "zu blocken um (%d+)"                         },
  { "MP5",         "(%d+) Mana pro 5"                            },
  { "MP5",         "(%d+) Mana alle 5"                           },
  { "HP5",         "(%d+) Leben alle 5"                          },

  -- Waffe
  { "WEAPON_SPEED", "^Tempo (%d+%.%d+)"    },
  { "WEAPON_DPS",   "%((%d+%.%d+) Schaden pro Sekunde%)" },
}

BLL.PATTERNS = (BLL.clientLocale == "deDE") and P_deDE or P_enUS

-- Schadensbereich wird separat behandelt, weil zwei Zahlen gecaptured werden.
BLL.DMG_PATTERN = (BLL.clientLocale == "deDE")
  and "^(%d+) %- (%d+) Schaden"
  or  "^(%d+) %- (%d+) Damage"

-- Zeilen, die wir gar nicht erst pruefen (spart Durchlaeufe)
BLL.SKIP_PREFIX = (BLL.clientLocale == "deDE")
  and { "Benoetigt Stufe", "Seelengebunden", "Beim Anlegen geb", "Einzigartig" }
  or  { "Requires Level", "Soulbound", "Binds when", "Unique" }
