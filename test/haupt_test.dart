// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_wetter/app.dart';
import 'package:rosenweg_wetter/attrappe.dart';
import 'package:rosenweg_wetter/seiten/haupt.dart';

void main() {
  setUpAll(() => Protokoll.nurKonsole = true);

  Future<Attrappe> zeigen(
    WidgetTester t,
    Size groesse, {
    bool ausfall = false,
    bool ersatz = false,
    Map<String, String>? gespeichert,
    ApiAntwort? verlauf,
  }) async {
    t.view.physicalSize = groesse;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final a = Attrappe(ausfall: ausfall, ersatz: ersatz);
    if (verlauf != null) a.erzwungen['GET /api/wetter/r9/history?h=24'] = verlauf;
    final s = RosenwegSitzung(appAngaben, transport: a);
    await s.starten();
    await t.pumpWidget(RosenwegRahmen(
      sitzung: s,
      inhalt: (_) => Haupt(sitzung: s, echtzeit: EchtzeitAttrappe(gespeichert ?? a.gespeichert())),
    ));
    await t.pumpAndSettle();
    return a;
  }

  Future<void> ende(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('Ersatzwerte: Hinweis mit Station und Stand, Quelle MeteoSchweiz, Ersatz im Verlauf', (t) async {
    // die Live-Werte der ausgefallenen Station (eingefroren) duerfen nicht gelten
    final a = await zeigen(t, const Size(412, 900), ersatz: true, gespeichert: {'wetter/r9/outdoortemp': '21.5'});
    expect(a.anfragen.any((r) => r.pfad == '/api/wetter/r9/aktuell'), isTrue);
    expect(find.textContaining('Ersatzwerte: MeteoSchweiz, Station Basel / Binningen (BAS), Stand'), findsOneWidget);
    expect(find.textContaining('3.1'), findsWidgets);
    expect(find.textContaining('21.5'), findsNothing);
    expect(find.textContaining('Aussensensor'), findsNothing);
    await t.scrollUntilVisible(find.textContaining('Quelle MeteoSchweiz'), 300);
    await t.tap(find.text('Verlauf'));
    await t.pumpAndSettle();
    expect(find.textContaining('Im Verlauf stehen Ersatzwerte: MeteoSchweiz'), findsOneWidget);
    await ende(t);
  });

  testWidgets('Station liefert: Temperatur gross, Kacheln, Sonne und Mond; Verlauf mit allen Werten', (t) async {
    final a = await zeigen(t, const Size(412, 900));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.textContaining('°C'), findsWidgets);
    expect(find.textContaining('Aussentemperatur'), findsOneWidget);
    expect(find.text('verbunden · wartet auf neue Werte'), findsOneWidget, reason: 'retained zaehlt nicht als live');
    expect(find.text('Luftdruck'), findsOneWidget);
    expect(find.textContaining('Aussensensor'), findsNothing);
    await t.scrollUntilVisible(find.text('Regen dieses Jahr'), 200);
    expect(find.text('CO₂'), findsNothing, reason: 'CO₂-Modul meldet 0 = nicht vorhanden');
    expect(find.text('Blitze'), findsNothing, reason: 'noch nie ein Blitz = kein Blitzsensor');
    await t.scrollUntilVisible(find.text('Sonne und Mond'), 200);
    expect(find.textContaining('Aufgang'), findsOneWidget);
    expect(a.anfragen.any((r) => r.pfad == '/api/wetter/r9/history?h=24'), isTrue);

    await t.tap(find.text('Verlauf'));
    await t.pumpAndSettle();
    expect(find.text('Temperatur'), findsOneWidget);
    expect(find.byType(Kleinverlauf), findsWidgets);
    expect(find.textContaining('Ohne Werte'), findsNothing);

    // gross mit Zeitraum
    await t.tap(find.text('Temperatur'));
    await t.pumpAndSettle();
    expect(find.byType(ZeitraumWahl), findsOneWidget);
    expect(find.byType(Verlaufsdiagramm), findsOneWidget);
    await t.tap(find.text('7 T'));
    await t.pumpAndSettle();
    expect(a.anfragen.any((r) => r.pfad == '/api/wetter/r9/history?h=168'), isTrue);
    expect(find.textContaining('tiefster'), findsOneWidget);
    await ende(t);
  });

  testWidgets('Aussensensor aus (wie seit August 2026): nur Luftdruck, klare Hinweise', (t) async {
    await zeigen(t, const Size(412, 900), ausfall: true);
    expect(find.text('Keine aktuelle Temperatur'), findsOneWidget);
    expect(find.textContaining('Aussensensor der Wetterstation liefert zurzeit keine Werte'), findsOneWidget);
    expect(find.text('Luftdruck'), findsOneWidget);
    expect(find.text('Wind'), findsNothing);
    expect(find.text('Sonnenstrahlung'), findsNothing);
    await t.scrollUntilVisible(find.text('Sonne und Mond'), 200);
    expect(find.text('Regen dieses Jahr'), findsNothing, reason: 'eingefrorener Jahreswert');
    expect(find.text('Bodenfeuchte'), findsNothing);

    await t.tap(find.text('Verlauf'));
    await t.pumpAndSettle();
    expect(find.text('Luftdruck'), findsOneWidget);
    expect(find.text('Temperatur'), findsNothing);
    expect(find.textContaining('Ohne Werte in den letzten 24 Stunden: Temperatur, Luftfeuchte, Wind'), findsOneWidget);
    await ende(t);
  });

  testWidgets('gar keine Werte: Leer-Zustand statt Nullen', (t) async {
    await zeigen(t, const Size(412, 900),
        gespeichert: const {'wetter/r9/outdoortemp': '-9999', 'wetter/r9/outdoorhumidity': '-9999'},
        verlauf: (status: 200, json: {'station': 'r9', 'hours': 24, 'points': <Object>[]}));
    expect(find.text('Die Wetterstation liefert gerade keine Werte.'), findsOneWidget);
    expect(find.text('Keine aktuelle Temperatur'), findsOneWidget);
    await t.tap(find.text('Verlauf'));
    await t.pumpAndSettle();
    expect(find.text('Noch kein Verlauf'), findsOneWidget);
    await ende(t);
  });

  testWidgets('Verlauf nicht erreichbar: Fehler mit Nochmals, Jetzt geht trotzdem', (t) async {
    await zeigen(t, const Size(412, 900), verlauf: (status: 500, json: {'error': 'history'}));
    expect(find.textContaining('Aussentemperatur'), findsOneWidget);
    await t.tap(find.text('Verlauf'));
    await t.pumpAndSettle();
    expect(find.text('Nochmals'), findsOneWidget);
    await t.tap(find.text('Nochmals'));
    await t.pumpAndSettle();
    expect(find.byType(Kleinverlauf), findsWidgets);
    await ende(t);
  });

  testWidgets('Station (breit): Leiste links, Verlauf zweispaltig', (t) async {
    await zeigen(t, const Size(1280, 860));
    expect(find.byType(NavigationRail), findsOneWidget);
    await t.tap(find.text('Verlauf'));
    await t.pumpAndSettle();
    final a = t.getTopLeft(find.text('Temperatur'));
    final b = t.getTopLeft(find.text('Luftfeuchte'));
    expect(a.dy, b.dy, reason: 'zwei Karten nebeneinander');
    await ende(t);
  });
}
