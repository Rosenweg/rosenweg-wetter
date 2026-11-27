// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Antwortet wie die Haupt-API, mit erfundenen Daten (keine echten Personen,
/// keine echten Messwerte). Fuer Tests, Bildschirmfotos und Entwicklung ohne
/// Server (--dart-define=RW_ATTRAPPE=1, dazu RW_AUSFALL=1 fuer den Zustand
/// „Aussensensor liefert nichts“ wie seit August 2026).
class Attrappe implements Transport {
  Attrappe({this.ausfall = false, DateTime? jetzt}) : jetzt = jetzt ?? DateTime.now();

  /// Wie die echte Station seit August 2026: Temperatur/Feuchte fehlen, Wind,
  /// Sonne und Regen stehen, nur der Luftdruck bewegt sich.
  final bool ausfall;
  final DateTime jetzt;

  /// Alle Anfragen in der Reihenfolge (fuer Tests).
  final anfragen = <({String methode, String pfad, Object? koerper})>[];

  /// Naechste Antwort fuer einen Pfad erzwingen (Tests), z. B. einen Fehler.
  final erzwungen = <String, ApiAntwort>{};

  final _ich = <String, dynamic>{
    'id': 7,
    'username': 'erika.muster',
    'name': 'Erika Muster',
    'email': 'erika.muster@example.org',
    'role': 'user',
    'groups': ['stweg3-eigentuemer'],
    'permissions': {'dashboard': 'read'},
  };

  @override
  Future<ApiAntwort> senden(String methode, String pfad, {Object? koerper}) async {
    anfragen.add((methode: methode, pfad: pfad, koerper: koerper));
    final z = erzwungen.remove('$methode $pfad');
    if (z != null) return z;
    final uri = Uri.parse(pfad);
    switch ('$methode ${uri.path}') {
      case 'GET /api/auth/me':
        return (status: 200, json: {'user': _ich});
      case 'GET /api/wetter/r9/history':
        final h = (int.tryParse(uri.queryParameters['h'] ?? '') ?? 24).clamp(1, 168);
        return (status: 200, json: {'station': 'r9', 'hours': h, 'points': verlauf(h)});
    }
    return (status: 404, json: {'error': 'Nicht gefunden: $methode $pfad'});
  }

  /// Ein Punkt je 10 Minuten, wie die Spalten von wetter_history.
  List<Map<String, dynamic>> verlauf(int stunden) {
    final r = Random(stunden);
    final punkte = <Map<String, dynamic>>[];
    for (var m = stunden * 60; m >= 0; m -= 10) {
      final t = jetzt.subtract(Duration(minutes: m));
      final tag = (t.hour + t.minute / 60 - 14) / 24 * 2 * pi; // waermste Zeit 14 Uhr
      final hell = max(0.0, sin((t.hour + t.minute / 60 - 7.5) / 9 * pi)); // 7:30–16:30
      final druck = 1012 + 6 * sin(t.millisecondsSinceEpoch / 3.6e6 / 40) + r.nextDouble() * 0.3;
      punkte.add(ausfall
          ? {
              'ts': t.toUtc().toIso8601String(),
              'outdoortemp': null,
              'outdoorhumidity': null,
              'windspeed': 0,
              'winddir': 287,
              'pressureabs': double.parse((druck - 20).toStringAsFixed(1)),
              'solarradiation': 191,
              'rain': 0,
              'uvi': 0,
              'windgustspeed': 0,
            }
          : {
              'ts': t.toUtc().toIso8601String(),
              'outdoortemp': double.parse((4 + 3.5 * cos(tag) + r.nextDouble() * 0.4).toStringAsFixed(1)),
              'outdoorhumidity': (82 - 12 * cos(tag) + r.nextInt(3)).round(),
              'windspeed': double.parse((6 + 5 * hell + r.nextDouble() * 4).toStringAsFixed(1)),
              'winddir': 230 + r.nextInt(40),
              'pressureabs': double.parse(druck.toStringAsFixed(1)),
              'solarradiation': (hell * 260 * 126.7 * (0.6 + r.nextDouble() * 0.4)).round(),
              'rain': t.hour >= 3 && t.hour < 5 ? double.parse((r.nextDouble() * 1.6).toStringAsFixed(1)) : 0,
              'uvi': (hell * 1.4).round(),
              'windgustspeed': double.parse((11 + 8 * hell + r.nextDouble() * 6).toStringAsFixed(1)),
            });
    }
    return punkte;
  }

  /// Was der Broker unter wetter/r9/# gespeichert haette (retained).
  Map<String, String> gespeichert() {
    final letzt = verlauf(1).last;
    String v(Object? x) => '$x';
    return ausfall
        ? {
            // genau so liefert die echte Station seit August 2026
            'wetter/r9/outdoortemp': '-5572.8',
            'wetter/r9/outdoorhumidity': '-9999',
            'wetter/r9/dewpointtemp': '-5572.8',
            'wetter/r9/windspeed': '0',
            'wetter/r9/windgustspeed': '0',
            'wetter/r9/winddir': '287',
            'wetter/r9/windheading': 'WNW',
            'wetter/r9/pressureabs': v(letzt['pressureabs']),
            'wetter/r9/pressurerel': v(letzt['pressureabs']),
            'wetter/r9/solarradiation': '191',
            'wetter/r9/uvi': '0',
            'wetter/r9/rain': '0',
            'wetter/r9/dailyrain': '0',
            'wetter/r9/yearlyrain': '163.3',
            'wetter/r9/co2': '0',
            'wetter/r9/pm25_co2': '0',
            'wetter/r9/lightning': '0',
            'wetter/r9/lightning_time': '0',
            'wetter/r9/soilmoisture': '0',
            'wetter/r9/tf_ch': '0',
          }
        : {
            for (final f in ['outdoortemp', 'outdoorhumidity', 'windspeed', 'windgustspeed', 'winddir', 'pressureabs', 'solarradiation', 'uvi', 'rain'])
              'wetter/r9/$f': v(letzt[f]),
            'wetter/r9/windheading': 'WSW',
            'wetter/r9/pressurerel': v(((letzt['pressureabs'] as num) + 31.4).toStringAsFixed(1)),
            'wetter/r9/maxdailygust': '24.1',
            'wetter/r9/dailyrain': '1.2',
            'wetter/r9/weeklyrain': '6.8',
            'wetter/r9/monthlyrain': '41.5',
            'wetter/r9/yearlyrain': '702.3',
            'wetter/r9/co2': '0',
            'wetter/r9/lightning': '0',
            'wetter/r9/lightning_time': '0',
          };
  }

  /// Echtzeit ohne Broker mit diesen Werten.
  EchtzeitAttrappe echtzeit() => EchtzeitAttrappe(gespeichert());
}

/// --dart-define=RW_AUSFALL=1: Attrappe im Zustand der echten Station.
const attrappeAusfall = bool.fromEnvironment('RW_AUSFALL');
