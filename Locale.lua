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
--                 Rüstungsnamen, denn die liefert der Client. Nicht
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

  -- ---- Statusmeldungen: Start und Datenbanken ----
  ["MIGRATED"]        = "Settings carried over from OctoLootline.",
  ["ITEMDB_BROKEN"]   = "ItemDB.lua is missing or was overwritten. The import target is Data/ItemData.lua, not ItemDB.lua!",
  ["ITEMDB_LOADED"]   = "ItemDB: %d items loaded",
  ["SETDB_LOADED"]    = "SetDB: %d sets loaded",
  ["ITEMDB_NONE"]     = "not imported",
  ["YES"]             = "yes",
  ["NO"]              = "no",
  ["ON"]              = "on",
  ["OFF"]             = "off",

  -- ---- Kandidatensuche ----
  ["CAND_NO_PFQUEST"] = "pfQuest missing - no suggestions without the database.",
  ["CAND_SEARCHING"]  = "Searching candidates for level %d-%d ...",
  ["CAND_FOUND"]      = "%d candidates found. Fetching item data ...",
  ["CAND_FOUND_MIX"]  = "%d candidates found (%d with location, %d from the import). Fetching item data ...",
  ["CAND_IMPORT"]     = "Import evaluated: %d items filtered out (wrong slot, wrong armor type or level too high).",
  ["CAND_CACHED"]     = "All item data already cached. Done.",
  ["CAND_REQUEST"]    = "%d unknown items, requesting them (approx. %d seconds). Runs in the background, /bll stop aborts.",
  ["CAND_ROUND2"]     = "%d items still open, second round.",
  ["CAND_DONE"]       = "Done: %d items read%s.",
  ["CAND_MISSING"]    = ", %d not found",
  ["CAND_IDLE"]       = "Nothing is running right now.",
  ["CAND_ABORTED"]    = "Aborted. %d items are saved and will be kept.",

  -- ---- Fortschritt im Fenster ----
  ["PROG_INDEX"]      = "Searching database ...",
  ["PROG_REQUEST"]    = "Requesting items: %d/%d (round %d)",
  ["PROG_WAIT"]       = "Waiting for server replies (%.0fs)",
  ["PROG_COLLECT"]    = "Evaluating replies ...",

  -- ---- Slash-Befehle ----
  ["DEBUG_STATE"]     = "Debug: %s",
  ["USAGE_DUMP"]      = "Usage: /bll dump <itemID>",
  ["USAGE_SRC"]       = "Usage: /bll src <itemID>",
  ["USAGE_SET"]       = "Usage: /bll set <itemID> - shows set and bonuses of the item",
  ["SRC_HEADER"]      = "Sources for item %d:",
  ["WEIGHTS_RESET"]   = "Stat weights reset.",
  ["WEIGHT_SET"]      = "Weight %s = %s",
  ["WEIGHT_REMOVED"]  = "removed",
  ["WEIGHTS_CURRENT"] = "Current weights:",
  ["NO_SETDATA"]      = "No set data loaded.",
  ["ITEM_NO_SET"]     = "Item %d belongs to no set.",
  ["SET_WORN"]        = "%s - %d/%d worn",
  ["SET_ACTIVE"]      = "active",
  ["SET_INACTIVE"]    = "inactive",
  ["USECD_SET"]       = "Assumed cooldown for use effects: %d seconds",
  ["USECD_INFO"]      = "Assumed cooldown: %d seconds. Change with /bll usecd <seconds>. The database provides none, so it is estimated.",
  ["RATE_SET"]        = "Query rate: %d items/second",
  ["RATE_INFO"]       = "Current query rate: %d items/second. Change with /bll rate <1-30>. Higher values put more load on the server.",
  ["CACHE_CLEARED"]   = "Item cache cleared.",
  ["UNUSED_STATE"]    = "Unreachable sources (developer entries, 0%% drop): %s",
  ["UNUSED_SHOWN"]    = "are shown",
  ["UNUSED_HIDDEN"]   = "are hidden",
  ["REOPEN_WINDOW"]   = "Reopen the window for it to take effect.",
  ["USAGE_CAT"]       = "Usage: /bll cat <zone name> <dungeon|raid|world|worldboss|battleground|quest|vendor|object>",
  ["CAT_EXAMPLE"]     = "Example: /bll cat Concavius worldboss",
  ["CAT_OWN"]         = "Your own assignments:",
  ["CAT_UNKNOWN"]     = "Unknown category: %s",
  ["CAT_SET"]         = "%s now counts as %s. Reopen the window.",
  ["AHEAD_SET"]       = "Planning ahead: %d levels. The search now covers level %d-%d. Search again with /bll up.",
  ["AHEAD_INFO"]      = "Planning ahead: %d levels - that is what /bll up searches. Change with /bll ahead <0-60>, 0 shows only what you can wear right now.",
  ["SPEC_NONE"]       = "No spec detected (%d talent points spent, %d needed). Class weights apply.",
  ["SPEC_FOUND"]      = "Spec: %s (%d points total)",
  ["INFO_LINE"]       = "pfQuest: %s | ItemDB: %s | Language: %s",

  -- ---- Hilfe ----
  ["HELP_HEADER"]     = "Commands:",
  ["HELP_MAIN"]       = "open/close the window",
  ["HELP_LANG"]       = "display language",
  ["HELP_UP"]         = "search for upgrades (n = level span, default from /bll ahead)",
  ["HELP_STOP"]       = "abort a running query",
  ["HELP_RATE"]       = "query rate in items/second (default 8)",
  ["HELP_FORGET"]     = "clear the item cache",
  ["HELP_SPEC"]       = "show detected spec",
  ["HELP_AHEAD"]      = "how many levels to plan ahead",
  ["HELP_CAT"]        = "reassign a location",
  ["HELP_UNUSED"]     = "show/hide unreachable sources",
  ["HELP_WEIGHT"]     = "show stat weights",
  ["HELP_WEIGHT_SET"] = "set a weight",
  ["HELP_WEIGHT_RST"] = "reset weights",
  ["HELP_SCAN"]       = "rescan gear and print it",
  ["HELP_DUMP"]       = "show raw tooltip lines of an item",
  ["HELP_TIP"]        = "compare tooltip read methods for one item",
  ["ST_TITLE"]        = "Self check %s",
  ["ST_LANG"]         = "Client language %s, display %s",
  ["ST_PATTERNS"]     = "Tooltip patterns: %s",
  ["ST_PATTERNS_NOTE"] = "(follows the client, not the switch)",
  ["ST_PFQUEST_NOTE"] = "- without it there are no locations",
  ["ST_ITEMDB_COUNT"] = "%d entries",
  ["ST_GEAR"]         = "Gear: %d of %d pieces with readable stats",
  ["ST_NO_STATS"]     = "Not a single stat read. That points to tooltip patterns that do not match the client language.",
  ["ST_WITHOUT"]      = "without stats: %s",
  ["ST_WITHOUT_NOTE"] = "(normal for trinkets and cloaks that have none)",
  ["ST_TOOLTIP"]      = "Tooltip readable: %d lines from \"%s\"",
  ["ST_TOOLTIP_BAD"]  = "Too few lines - the scan tooltip does not return what the game shows.",
  ["ST_BAND"]         = "Search range %d-%d, planning ahead %d",
  ["ST_POOL"]         = "Pool %d",
  ["ST_POOL_LOC"]     = "(%d with location)",
  ["ST_NOSEARCH"]     = "Not searched yet - /bll up",
  ["ST_OK"]           = "Nothing unusual.",
  ["ST_WARN"]         = "%d item(s) to look at - please report the lines marked red.",
  ["USAGE_TIP"]       = "Usage: /bll tip <itemID>",
  ["USAGE_ITEM"]      = "Usage: /bll item <itemID>",
  ["ITEM_NOCACHE"]    = "No cache entry for %d",
  ["ITEM_HINT"]       = "(run /bll up first, then try again)",
  ["ITEM_HEAD"]       = "Cache %d: %s",
  ["ITEM_LEVEL"]      = "Level    ",
  ["ITEM_SLOT"]       = "Slot     ",
  ["ITEM_ORIGIN"]     = "Origin   ",
  ["ITEM_LOCK"]       = "Locked   ",
  ["ITEM_STATS"]      = "Stats    ",
  ["ITEM_IMPORT"]     = "import",
  ["ITEM_SERVER"]     = "server",
  ["ITEM_NONE"]       = "none",
  ["HOOKS_HEAD"]      = "Active addons that may extend tooltips:",
  ["HOOKS_NONE"]      = "none detected",
  ["HOOKS_TOTAL"]     = "%d addons in total",
  ["HELP_ITEM"]       = "show the cached entry of an item",
  ["HELP_HOOKS"]      = "list addons that may extend tooltips",
  ["TIP_COMPARE"]     = "Tooltip comparison for %s",
  ["TIP_HINT"]        = "For comparison: hover the item in game and see which lines are missing here.",
  ["DUMP_LINES"]      = "Tooltip lines:",
  ["DUMP_FOUND"]      = "Parsed: %s",
  ["DUMP_NOTHING"]    = "nothing",
  ["HELP_SELFTEST"]   = "check patterns, languages and data sources",
  ["HELP_SRC"]        = "show sources of an item",
  ["HELP_SET"]        = "set and bonuses of an item",
  ["HELP_USECD"]      = "assumed cooldown for use effects",
  ["HELP_INFO"]       = "status line",
  ["HELP_DEBUG"]      = "toggle debug output",

  -- ---- Herkunft eines Kandidaten ----
  ["NO_LOCATION_YET"] = "no known location",
  ["LOCKED_ITEM"]     = "not freely available",
  ["CAT_DUNGEON"]     = "DUNGEON",
  ["CAT_RAID"]        = "RAID",
  ["CAT_QUEST"]       = "QUEST",
  ["CAT_VENDOR"]      = "VENDOR",
  ["CAT_OBJECT"]      = "OBJECT",
  ["CAT_WORLDBOSS"]   = "WORLD BOSS",
  ["CAT_PVP"]         = "PVP",
  ["CAT_WORLD"]       = "WORLD",
  ["SHOW_VENDORS"]    = "Show vendors",
  ["VENDOR_TOOLTIP"]  = "Vendor goods are a sure thing and would otherwise push every dungeon off the list. Switch them on when you want to go shopping.",
  ["NO_ROUTE"]        = "No route yet. Click \"Find upgrades\" below.",
  ["LOOT_QUESTS"]     = "Quests",
  ["LOCKED_STATE"]    = "Items with a reputation or rank requirement: %s",
  ["LOCKED_SHOWN"]    = "are shown",
  ["LOCKED_HIDDEN"]   = "are hidden",
  ["DUMP_LOCKED"]     = "Access requirement:",
  ["HELP_LOCKED"]     = "show/hide items needing reputation or rank",
  ["UNSCORED_EQUIPPED"] = "effect not scored",
  ["UNSCORED_HINT"]   = "The equipped item has an effect the addon cannot put a number on. Close suggestions are held back - they would be guesses.",
  ["UNSCORED_SHORT"]  = "comparison incomplete",
  ["DUMP_UNSCORED"]   = "Not scored:",
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

  -- ---- Statusmeldungen: Start und Datenbanken ----
  ["MIGRATED"]        = "Einstellungen aus OctoLootline uebernommen.",
  ["ITEMDB_BROKEN"]   = "ItemDB.lua fehlt oder wurde ueberschrieben. Importziel ist Data/ItemData.lua, nicht ItemDB.lua!",
  ["ITEMDB_LOADED"]   = "ItemDB: %d Items geladen",
  ["SETDB_LOADED"]    = "SetDB: %d Sets geladen",
  ["ITEMDB_NONE"]     = "nicht importiert",
  ["YES"]             = "ja",
  ["NO"]              = "nein",
  ["ON"]              = "an",
  ["OFF"]             = "aus",

  -- ---- Kandidatensuche ----
  ["CAND_NO_PFQUEST"] = "pfQuest fehlt - ohne die Datenbank keine Vorschlaege.",
  ["CAND_SEARCHING"]  = "Suche Kandidaten fuer Stufe %d-%d ...",
  ["CAND_FOUND"]      = "%d Kandidaten gefunden. Hole Itemdaten ...",
  ["CAND_FOUND_MIX"]  = "%d Kandidaten gefunden (%d mit Fundort, %d aus dem Import). Hole Itemdaten ...",
  ["CAND_IMPORT"]     = "Import ausgewertet: %d Items aussortiert (falscher Slot, falsche Ruestungsart oder Stufe zu hoch).",
  ["CAND_CACHED"]     = "Alle Itemdaten bereits im Cache. Fertig.",
  ["CAND_REQUEST"]    = "%d unbekannte Items, frage sie an (ca. %d Sekunden). Laeuft im Hintergrund, /bll stop bricht ab.",
  ["CAND_ROUND2"]     = "%d Items noch offen, zweite Runde.",
  ["CAND_DONE"]       = "Fertig: %d Items eingelesen%s.",
  ["CAND_MISSING"]    = ", %d nicht auffindbar",
  ["CAND_IDLE"]       = "Es laeuft gerade nichts.",
  ["CAND_ABORTED"]    = "Abgebrochen. %d Items sind gespeichert und bleiben erhalten.",

  -- ---- Fortschritt im Fenster ----
  ["PROG_INDEX"]      = "Durchsuche Datenbank ...",
  ["PROG_REQUEST"]    = "Frage Items an: %d/%d (Runde %d)",
  ["PROG_WAIT"]       = "Warte auf Serverantworten (%.0fs)",
  ["PROG_COLLECT"]    = "Werte Antworten aus ...",

  -- ---- Slash-Befehle ----
  ["DEBUG_STATE"]     = "Debug: %s",
  ["USAGE_DUMP"]      = "Nutzung: /bll dump <itemID>",
  ["USAGE_SRC"]       = "Nutzung: /bll src <itemID>",
  ["USAGE_SET"]       = "Nutzung: /bll set <itemID> - zeigt Set und Boni des Items",
  ["SRC_HEADER"]      = "Quellen fuer Item %d:",
  ["WEIGHTS_RESET"]   = "Statgewichte zurueckgesetzt.",
  ["WEIGHT_SET"]      = "Gewicht %s = %s",
  ["WEIGHT_REMOVED"]  = "entfernt",
  ["WEIGHTS_CURRENT"] = "Aktuelle Gewichte:",
  ["NO_SETDATA"]      = "Keine Setdaten geladen.",
  ["ITEM_NO_SET"]     = "Item %d gehoert zu keinem Set.",
  ["SET_WORN"]        = "%s - %d/%d getragen",
  ["SET_ACTIVE"]      = "aktiv",
  ["SET_INACTIVE"]    = "inaktiv",
  ["USECD_SET"]       = "Angenommene Abklingzeit fuer Use-Effekte: %d Sekunden",
  ["USECD_INFO"]      = "Angenommene Abklingzeit: %d Sekunden. Aendern mit /bll usecd <sekunden>. Die Datenbank liefert keine, deshalb wird geschaetzt.",
  ["RATE_SET"]        = "Abfragerate: %d Items/Sekunde",
  ["RATE_INFO"]       = "Aktuelle Abfragerate: %d Items/Sekunde. Aendern mit /bll rate <1-30>. Hoehere Werte belasten den Server staerker.",
  ["CACHE_CLEARED"]   = "Itemcache geleert.",
  ["UNUSED_STATE"]    = "Unerreichbare Quellen (Entwicklereintraege, 0%% Drop): %s",
  ["UNUSED_SHOWN"]    = "werden angezeigt",
  ["UNUSED_HIDDEN"]   = "werden ausgeblendet",
  ["REOPEN_WINDOW"]   = "Fenster neu oeffnen, damit es wirkt.",
  ["USAGE_CAT"]       = "Nutzung: /bll cat <Zonenname> <dungeon|raid|welt|weltboss|schlachtfeld|quest|haendler|objekt>",
  ["CAT_EXAMPLE"]     = "Beispiel: /bll cat Concavius weltboss",
  ["CAT_OWN"]         = "Eigene Zuordnungen:",
  ["CAT_UNKNOWN"]     = "Unbekannte Kategorie: %s",
  ["CAT_SET"]         = "%s gilt jetzt als %s. Fenster neu oeffnen.",
  ["AHEAD_SET"]       = "Vorausplanung: %d Stufen. Die Suche umfasst jetzt Stufe %d-%d. Neu suchen mit /bll up.",
  ["AHEAD_INFO"]      = "Vorausplanung: %d Stufen - so weit sucht /bll up. Aendern mit /bll ahead <0-60>, 0 zeigt nur sofort Tragbares.",
  ["SPEC_NONE"]       = "Keine Spezialisierung erkannt (%d Talentpunkte vergeben, noetig sind %d). Es gelten die Klassenwerte.",
  ["SPEC_FOUND"]      = "Spezialisierung: %s (%d Punkte gesamt)",
  ["INFO_LINE"]       = "pfQuest: %s | ItemDB: %s | Sprache: %s",

  -- ---- Hilfe ----
  ["HELP_HEADER"]     = "Befehle:",
  ["HELP_MAIN"]       = "Fenster oeffnen/schliessen",
  ["HELP_LANG"]       = "Anzeigesprache",
  ["HELP_UP"]         = "Upgrades suchen (n = Stufenspanne, Standard aus /bll ahead)",
  ["HELP_STOP"]       = "laufende Abfrage abbrechen",
  ["HELP_RATE"]       = "Abfragerate in Items/Sekunde (Standard 8)",
  ["HELP_FORGET"]     = "Itemcache leeren",
  ["HELP_SPEC"]       = "erkannte Spezialisierung zeigen",
  ["HELP_AHEAD"]      = "wie viele Stufen vorausgeplant wird",
  ["HELP_CAT"]        = "Fundort umsortieren",
  ["HELP_UNUSED"]     = "unerreichbare Quellen ein/ausblenden",
  ["HELP_WEIGHT"]     = "Statgewichte zeigen",
  ["HELP_WEIGHT_SET"] = "Gewicht setzen",
  ["HELP_WEIGHT_RST"] = "Gewichte zuruecksetzen",
  ["HELP_SCAN"]       = "Ausruestung neu scannen und ausgeben",
  ["HELP_DUMP"]       = "rohe Tooltipzeilen eines Items zeigen",
  ["HELP_TIP"]        = "Leseverfahren fuer den Tooltip vergleichen",
  ["ST_TITLE"]        = "Selbstpruefung %s",
  ["ST_LANG"]         = "Clientsprache %s, Anzeige %s",
  ["ST_PATTERNS"]     = "Tooltipmuster: %s",
  ["ST_PATTERNS_NOTE"] = "(folgt dem Client, nicht dem Schalter)",
  ["ST_PFQUEST_NOTE"] = "- ohne sie gibt es keine Fundorte",
  ["ST_ITEMDB_COUNT"] = "%d Eintraege",
  ["ST_GEAR"]         = "Ausruestung: %d von %d Teilen mit erkannten Werten",
  ["ST_NO_STATS"]     = "Kein einziger Wert erkannt. Das deutet darauf hin, dass die Tooltipmuster nicht zur Clientsprache passen.",
  ["ST_WITHOUT"]      = "ohne Werte: %s",
  ["ST_WITHOUT_NOTE"] = "(bei Schmuck und Umhaengen ohne Werte ist das normal)",
  ["ST_TOOLTIP"]      = "Tooltip lesbar: %d Zeilen aus \"%s\"",
  ["ST_TOOLTIP_BAD"]  = "Zu wenige Zeilen - der Scan-Tooltip liefert nicht, was im Spiel steht.",
  ["ST_BAND"]         = "Suchband %d-%d, Vorausplanung %d",
  ["ST_POOL"]         = "Pool %d",
  ["ST_POOL_LOC"]     = "(%d mit Fundort)",
  ["ST_NOSEARCH"]     = "Noch nicht gesucht - /bll up",
  ["ST_OK"]           = "Keine Auffaelligkeiten.",
  ["ST_WARN"]         = "%d Auffaelligkeit(en) - bitte die rot markierten Zeilen melden.",
  ["USAGE_TIP"]       = "Nutzung: /bll tip <itemID>",
  ["USAGE_ITEM"]      = "Nutzung: /bll item <itemID>",
  ["ITEM_NOCACHE"]    = "Kein Cache-Eintrag fuer %d",
  ["ITEM_HINT"]       = "(erst /bll up, dann erneut)",
  ["ITEM_HEAD"]       = "Cache %d: %s",
  ["ITEM_LEVEL"]      = "Stufe    ",
  ["ITEM_SLOT"]       = "Slot     ",
  ["ITEM_ORIGIN"]     = "Herkunft ",
  ["ITEM_LOCK"]       = "Sperre   ",
  ["ITEM_STATS"]      = "Werte    ",
  ["ITEM_IMPORT"]     = "Import",
  ["ITEM_SERVER"]     = "Server",
  ["ITEM_NONE"]       = "keine",
  ["HOOKS_HEAD"]      = "Aktive Addons, die Tooltips erweitern koennten:",
  ["HOOKS_NONE"]      = "keine erkannt",
  ["HOOKS_TOTAL"]     = "%d Addons insgesamt",
  ["HELP_ITEM"]       = "Cache-Eintrag eines Gegenstands zeigen",
  ["HELP_HOOKS"]      = "Addons auflisten, die Tooltips erweitern",
  ["TIP_COMPARE"]     = "Tooltip-Vergleich fuer %s",
  ["TIP_HINT"]        = "Zum Vergleich: im Spiel ueber den Gegenstand fahren und schauen, welche Zeilen dort fehlen.",
  ["DUMP_LINES"]      = "Tooltipzeilen:",
  ["DUMP_FOUND"]      = "Erkannt: %s",
  ["DUMP_NOTHING"]    = "nichts",
  ["HELP_SELFTEST"]   = "Muster, Sprachen und Datenquellen pruefen",
  ["HELP_SRC"]        = "Quellen eines Items zeigen",
  ["HELP_SET"]        = "Set und Boni eines Items",
  ["HELP_USECD"]      = "angenommene Abklingzeit fuer Use-Effekte",
  ["HELP_INFO"]       = "Statuszeile",
  ["HELP_DEBUG"]      = "Debugausgabe an/aus",

  -- ---- Herkunft eines Kandidaten ----
  ["NO_LOCATION_YET"] = "kein bekannter Fundort",
  ["LOCKED_ITEM"]     = "nicht frei erhaeltlich",
  ["CAT_DUNGEON"]     = "DUNGEON",
  ["CAT_RAID"]        = "RAID",
  ["CAT_QUEST"]       = "QUEST",
  ["CAT_VENDOR"]      = "HAENDLER",
  ["CAT_OBJECT"]      = "OBJEKT",
  ["CAT_WORLDBOSS"]   = "WELTBOSS",
  ["CAT_PVP"]         = "PVP",
  ["CAT_WORLD"]       = "WELT",
  ["SHOW_VENDORS"]    = "Haendler zeigen",
  ["VENDOR_TOOLTIP"]  = "Haendlerware ist sicher zu bekommen und draengt sonst jeden Dungeon aus der Liste. Einschalten, wenn du einkaufen gehen willst.",
  ["NO_ROUTE"]        = "Noch kein Wegplan. Unten auf \"Upgrades suchen\" klicken.",
  ["LOOT_QUESTS"]     = "Quests",
  ["LOCKED_STATE"]    = "Gegenstaende mit Ruf- oder Rangbedingung: %s",
  ["LOCKED_SHOWN"]    = "werden angezeigt",
  ["LOCKED_HIDDEN"]   = "werden ausgeblendet",
  ["DUMP_LOCKED"]     = "Zugangsbedingung:",
  ["HELP_LOCKED"]     = "Teile mit Ruf- oder Rangbedingung ein-/ausblenden",
  ["UNSCORED_EQUIPPED"] = "Effekt nicht bewertet",
  ["UNSCORED_HINT"]   = "Das angelegte Teil hat einen Effekt, den das Addon nicht in Punkte fassen kann. Knappe Vorschlaege bleiben deshalb aussen vor - sie waeren geraten.",
  ["UNSCORED_SHORT"]  = "Vergleich unvollstaendig",
  ["DUMP_UNSCORED"]   = "Nicht bewertet:",
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
  { "STR",         "^%+(%d+) St.-rke"          },
  { "AGI",         "^%+(%d+) Beweglichkeit"      },
  { "STA",         "^%+(%d+) Ausdauer"           },
  { "INT",         "^%+(%d+) Intelligenz"        },
  { "SPI",         "^%+(%d+) Willenskraft"       },

  { "STR",         "^%-(%d+) St.-rke",         -1 },
  { "AGI",         "^%-(%d+) Beweglichkeit",     -1 },
  { "STA",         "^%-(%d+) Ausdauer",          -1 },
  { "INT",         "^%-(%d+) Intelligenz",       -1 },
  { "SPI",         "^%-(%d+) Willenskraft",      -1 },

  -- Ruestung / Block
  { "ARMOR",       "^(%d+) R.-stung"           },
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

