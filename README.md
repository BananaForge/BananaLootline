# BananaLootline

**Gear- und Lootline-Planer für OctoWoW (Client 1.12).**
Das Addon beantwortet zwei Fragen direkt im Spiel: *Was ist für diesen Slot besser?* und vor allem *Wohin soll ich gehen?*

Teil der Gilden-Marke **BananaForge**. Schwesteraddon: [BananaRepublik Partnerguild](#bananarepublik-partnerguild) für Berufe und Rezepte.

![Version](https://img.shields.io/badge/version-0.18.0-yellow) ![Client](https://img.shields.io/badge/client-1.12-blue) ![Lua](https://img.shields.io/badge/lua-5.0-lightgrey)

---

## Funktionen

**Lootline** (Standardansicht)
Alle Verbesserungen für deinen Charakter, gebündelt nach Fundort. Die Orte sind nach dem erwarteten Zuwachs pro Besuch sortiert: Zuwachs mal Dropchance. Ein Ort mit einem 75-%-Drop steht damit vor einem Ort mit drei 1-%-Drops. Quests und Händler zählen als sichere Quelle. Jeder Ort zeigt Kategorie, Stufenbereich und die Zahl der Upgrades.

**Pro Item**
Klick auf einen Slot zeigt oben dein angelegtes Teil und darunter bis zu sechs Upgrades. Jedes Upgrade zeigt Wertänderung, Fundort und Dropchance.

**Verzauberung**
Die besten Verzauberungen je Slot. Mit BananaRepublik Partnerguild siehst du dazu, wer in Gilde und Partnergilde sie beherrscht. Ein Klick öffnet das Rezept dort.

**Statfeld wie im Charakterfenster**
Zwei Kästen mit Auswahl: Grundwerte, Nahkampf, Distanz, Zauber, Verteidigung. Die Auswahl wird pro Charakter gespeichert.

**Bewertung**
- Statgewichte pro Klasse, bei ausreichend Talentpunkten pro Spezialisierung
- Setboni: Nur neu erreichte Schwellen zählen
- Use-Effekte anteilig nach Dauer und Abklingzeit
- Zweihänder gegen den Verlust der Schildhand verrechnet
- Rüstungsart, Klassenbeschränkung und Fraktion werden geprüft
- **Waffenfertigkeiten aus dem Client:** Gelernte Waffen gelten sofort. Lernbare Waffen erscheinen mit Hinweis „Waffenmeister". Beidhändigkeit zählt erst, wenn sie gelernt ist (Schurke ab 10, Krieger und Jäger ab 20).
- Vorausplanung: Teile bis zu 6 Stufen über dir erscheinen mit Vermerk „ab 18"

**Sonstiges**
- Anzeige auf Deutsch oder Englisch, umschaltbar oben rechts (DE/EN)
- Scrollbare Listen, Tooltips, Shift-Klick verlinkt Items im Chat

---

## Voraussetzungen

| | |
|---|---|
| Client | World of Warcraft 1.12 (OctoWoW) |
| Empfohlen | [pfQuest](https://github.com/shagu/pfQuest) mit dem Datenpaket pfQuest-octo. Ohne pfQuest fehlen Fundorte und Dropchancen, die Lootline bleibt leer. |
| Optional | BananaRepublik Partnerguild ab 2.1.0 für die Crafter-Anzeige bei Verzauberungen |

---

## Installation

1. Unter **Releases** die Datei `BananaLootline-x.y.z.zip` herunterladen.
2. Entpacken nach `World of Warcraft/Interface/AddOns/`.
3. Der Ordner muss exakt **`BananaLootline`** heissen.
4. Spiel starten, im Chat `/bll` eingeben.

> **Achtung:** GitHubs grüner Knopf „Code → Download ZIP" liefert einen Ordner namens `BananaLootline-main`. Damit findet der Client weder das Addon noch das Logo. Nimm das ZIP aus den Releases oder benenne den Ordner um.

### Umstieg von OctoLootline

Bis Version 0.13.3 hiess das Addon OctoLootline (`/oll`).

1. Spiel beenden.
2. Ordner `Interface/AddOns/OctoLootline` löschen. Bleibt er liegen, laufen beide Addons parallel.
3. Einstellungen mitnehmen (optional): In `WTF/Account/<Konto>/SavedVariables/` und in `WTF/Account/<Konto>/<Server>/<Charakter>/SavedVariables/` die Datei `OctoLootline.lua` in `BananaLootline.lua` umbenennen. Beim ersten Start übernimmt das Addon die Werte und meldet das im Chat.

---

## Erste Schritte

1. `/bll` öffnet das Fenster.
2. Unten auf **Upgrades suchen** klicken. Der erste Lauf fragt fehlende Itemdaten beim Server an und läuft im Hintergrund.
3. In der **Lootline** siehst du danach, wohin es sich lohnt.

---

## Befehle

| Befehl | Wirkung |
|---|---|
| `/bll` | Fenster öffnen/schliessen |
| `/bll up [n]` | Upgrades suchen, n = Stufenspanne (Standard 6) |
| `/bll stop` | laufende Abfrage abbrechen |
| `/bll lang de\|en\|auto` | Anzeigesprache |
| `/bll ahead <n>` | Stufen Vorausplanung |
| `/bll spec` | erkannte Spezialisierung zeigen |
| `/bll weight` | Statgewichte zeigen |
| `/bll weight STR 3` | Gewicht setzen |
| `/bll weight reset` | Gewichte zurücksetzen |
| `/bll cat <Zone> <Kategorie>` | Fundort umsortieren |
| `/bll unused` | unerreichbare Quellen ein-/ausblenden |
| `/bll set <id>` | Set und Boni eines Items |
| `/bll src <id>` | Quellen eines Items |
| `/bll usecd <s>` | angenommene Abklingzeit für Use-Effekte |
| `/bll rate <n>` | Abfragerate in Items pro Sekunde (Standard 8) |
| `/bll forget` | Itemcache leeren |
| `/bll scan` | Ausrüstung neu scannen und ausgeben |
| `/bll dump <id>` | rohe Tooltipzeilen eines Items |
| `/bll info` | Statuszeile |
| `/bll debug` | Debugausgabe an/aus |

---

## Bekannte Grenzen

- **Statgewichte:** Die Jäger-Gewichte sind belegt (Icy Veins, Bezug Stufe 60). Die übrigen Klassen nutzen Schätzwerte. Alle Werte gelten für Stufe 60 und passen sich nicht an niedrigere Stufen an.
- **Dropchance pro Einheit:** Droppt ein Teil von vielen Mobs mit je 1 %, unterschätzt die Lootline den Ort.
- **Bedingte Boni zählen nicht:** „+72 Attack Power when fighting Beasts" und Angriffskraft in Druidengestalt fliessen nicht in die Wertung ein.
- **Use-Effekte:** Die Abklingzeit fehlt in den Daten, das Addon rechnet mit angenommenen 180 Sekunden.
- **Frisch gelernte Waffenfertigkeit** startet bei 1. Das Addon bewertet die Waffe trotzdem mit vollem Wert.
- **Deutscher Client:** Die deutschen Namen der Waffenfertigkeiten sind nicht im Spiel geprüft. Erkennt das Addon keine, fällt es auf die Klassentabelle zurück.

---

## BananaRepublik Partnerguild

Ist das Partner-Addon ab Version 2.1.0 installiert, zeigt die Verzauberungsansicht hinter jeder Verzauberung, wie viele Crafter sie beherrschen und wie viele davon online sind. Ein Klick öffnet das Rezept mit allen Craftern aus Gilde und Partnergilde. Die Zuordnung läuft über den Rezeptnamen. Beide Addons müssen dieselbe Clientsprache sehen.

---

## Mitentwickeln

Aufbau, technische Fallen des 1.12-Clients, Datenimport und Tests: siehe [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md).

Tests lokal ausführen:

```bash
bash tools/run_tests.sh
```

Ein Release entsteht automatisch, sobald ein Tag wie `v0.18.0` gepusht wird. Die Version im Tag muss mit `## Version:` in `BananaLootline.toc` übereinstimmen.

---

## Credits

- **Quellendaten:** [pfQuest](https://github.com/shagu/pfQuest) von Eric Mauser (Shagu) und Mitwirkenden, Datenpaket pfQuest-octo von Roby_Brok. BananaLootline liest diese Daten zur Laufzeit und verteilt sie nicht weiter.
- **Itemdaten:** OctoWoW-Datenbank (octowow.st/db)
- **Statgewichte Jäger:** Icy Veins, „Classic Hunter DPS Stat Priority"

## Lizenz

[MIT](LICENSE)
