# Changelog

Alle nennenswerten Änderungen an BananaLootline. Neueste Version oben.

## 0.18.0
- Waffenfertigkeiten werden aus dem Client gelesen. Gelernte Waffen gelten sofort, lernbare erscheinen mit Hinweis „Waffenmeister" (ab Stufe 10, Stangenwaffen ab 20).
- Beidhändigkeit gilt, sobald der Client sie meldet. Vorher: Schurke ab 10, Krieger und Jäger ab 20.
- Schurken bekommen keine Einhandäxte mehr vorgeschlagen.
- Schamanen: keine Faustwaffen. Zweihandäxte und -kolben nur mit dem entsprechenden Talent.
- Fehler behoben: Items über der eigenen Stufe wurden dauerhaft aussortiert und kamen auch nach einem Stufenaufstieg nicht zurück. Die Vorausplanung zeigte dadurch kaum importierte Items. Cache-Version 4.

## 0.17.2
- `ItemData.lua` neu gebaut: Angriffskraft bei 600 Items, Distanz-AP 47, Verteidigung 368, Blockchance 62, Blockwert 39 und Leben/5 s 100 nachgetragen.
- Konverter überspringt bedingte Effekte („when fighting Beasts", „in Cat form only", Procs).
- Setbonus der Cryptstalker-Teile wird nicht mehr pro Teil als Wert gezählt.

## 0.17.1
- Scanner: „ranged attack power" zählte als Nahkampf-AP, „Increased Defense +7" und schulgebundener Zauberschaden wurden nicht erkannt. Behoben, Cache-Version 3.
- Jäger-Gewichte aus Icy Veins: Beweglichkeit 2,5, Krit und Treffer je 32, allgemeine Angriffskraft 1,0 statt 0,5.

## 0.17.0
- Lootline sortiert nach erwartetem Zuwachs pro Besuch (Zuwachs × Dropchance).
- Quests und Händler gelten als sichere Quelle statt als 1 % Dropchance.
- Waffen in der Schildhand verlangen Beidhändigkeit.

## 0.16.3
- Figur, Statfeld und Waffenreihe mittig zwischen Logo und Knopfleiste, Abstand zwischen Füssen und Statfeld.

## 0.16.2
- Figur nach oben verschoben, Statfeld und Waffenreihe direkt darunter.

## 0.16.1
- Statfeld nach Vorbild des Charakterfensters: zwei Kästen mit Auswahl (Grundwerte, Nahkampf, Distanz, Zauber, Verteidigung).

## 0.16.0
- Sprachumschalter DE/EN oben rechts, gespeichert pro Account. Die Tooltip-Auswertung folgt weiter der Clientsprache.
- Dankeschön-Knopf mit Dankesfenster.
- Statfeld unter die Figur verlegt.

## 0.15.0
- Slot-Ansicht neu gegliedert: Bereich „Angelegt" und Bereich „Upgrades" mit Name, Wertänderung, Fundort und Dropchance.
- Anbindung an BananaRepublik Partnerguild 2.1.0: Crafter-Anzahl bei Verzauberungen, Klick öffnet das Rezept.

## 0.14.0
- Umbenennung von OctoLootline in BananaLootline, Befehl `/bll`. Einstellungen werden aus OctoLootline übernommen.

## 0.13.3
- Lootline und Verzauberungen scrollbar, Überschriften einzeilig, Verzauberungen zweizeilig mit lesbaren Wertnamen.

## 0.13.2
- Quests mit Auswahlbelohnung zählen nur das beste Teil.

## 0.13.1
- Ausgangsstand der Übergabe.