------------------------------------------------------------------
-- Hinweise auf Effekte, die kein Muster in Werte uebersetzt
--
-- Proc-Effekte sind in Vanilla haeufig und tauchen im Tooltip als Text
-- auf, nicht als Wert: "Chance bei Treffer", "2% Chance, einen
-- zusaetzlichen Angriff auszufuehren". Ein Item kann dadurch stark sein,
-- ohne dass der Scanner einen einzigen Punkt findet.
--
-- Diese Muster markieren solche Zeilen, damit der Vergleich weiss, dass
-- er unvollstaendig ist. Sie greifen nur bei Zeilen, auf die vorher KEIN
-- Wertmuster gepasst hat - "erhoeht Eure Chance auszuweichen um 1%" ist
-- also nicht betroffen, das ist laengst als DODGE erfasst.
--
-- Bewusst kurz: jedes Muster, das zu breit trifft, unterdrueckt echte
-- Vorschlaege. Verglichen wird kleingeschrieben.
------------------------------------------------------------------


------------------------------------------------------------------
-- Zugangsbedingungen: Ruf und PvP-Rang
--
-- Ein Bogen beim PvP-Quartiermeister kann Stufe 18 verlangen und
-- zusaetzlich einen Ehrenrang. Die Stufe kennt das Addon, den Rang
-- nicht - solche Teile standen deshalb ganz oben in der Lootline,
-- obwohl ein frischer Charakter nie an sie herankommt.
--
-- Erkannt wird die Bedingungszeile des Tooltips. Reine Stufenzeilen
-- ("Requires Level 18") filtert SKIP_PREFIX schon vorher heraus, hier
-- kommen also nur die anderen an: Ruf, Rang, Beruf.
--
-- Das Muster umgeht den Umlaut in "Benoetigt" absichtlich mit ".-",
-- damit es unabhaengig von der Zeichenkodierung des Clients greift.
------------------------------------------------------------------

