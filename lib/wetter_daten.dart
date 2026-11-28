// SPDX-License-Identifier: GPL-3.0-or-later
/// Was die Wetterstation liefert und wie die App es liest – dieselbe Quelle
/// und dieselben Regeln wie wetter.html:
///
/// - **live:** MQTT `wetter/r9/<feld>` ueber den Broker der Anlage (je Feld
///   ein Thema, Inhalt = Zahl bzw. Text, retained). ioBroker
///   (weatherunderground-Adapter) schreibt dorthin.
/// - **Verlauf:** `GET /api/wetter/r9/history?h=1…168` (oeffentlich), ein
///   Schnappschuss je Minute (Ingest-Timer auf CT 105).
///
/// Dazu kommt, was die Web-Seite noch nicht kann: Werte, die offensichtlich
/// nicht stimmen, werden ausgeblendet statt als „0“ gezeigt (Aussensensor
/// ausgefallen, Zusatzmodule nicht vorhanden). Seit August 2026 liefert die
/// Station kaum Werte; die App zeigt dann einen sauberen Leer-Zustand.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Station (Teil der Themen und des API-Pfads).
const station = 'r9';
const themaFilter = 'wetter/$station/#';

/// Solar liefert die Station in Lux; W/m² wie wetter.html (Ecowitt ~ Lux/126.7).
const luxJeWm2 = 126.7;

/// Ein Messwert der Station.
@immutable
class Feld {
  const Feld(this.name, this.titel, this.einheit, this.stellen, this.symbol, {this.farbe, this.aussen = true});

  /// Name im Thema bzw. in der Verlaufs-API (`outdoortemp`).
  final String name;
  final String titel;
  final String einheit;
  final int stellen;
  final IconData symbol;

  /// Farbe im Diagramm (nur Felder mit Verlauf).
  final Color? farbe;

  /// Kommt vom Aussensensor (Temperatur, Wind, Sonne, Regen). Faellt der aus,
  /// sind alle diese Werte eingefroren bzw. ungueltig.
  final bool aussen;

  String text(double? v, {bool einheitDazu = true}) {
    if (v == null || !v.isFinite) return '–';
    final z = v.toStringAsFixed(stellen);
    return einheitDazu && einheit.isNotEmpty ? '$z $einheit' : z;
  }
}

const temperatur = Feld('outdoortemp', 'Temperatur', '°C', 1, Icons.thermostat, farbe: Color(0xFFEA580C));
const feuchte = Feld('outdoorhumidity', 'Luftfeuchte', '%', 0, Icons.water_drop_outlined, farbe: Color(0xFF0284C7));
const wind = Feld('windspeed', 'Wind', 'km/h', 1, Icons.air, farbe: Color(0xFF65A30D));
const boeen = Feld('windgustspeed', 'Böen', 'km/h', 1, Icons.storm, farbe: Color(0xFF4D7C0F));
const maxBoe = Feld('maxdailygust', 'Stärkste Böe heute', 'km/h', 1, Icons.storm);
const windrichtung = Feld('winddir', 'Windrichtung', '°', 0, Icons.explore_outlined);
const druck = Feld('pressureabs', 'Luftdruck', 'hPa', 1, Icons.speed, farbe: Color(0xFF9333EA), aussen: false);
const druckRel = Feld('pressurerel', 'Luftdruck auf Meereshöhe', 'hPa', 1, Icons.speed, aussen: false);
const sonne = Feld('solarradiation', 'Sonnenstrahlung', 'W/m²', 0, Icons.wb_sunny_outlined, farbe: Color(0xFFCA8A04));
const uv = Feld('uvi', 'UV-Index', '', 0, Icons.brightness_high_outlined, farbe: Color(0xFFDB2777));
const regenrate = Feld('rain', 'Regen jetzt', 'mm/h', 1, Icons.grain, farbe: Color(0xFF2563EB));
const regenHeute = Feld('dailyrain', 'Regen heute', 'mm', 1, Icons.umbrella_outlined);
const regenWoche = Feld('weeklyrain', 'Regen diese Woche', 'mm', 1, Icons.umbrella_outlined);
const regenMonat = Feld('monthlyrain', 'Regen diesen Monat', 'mm', 1, Icons.umbrella_outlined);
const regenJahr = Feld('yearlyrain', 'Regen dieses Jahr', 'mm', 1, Icons.umbrella_outlined);
const blitze = Feld('lightning', 'Blitze', '', 0, Icons.bolt, aussen: false);
const co2 = Feld('co2', 'CO₂', 'ppm', 0, Icons.co2, aussen: false);
const pm25 = Feld('pm25_co2', 'Feinstaub PM2.5', 'µg/m³', 0, Icons.blur_on, aussen: false);
const pm10 = Feld('pm10_co2', 'Feinstaub PM10', 'µg/m³', 0, Icons.blur_on, aussen: false);
const bodenfeuchte = Feld('soilmoisture', 'Bodenfeuchte', '%', 0, Icons.grass, aussen: false);
const zusatzTemp = Feld('tf_ch', 'Temperatur Zusatzfühler', '°C', 1, Icons.thermostat_outlined, aussen: false);

