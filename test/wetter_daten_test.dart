// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_wetter/attrappe.dart';
import 'package:rosenweg_wetter/sonne_mond.dart';
import 'package:rosenweg_wetter/wetter_daten.dart';

Map<String, String> _roh(Map<String, String> m) => {for (final e in m.entries) e.key.split('/').last: e.value};

void main() {
  final jetzt = DateTime(2026, 11, 28, 12);

  test('wertLesen: Fehlerwerte weg, Solar von Lux in W/m²', () {
    expect(wertLesen('outdoortemp', '-5572.8'), isNull);
    expect(wertLesen('outdoorhumidity', -9999), isNull);
    expect(wertLesen('outdoortemp', '-3.4'), -3.4);
    expect(wertLesen('solarradiation', 1267), closeTo(10, 1e-9));
    expect(wertLesen('windheading', 'WNW'), isNull);
  });

  test('lageBestimmen: Station in Ordnung', () {
    final a = Attrappe(jetzt: jetzt);
    final l = lageBestimmen(_roh(a.gespeichert()), verlaufLesen({'points': a.verlauf(24)}));
    expect(l.aussenAusgefallen, isFalse);
    expect(l[temperatur], isNotNull);
    expect(l[regenJahr], 702.3);
    expect(l[co2], isNull);
    expect(l[blitze], isNull);
  });

  test('lageBestimmen: Aussensensor aus – nur Luftdruck bleibt', () {
    final a = Attrappe(jetzt: jetzt, ausfall: true);
    final l = lageBestimmen(_roh(a.gespeichert()), verlaufLesen({'points': a.verlauf(24)}));
    expect(l.aussenAusgefallen, isTrue);
    expect(l.werte.keys.toSet(), {'pressureabs'}, reason: 'rel. Druck = abs. Druck sagt nichts Neues');
    expect(l.ausgefallenSeit, isNotNull);
  });

  test('lageBestimmen: ohne Verlauf nur die offensichtlichen Fehlerwerte weg', () {
    final l = lageBestimmen({'outdoortemp': '-5572.8', 'pressureabs': '991.7', 'windspeed': '0'}, const {});
    expect(l.aussenAusgefallen, isFalse, reason: 'ein Zeichen allein reicht nicht');
    expect(l.werte, {'pressureabs': 991.7, 'windspeed': 0});
  });

  test('Ableitungen: Taupunkt, gefuehlt, Kompass', () {
    expect(taupunkt(20, 50)!, closeTo(9.3, 0.1));
    expect(gefuehlt(2, 80, 20)!.art, 'Windchill');
    expect(gefuehlt(30, 60, 0)!.art, 'Hitzeindex');
    expect(gefuehlt(15, 60, 3)!.wert, 15);
    expect(kompass(287), 'WNW');
    expect(kompass(359), 'N');
  });

  test('Sonne und Mond fuer Kaiseraugst', () {
    final s = sonnenzeiten(DateTime(2026, 11, 28));
    // Ende November: Aufgang gegen 7:55, Untergang gegen 16:40 (MEZ)
    expect(s.aufgang!.toUtc().hour * 60 + s.aufgang!.toUtc().minute, inInclusiveRange(6 * 60 + 40, 7 * 60 + 10));
    expect(s.untergang!.toUtc().hour * 60 + s.untergang!.toUtc().minute, inInclusiveRange(15 * 60 + 25, 15 * 60 + 55));
    expect(sonnenhoehe(DateTime.utc(2026, 11, 28, 11, 30)), greaterThan(15));
    expect(sonnenhoehe(DateTime.utc(2026, 11, 28, 23)), lessThan(0));
    final m = mondphase(DateTime.utc(2026, 11, 24, 15)); // Vollmond 24.11.2026
    expect(m.anteil, greaterThan(0.97));
    expect(mondphaseName(m.phase), 'Vollmond');
  });

  test('Verlauf lesen: Zeitpunkte lokal, fehlende Werte als Luecke', () {
    final r = verlaufLesen({
      'points': [
        {'ts': '2026-11-28T10:00:00.000Z', 'outdoortemp': 3.1, 'pressureabs': 991.0},
        {'ts': '2026-11-28T10:01:00.000Z', 'outdoortemp': null, 'pressureabs': 991.1},
      ],
    });
    expect(r[temperatur.name]!.punkte.length, 2);
    expect(r[temperatur.name]!.gueltige.length, 1);
    expect(r[druck.name]!.letzter!.wert, 991.1);
    expect(r[druck.name], isA<Messreihe>());
  });

  test('Ersatz: aus der Antwort der API lesen, Hinweis mit Station und Stand', () {
    final j = Attrappe(jetzt: jetzt, ersatz: true);
    final antwort = {
      'zustand': 'ersatz',
      'quelle': {'art': 'meteoschweiz', 'station': 'BAS', 'name': 'Basel / Binningen', 'stand': '2026-11-28T11:00:00.000Z', 'abstand_km': 10.3},
      'werte': {'outdoortemp': 3.1, 'solarradiation': 12670, 'uvi': null, 'sonnenschein_min': 10},
    };
    final e = ersatzLesen(antwort)!;
    expect(e.station, 'BAS');
    expect(e.hinweis, startsWith('Ersatzwerte: MeteoSchweiz, Station Basel / Binningen (BAS), Stand '));
    final roh = ersatzRoh(antwort);
    expect(roh.keys.toSet(), {'outdoortemp', 'solarradiation'}, reason: 'null und Sonnenscheindauer bleiben draussen');
    final l = lageBestimmen(roh, const {}).mitErsatz(e);
    expect(l[temperatur], 3.1);
    expect(l[sonne], closeTo(100, 1e-9));
    expect(l.ersatz, isNotNull);
    expect(j.ersatz, isTrue);
    // eigene Station oder fremde Quelle: kein Ersatz
    expect(ersatzLesen({'zustand': 'eigen', 'quelle': {'art': 'eigen'}}), isNull);
    expect(ersatzLesen({'zustand': 'ersatz', 'quelle': {'art': 'andere', 'station': 'X', 'stand': '2026-11-28T11:00:00Z'}}), isNull);
    expect(ersatzLesen(null), isNull);
  });

  test('Verlauf: Ersatz-Zeitraum und Stationen aus der API', () {
    final r = verlaufErsatzLesen({
      'ersatz': {'von': '2026-11-28T08:00:00.000Z', 'bis': '2026-11-28T11:00:00.000Z'},
      'points': [
        {'ts': '2026-11-28T08:00:00Z', 'ersatz': true, 'ersatz_station': 'BAS'},
        {'ts': '2026-11-28T07:00:00Z'},
      ],
    })!;
    expect(r.stationen, {'BAS'});
    expect(r.bis.isAfter(r.von), isTrue);
    expect(verlaufErsatzLesen({'ersatz': null, 'points': []}), isNull);
  });
}