BLL.RESTRICT_PREFIX = (BLL.clientLocale == "deDE")
  and { "^Ben.-tigt", "^Erfordert" }
  or  { "^Requires" }

-- Zusaetzliches Netz fuer Zeilen, die nicht mit dem Bedingungswort
-- beginnen, aber eindeutig eine Ruf- oder Rangstufe nennen.
BLL.RESTRICT_WORDS = (BLL.clientLocale == "deDE")
  and { "wohlwollend", "respektvoll", "ehrf", "freundlich", "revered",
        "ehrenrang", "rang " }
  or  { "friendly", "honored", "revered", "exalted", "rank " }

BLL.EFFECT_HINTS = (BLL.clientLocale == "deDE")
  and { "chance", "benutzen:", "wenn getroffen", "bei treffer" }
  or  { "chance", "use:", "when struck", "on hit" }


-- Schadensbereich wird separat behandelt, weil zwei Zahlen gecaptured werden.
BLL.DMG_PATTERN = (BLL.clientLocale == "deDE")
  and "^(%d+) %- (%d+) Schaden"
  or  "^(%d+) %- (%d+) Damage"

-- Zeilen, die wir gar nicht erst pruefen (spart Durchlaeufe)
BLL.SKIP_PREFIX = (BLL.clientLocale == "deDE")
  and { "Benoetigt Stufe", "Seelengebunden", "Beim Anlegen geb", "Einzigartig" }
  or  { "Requires Level", "Soulbound", "Binds when", "Unique" }