/// Felder mit Verlauf (Spalten von /api/wetter/r9/history), in dieser Reihenfolge.
const verlaufFelder = [temperatur, feuchte, druck, wind, boeen, sonne, uv, regenrate];

/// Kacheln auf „Jetzt“, gruppiert.
const gruppen = <(String, IconData, List<Feld>)>[
  ('Luft und Wind', Icons.air, [feuchte, druck, druckRel, wind, boeen, maxBoe, windrichtung]),
  ('Sonne', Icons.wb_sunny_outlined, [sonne, uv]),
  ('Regen', Icons.umbrella_outlined, [regenrate, regenHeute, regenWoche, regenMonat, regenJahr]),
  ('Luftqualität und Garten', Icons.eco_outlined, [co2, pm25, pm10, bodenfeuchte, zusatzTemp, blitze]),
];

/// Wert aus MQTT oder Verlauf lesen. null = keiner: Sensor-Fehlerwerte
/// (-9999, -5572.8 …) und unrealistische Extremwerte wie in wetter.html.
double? wertLesen(String feld, Object? roh) {
  final v = roh is num ? roh.toDouble() : double.tryParse('${roh ?? ''}'.trim());
  if (v == null || !v.isFinite || v <= -1000 || v >= 100000) return null;
  return feld == sonne.name ? v / luxJeWm2 : v;
}

