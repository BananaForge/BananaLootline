# Changelog

Alle nennenswerten Änderungen an BananaLootline. Neueste Version oben.

## 0.19.3
- Die Prüfung auf Ruf- und Rangbedingungen greift jetzt dort, wo sie etwas bewirkt. Sie liest den Tooltip, und den sah nur, was das Addon beim Server anfragen musste — bei einem Stufe-15-Jäger 22 von 955 verwertbaren Kandidaten, also zwei Prozent. Geprüft wird jetzt jeder Gegenstand, der tatsächlich in der Liste landet; kennt der Client ihn, kostet das keine einzige Serveranfrage.
- Ein gefiltertes Teil lässt die Liste nicht mehr schrumpfen: die nachfolgenden rücken auf.
- Drei Diagnosewerkzeuge unter `tools/`: `diag_full.lua` prüft alle Ausrüstungsplätze gegen die Itemdatenbank, `diag_gaps.lua` misst Lücken in der Datenlage, `diag_perf.lua` die Laufzeit. Aufruf vom Addonstamm, etwa `lua5.1 tools/diag_full.lua 60 WARRIOR`.
- Geprüft über 24 Kombinationen aus Stufe und Klasse: keine Vorschläge über der Stufengrenze, keine fremde Klasse, kein falscher Ausrüstungsplatz.

## 0.19.2
- Die Anforderungsstufe wird zwischen Itemcache und Itemdatenbank abgeglichen; bei Uneinigkeit gilt die höhere Angabe. „Outrider's Bow" erschien bei einem Stufe-15-Jäger mit dem Vermerk „ab 18", obwohl Tooltip und Import übereinstimmend Stufe 60 nennen — im gespeicherten Cache stand noch ein alter Wert, und Cache-Einträge werden nicht neu bewertet, solange ihre Version passt.
- Gegenstände mit Ruf- oder Rangbedingung erscheinen nicht mehr in den Vorschlägen. Beim PvP-Quartiermeister in den Barrens steht ein Bogen ab Stufe 18 — zu holen ist er aber erst mit dem passenden Ehrenrang. Das Addon kannte nur die Stufenangabe und setzte solche Teile ganz nach oben. Die Bedingung wird jetzt beim Auslesen des Tooltips erkannt und dauerhaft vermerkt, weil der Client den Tooltip später wieder vergisst.
- Neuer Befehl `/bll locked` blendet diese Teile wieder ein.
- `/bll dump <id>` weist eine erkannte Zugangsbedingung getrennt aus.
- Cache-Version 5: ältere Einträge kennen das neue Feld nicht und werden einmalig neu eingelesen.

## 0.19.1
- Fehler aus 0.19.0 behoben: Ein Stufe-15-Jäger bekam Gegenstände mit Itemlevel 65 aus Tanaris vorgeschlagen, und die Kandidatenzahl stieg von rund 600 auf 4118. Ursache war der Importfilter — 2275 der 11349 Einträge führen keine Anforderungsstufe, und die Prüfung „Anforderungsstufe kleiner als Obergrenze" ist bei einer 0 immer wahr. Fehlt die Angabe, wird sie jetzt über das Itemlevel geschätzt; der Abstand beträgt im Datenbestand im Median 5 Stufen.
- Der Rückblick nach unten wächst mit der Stufe statt fest bei 10 zu liegen: 3 Stufen auf Stufe 15, 10 auf Stufe 60. Der feste Wert war für das Stufenende gedacht und riss auf niedrigen Stufen das Suchband unnötig weit auf — Stufe 15 suchte 5 bis 21 ab statt 12 bis 21.
- Neuer Regressionstest `test_poolbounds.lua` mit genau den beiden Gegenständen aus dem Fehlerbericht.

## 0.19.0
- Effekte ohne Zahl werden beim Vergleich berücksichtigt. Der Scanner liest Werte aus dem Tooltip; ein Proc-Effekt steht dort als Satz und zählte deshalb null Punkte. Die Hand der Gerechtigkeit verlor damit gegen jedes beliebige Teil mit vier Ausdauer. Trägt der Spieler ein Teil mit unbeziffertem Effekt, muss ein Kandidat jetzt deutlich vorne liegen statt knapp; solche Vorschläge werden als unvollständiger Vergleich gekennzeichnet. Das angelegte Teil bekommt den Vermerk „Effekt nicht bewertet".
- Items ohne Kampfeffekt sind davon nicht betroffen. Die Anstecknadel der Argentumdämmerung bleibt bei null Punkten, jedes Teil mit einem einzigen Wert schlägt sie weiterhin.
- `/bll dump <id>` listet die Zeilen auf, die nach einem Effekt aussehen, aus denen aber kein Wert kam — damit lassen sich Fehlalarme der Erkennung melden.
- Statusmeldungen folgen jetzt dem Schalter DE/EN. Rund 60 Texte in Chat, Hilfe und Fortschrittsanzeige standen fest im Code und blieben deutsch, auch wenn die Anzeigesprache auf Englisch stand. Die Tooltip-Auswertung folgt weiterhin der Clientsprache.
- `/bll cat` versteht die Kategorien jetzt auch auf Englisch: `world`, `worldboss`, `battleground`, `vendor`, `object`.
- `/bll ahead` steuert endlich die Suche. Bisher wirkte die Einstellung nur als Filter auf bereits gefundene Items; `/bll up` suchte immer mit der festen Spanne 6.
- Das Suchband reicht 10 Stufen nach unten statt der halben Vorausplanung. Ein Charakter auf Stufe 60 suchte damit nur 57 bis 63 ab — ein Streifen, in dem am Stufenende fast nichts liegt. Jetzt sind es 50 bis 63.
- Die Quellenstufe eines Items ist nicht mehr das Minimum über alle Quellen, sondern die niedrigste Quelle innerhalb des Suchbands. Ein Raidteil, das irgendwo auch ein Stufe-40-Mob trägt, fiel vorher aus jedem Band eines Stufe-60-Charakters heraus.
- Der Kandidatenpool zieht zusätzlich Items aus der importierten ItemDB. pfQuest liefert nur Items mit brauchbarer Stufenangabe an der Quelle; am Stufenende blieb davon zu wenig übrig. Items aus dem Import haben keinen Fundort, werden als solche gekennzeichnet und hinter den verorteten einsortiert. Im Wegplan erscheinen sie nicht — dort gehört nur hin, wohin man auch gehen kann.
- Fehler behoben: `Progress()` war zweimal definiert. Die zweite Fassung überschrieb die erste und kannte nur einen Zustand, den es nicht gibt — während Abfrage und Auswertung zeigte das Fenster deshalb gar keinen Fortschritt.
- Fehler behoben: Die Meldung zu `/bll unused` gab `0%%` statt `0%` aus.
- Vier neue Testdateien: `test_messages.lua` prüft Schlüsselgleichheit, Formatplatzhalter und dass keine Meldung mehr fest verdrahtet ist, `test_searchband.lua` deckt Stufenband, Quellenstufe und Poolaufbau ab, `test_trinket.lua` den Vergleich bei Schmuckstücken ohne Werte, `test_unscored.lua` die Effekterkennung samt Gegenproben gegen Fehlalarme.

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
