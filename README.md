<p align="center"><img src="assets/logo/rosenweg-wetter-512.png" width="96" alt="Logo"></p>
<h1 align="center">Rosenweg Wetter</h1>
<p align="center">Wetterstation am Rosenweg 9: aktuelle Werte live, Verlauf bis 7 Tage, Sonne und Mond.</p>
<p align="center"><a href="docs/anleitung.md">Anleitung</a> · <a href="https://www.rosenweg4303.ch/apps">Herunterladen</a></p>

Angelegt mit `werkzeug/neue-app.sh` aus der App-Vorlage von
[rosenweg-basis](https://github.com/Rosenweg/rosenweg-basis). Anmeldung, API,
Gerüst, Updater und Logo kommen aus der Basis; hier steht nur, was diese App
eigen macht.

## Läuft auf

| Plattform | Datei | Grenzen |
|---|---|---|
| Linux (Debian 13, Stationen und eigene Rechner) | `rosenweg-wetter_<version>_amd64.deb` | Stationen bekommen das Paket vom PXE-Server (os-stationen), dort ist der Updater aus |
| Android 8 und neuer | `rosenweg-wetter-<version>.apk` (Rosenweg-Schlüssel) | auf geteilten Telefonen meldet Rosenweg Gerät an und ab |
| Windows 10/11 | `Rosenweg-Wetter-<version>-Setup.exe` | unsigniert, solange kein Code-Signing-Zertifikat da ist (SmartScreen fragt einmal) |
| macOS 11 und neuer | `Rosenweg-Wetter-<version>.dmg` | ohne Apple Developer ID ad hoc signiert (Gatekeeper fragt beim ersten Start) |
| Web (Browser) | `rosenweg-wetter-web.tar.gz` am Release, ausgerollt nach [rosenweg4303.ch/app/wetter/](https://rosenweg4303.ch/app/wetter/) | meldet sich mit der Anmeldung der Website an (eine Anmeldung für alles), kein Updater; Weiteres: rosenweg-basis `docs/web.md` |
| iOS/iPadOS | – | baut in CI ohne Signatur, verteilt wird erst mit dem Apple Developer Program |

Herunterladen: [www.rosenweg4303.ch/apps](https://www.rosenweg4303.ch/apps).

## Datenquelle

Dieselbe wie die Web-Seite `wetter.html` (bleibt bestehen):

| Was | Woher | Baustein |
|---|---|---|
| Live-Werte | MQTT `wetter/r9/<feld>` über `wss://mqtt.rosenweg4303.ch`, öffentlicher Lese-Benutzer `wetter-public` (nur `wetter/r9/#`, steht wie im Web-Code bewusst offen in `lib/quelle.dart`) | `RosenwegMqtt`, `EchtzeitAnzeige` |
| Verlauf | `GET /api/wetter/r9/history?h=1…168` (öffentlich; Schnappschuss je Minute vom Ingest-Timer auf CT 105) | `Verlaufsdiagramm`, `Kleinverlauf`, `ZeitraumWahl` |
| Sonne, Mond | gerechnet (SunCalc) für Kaiseraugst | `lib/sonne_mond.dart` |

Die Station (ioBroker, weatherunderground) liefert seit August 2026 kaum Werte:
Temperatur und Feuchte als Fehlerwert (−5572.8, −9999), Wind, Sonne, Regen
stehen still, nur der Luftdruck bewegt sich. `lib/wetter_daten.dart`
(`lageBestimmen`) erkennt das aus dem 24-h-Verlauf und blendet die Werte des
Aussensensors aus; fehlende Zusatzmodule (CO₂ = 0, Blitz nie, Boden 0) ebenso.
Gespeicherte MQTT-Werte (retained) zählen nicht als „live“.

## Bedienung

Siehe [docs/anleitung.md](docs/anleitung.md).

## Entwickeln

```sh
# rosenweg-basis daneben auschecken, dann lokal gegen sie bauen:
printf 'dependency_overrides:\n  rosenweg_basis:\n    path: ../rosenweg-basis\n' > pubspec_overrides.yaml
flutter pub get
flutter run -d macos                       # oder linux, windows, ein Handy
flutter run -d macos --dart-define=RW_ATTRAPPE=1   # ohne Server, mit Vorführdaten (lib/attrappe.dart)
flutter analyze && flutter test
RW_FOTO=$HOME/Downloads flutter test test/bildschirmfoto_test.dart   # Bildschirmfotos
```

Vor dem Commit `pubspec_overrides.yaml` entfernen und `flutter pub get` laufen lassen –
`pubspec.lock` darf nicht auf `../rosenweg-basis` zeigen (die CI bricht sonst ab).

| Ordner | Inhalt |
|---|---|
| `lib/app.dart` | `RosenwegApp`: Kennung `ch.rosenweg4303.wetter`, Name, Logo |
| `lib/seiten/` | die Seiten der App (`RosenwegGeruest`: Handy unten, Desktop links) |
| `lib/attrappe.dart` | Vorführdaten statt der API (Tests, Bildschirmfotos) |
| `assets/logo/` | Logo aus dem Baukasten der Basis: `sh assets/logo/erzeugen.sh ../rosenweg-basis` |
| `linux/paket/` | Debian-Paket (`bauen.sh`, im Bau-Container `im-container.sh`), `paket.conf` = Vorlage für os-stationen |
| `macos/installer/` | DMG (`bauen.sh`) |
| `windows/installer/` | Inno-Setup-Installer |
| `.github/workflows/` | `app.yml` (Bau, Release) und `apps.yml` (an /apps) – die Arbeit macht rosenweg-basis |

## Veröffentlichen

1. Version in `pubspec.yaml` erhöhen (`version: x.y.z+n`, Baunummer immer mit).
2. Pull Request, CI grün (Linux und Android), Merge auf main.
3. Die CI baut alle fünf Plattformen, legt das Release `vx.y.z` an und schickt
   APK, `.deb`, DMG und Installer an `/apps`. Ohne neue Version passiert nach dem
   Merge nur die CI.
4. Web: `scripts/rw-web-ausrollen.sh --app wetter` im Website-Repo (Archiv aus dem Release), Menüeintrag „Wetter“ zeigt auf `/app/wetter/`.
5. Stationen: `linux/paket/paket.conf` in os-stationen (`pakete/rosenweg-wetter/`)
   mit Version und Prüfsumme nachführen.

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE). Logo-Zeichen: siehe rosenweg-basis
`werkzeug/logo/zeichen/LIZENZEN.md`.