/// Kompass-Richtung zu Grad.
String kompass(double grad) {
  const r = ['N', 'NNO', 'NO', 'ONO', 'O', 'OSO', 'SO', 'SSO', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  return r[((grad % 360) / 22.5).round() % 16];
}

/// Verlauf aus der API: Messreihen je Feld.
Map<String, Messreihe> verlaufLesen(Object? json) {
  final punkte = json is Map && json['points'] is List ? json['points'] as List : const [];
  final reihen = <String, Messreihe>{};
  for (final f in verlaufFelder) {
    reihen[f.name] = Messreihe(
      titel: f.titel,
      einheit: f.einheit,
      farbe: f.farbe,
      nachkommastellen: f.stellen,
      punkte: [
        for (final p in punkte)
          if (p is Map && DateTime.tryParse('${p['ts']}') != null)
            Messpunkt(DateTime.parse('${p['ts']}').toLocal(), wertLesen(f.name, p[f.name])),
      ],
    );
  }
  return reihen;
}

/// Ersatzwerte: faellt die eigene Station aus, liefert die API (`GET
/// /api/wetter/r9/aktuell`) die Messung einer MeteoSchweiz-Station (Open
/// Government Data, Namensnennung Pflicht).
@immutable
class Ersatz {
  const Ersatz({required this.station, required this.name, required this.stand, this.abstandKm});

  /// Abkuerzung, z. B. BAS.
  final String station;

  /// Name, z. B. „Basel / Binningen“.
  final String name;

  /// Zeitpunkt der Messung.
  final DateTime stand;
  final double? abstandKm;

  /// „Basel / Binningen (BAS)“.
  String get stationText => name.isEmpty || name == station ? station : '$name ($station)';

  /// Der Hinweis nach den Nutzungsbedingungen von MeteoSchweiz.
  String get hinweis => 'Ersatzwerte: MeteoSchweiz, Station $stationText, Stand ${zeitpunktText(stand)}';
}

/// Ersatz aus der Antwort von `/api/wetter/r9/aktuell`; null = eigene Station.
Ersatz? ersatzLesen(Object? json) {
  if (json is! Map || json['zustand'] != 'ersatz') return null;
  final q = json['quelle'];
  if (q is! Map || q['art'] != 'meteoschweiz') return null;
  final stand = DateTime.tryParse('${q['stand']}');
  if (stand == null) return null;
  final abk = '${q['station'] ?? ''}'.trim();
  if (abk.isEmpty) return null;
  return Ersatz(
    station: abk,
    name: '${q['name'] ?? ''}'.trim(),
    stand: stand.toLocal(),
    abstandKm: q['abstand_km'] is num ? (q['abstand_km'] as num).toDouble() : null,
  );
}

/// Werte der Ersatzstation als rohe Feldwerte (wie von MQTT); ohne Sonnenscheindauer.
Map<String, String> ersatzRoh(Object? json) {
  final w = json is Map ? json['werte'] : null;
  if (w is! Map) return const {};
  return {
    for (final e in w.entries)
      if (e.value is num && e.key != 'sonnenschein_min') '${e.key}': '${e.value}',
  };
}

/// Zeitraum im Verlauf, in dem Ersatzwerte stehen (API: `ersatz: {von, bis}`); sonst null.
({DateTime von, DateTime bis, Set<String> stationen})? verlaufErsatzLesen(Object? json) {
  if (json is! Map || json['ersatz'] is! Map) return null;
  final e = json['ersatz'] as Map;
  final von = DateTime.tryParse('${e['von']}'), bis = DateTime.tryParse('${e['bis']}');
  if (von == null || bis == null) return null;
  final punkte = json['points'] is List ? json['points'] as List : const [];
  final st = {
    for (final p in punkte)
      if (p is Map && p['ersatz'] == true && '${p['ersatz_station'] ?? ''}'.isNotEmpty) '${p['ersatz_station']}',
  };
  return (von: von.toLocal(), bis: bis.toLocal(), stationen: st);
}

/// Was die Station gerade wirklich liefert.
@immutable
class Lage {
  const Lage({required this.werte, required this.texte, this.aussenAusgefallen = false, this.ausgefallenSeit, this.ersatz});

  /// Gesetzt, wenn die Werte nicht von der eigenen Station kommen.
  final Ersatz? ersatz;

  Lage mitErsatz(Ersatz e) => Lage(werte: werte, texte: texte, ersatz: e);

  /// Gueltige Zahlen je Feld (ohne Fehlerwerte, ohne Ausgefallenes).
  final Map<String, double> werte;

  /// Textwerte (windheading, lightning_time in Unix-Sekunden).
  final Map<String, String> texte;

  /// Aussensensor liefert nichts bzw. immer dasselbe.
  final bool aussenAusgefallen;

  /// Seit mindestens so langer Zeit steht der Aussensensor (Spanne des
  /// Verlaufs, in dem sich nichts bewegt hat; null = unbekannt).
  final Duration? ausgefallenSeit;

  double? operator [](Feld f) => werte[f.name];
  bool get leer => werte.isEmpty;
}

/// Liest die rohen MQTT-Werte und den 24-h-Verlauf zu einer [Lage].
///
/// Aussensensor ausgefallen = mindestens zwei von: Temperatur fehlt oder steht,
/// Feuchte fehlt oder steht, Sonnenstrahlung steht, Windrichtung steht – je
/// ueber mindestens 12 h Verlauf immer derselbe Wert. Dann gelten alle
/// Aussen-Werte (auch Regen) als unbekannt.
Lage lageBestimmen(Map<String, String> roh, Map<String, Messreihe> verlauf) {
  bool steht(Feld f) {
    final g = verlauf[f.name]?.gueltige ?? const <Messpunkt>[];
    if (g.length < 2) return false;
    if (g.last.zeit.difference(g.first.zeit) < const Duration(hours: 12)) return false;
    return g.every((p) => p.wert == g.first.wert);
  }

  bool fehlt(Feld f) {
    final r = verlauf[f.name];
    final verlaufLeer = r != null && r.punkte.length >= 10 && r.gueltige.isEmpty;
    return verlaufLeer || (roh.containsKey(f.name) && wertLesen(f.name, roh[f.name]) == null);
  }

  final zeichen = [
    fehlt(temperatur) || steht(temperatur),
    fehlt(feuchte) || steht(feuchte),
    steht(sonne),
    steht(windrichtung),
  ].where((b) => b).length;
  final aus = zeichen >= 2;
  Duration? seit;
  if (aus) {
    final p = verlauf[druck.name]?.punkte ?? verlauf.values.firstOrNull?.punkte ?? const [];
    if (p.length >= 2) seit = p.last.zeit.difference(p.first.zeit);
  }

  final werte = <String, double>{};
  final texte = <String, String>{};
  for (final MapEntry(key: name, value: text) in roh.entries) {
    final v = _textFelder.contains(name) ? null : wertLesen(name, text);
    if (v == null) {
      if (text.trim().isNotEmpty) texte[name] = text.trim();
      continue;
    }
    werte[name] = v;
  }
  // Aussensensor aus: alles von dort weg (eingefroren oder Fehlerwert)
  if (aus) {
    for (final g in gruppen) {
      for (final f in g.$3) {
        if (f.aussen) werte.remove(f.name);
      }
    }
    for (final n in [temperatur.name, 'dewpointtemp', 'windchilltemp', 'windheading']) {
      werte.remove(n);
      texte.remove(n);
    }
  }
  // Zusatzmodule, die es nicht gibt: das CO₂-Modul meldet dann ueberall 0.
  if ((werte[co2.name] ?? 0) <= 0) {
    for (final n in [co2.name, pm25.name, pm10.name, 'humi_co2', 'tf_co2']) {
      werte.remove(n);
    }
  }
  // relativer Druck ohne Hoehenkorrektur (= absolut) sagt nichts Neues
  if (werte[druckRel.name] != null && werte[druckRel.name] == werte[druck.name]) werte.remove(druckRel.name);
  if (werte[bodenfeuchte.name] == 0) werte.remove(bodenfeuchte.name);
  if (werte[zusatzTemp.name] == 0) werte.remove(zusatzTemp.name);
  // Blitzsensor: nur zeigen, wenn er je einen Blitz gemeldet hat.
  if ((int.tryParse(texte['lightning_time'] ?? '') ?? 0) <= 0) werte.remove(blitze.name);
  // doppelte Regenmesser (Piezo) nur, wenn es einen gibt
  for (final n in [...werte.keys]) {
    if (n.endsWith('_piezo')) werte.remove(n);
  }
  return Lage(werte: werte, texte: texte, aussenAusgefallen: aus, ausgefallenSeit: seit);
}

/// Felder, die als Text gelesen werden (Richtung als Wort, Zeitpunkt in Sekunden).
const _textFelder = {'windheading', 'lightning_time'};

/// Taupunkt (Magnus) in °C.
double? taupunkt(double? t, double? rh) {
  if (t == null || rh == null || rh <= 0) return null;
  const a = 17.27, b = 237.7;
  final g = (a * t) / (b + t) + math.log(rh / 100);
  return (b * g) / (a - g);
}

/// Gefuehlte Temperatur: Windchill bis 10 °C, Hitzeindex ab 27 °C, sonst gemessen.
({double wert, String art})? gefuehlt(double? t, double? rh, double? v) {
  if (t == null) return null;
  if (t <= 10 && v != null && v > 4.8) {
    final p = math.pow(v, 0.16).toDouble();
    return (wert: 13.12 + 0.6215 * t - 11.37 * p + 0.3965 * t * p, art: 'Windchill');
  }
  if (t >= 27 && rh != null) {
    const c = [-8.784695, 1.61139411, 2.338549, -0.14611605, -0.012308094, -0.016424828, 0.002211732, 0.00072546, -0.000003582];
    return (
      wert: c[0] + c[1] * t + c[2] * rh + c[3] * t * rh + c[4] * t * t + c[5] * rh * rh + c[6] * t * t * rh + c[7] * t * rh * rh + c[8] * t * t * rh * rh,
      art: 'Hitzeindex',
    );
  }
  return (wert: t, art: 'wie gemessen');
}

/// Kurzer Hinweis unter einer Kachel (wie wetter.html).
String? hinweisZu(Feld f, double v, Lage l) => switch (f.name) {
      'windspeed' => v < 1 ? 'windstill' : (v >= 39 ? 'stürmisch' : null),
      'windgustspeed' => v >= 39 ? 'Sturmböen' : null,
      'winddir' => l.texte['windheading'] ?? kompass(v),
      'pressureabs' => v < 1000 ? 'eher Tiefdruck' : (v > 1020 ? 'eher Hochdruck' : 'normal'),
      'solarradiation' => v <= 0 ? 'kein Sonnenlicht' : (v > 600 ? 'starke Sonne' : null),
      'uvi' => v < 3 ? 'niedrig' : v < 6 ? 'mässig' : v < 8 ? 'hoch' : v < 11 ? 'sehr hoch' : 'extrem',
      'rain' => v > 0 ? 'es regnet' : 'trocken',
      _ => null,
    };