------------------------------------------------------------------
-- Dropchancen lesbar machen.
--
-- Die Zahlen aus dem Export reichen weit unter ein Prozent: "Feet of
-- the Lynx" faellt mit 0,0045 Prozent. Mit "%.1f%%" stand ueberall
-- "0.0%" - was aussieht wie "faellt nie" und trotzdem der haeufigste
-- Wert im Bestand ist. Der Median aller Dropzeilen liegt bei 0,0085
-- Prozent, die kleinste belegte Stelle bei 0,0001. Deshalb wachsen die
-- Nachkommastellen mit der Kleinheit des Werts, statt ihn wegzurunden.
function BLL:FormatChance(chance)
  local c = tonumber(chance)
  if not c or c <= 0 then return nil end
  if c >= 10     then return string.format("%.0f%%", c) end
  if c >= 1      then return string.format("%.1f%%", c) end
  if c >= 0.1    then return string.format("%.2f%%", c) end
  if c >= 0.01   then return string.format("%.3f%%", c) end
  if c >= 0.0001 then return string.format("%.4f%%", c) end
  return "<0.0001%"
end

------------------------------------------------------------------
-- Elitekennung eines Gegners.
--
-- Der Export fuehrt sie als Zahl. Fuer den Wegplan zaehlt vor allem der
-- Unterschied zwischen "kann ich allein" und "brauche ich eine Gruppe";
-- Selten und Boss stehen daneben, weil ein seltener Gegner nicht immer
-- da ist und ein Boss eine Instanz bedeutet.
--   1 Elite, 2 Selten-Elite, 3 Boss, 4 Selten
------------------------------------------------------------------

function BLL:EliteLabel(rank)
  local de = (self.locale == "deDE")
  if rank == 1 then return de and "Elite"  or "Elite"  end
  if rank == 2 then return de and "Selten-Elite" or "Rare Elite" end
  if rank == 3 then return de and "Boss"   or "Boss"   end
  if rank == 4 then return de and "Selten" or "Rare"   end
  return nil
end
