// SPDX-License-Identifier: GPL-3.0-or-later
/// Sonnenauf- und -untergang, Sonnenhoehe und Mondphase – gerechnet, nicht
/// gemessen, also auch ohne Wetterstation verfuegbar. Nach SunCalc
/// (Vladimir Agafonkin, BSD-2-Clause), wie in wetter.html.
library;

import 'dart:math';

/// Rosenweg 9, Kaiseraugst.
const breite = 47.535, laenge = 7.726;

const _rad = pi / 180, _tagMs = 86400000, _j1970 = 2440588, _j2000 = 2451545, _e = _rad * 23.4397;

double _julian(DateTime d) => d.millisecondsSinceEpoch / _tagMs - 0.5 + _j1970;
DateTime _ausJulian(double j) => DateTime.fromMillisecondsSinceEpoch(((j + 0.5 - _j1970) * _tagMs).round());
double _tage(DateTime d) => _julian(d) - _j2000;
double _ra(double l, double b) => atan2(sin(l) * cos(_e) - tan(b) * sin(_e), cos(l));
double _dek(double l, double b) => asin(sin(b) * cos(_e) + cos(b) * sin(_e) * sin(l));
double _sternzeit(double d, double lw) => _rad * (280.16 + 360.9856235 * d) - lw;
double _mittlereAnomalie(double d) => _rad * (357.5291 + 0.98560028 * d);
double _ekliptik(double m) =>
    m + _rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m)) + _rad * 102.9372 + pi;

/// Hoehe der Sonne in Grad (unter 0 = Nacht).
double sonnenhoehe(DateTime t, {double lat = breite, double lng = laenge}) {
  final lw = _rad * -lng, phi = _rad * lat, d = _tage(t);
  final l = _ekliptik(_mittlereAnomalie(d));
  final dek = _dek(l, 0), ra = _ra(l, 0);
  final h = _sternzeit(d, lw) - ra;
  return asin(sin(phi) * sin(dek) + cos(phi) * cos(dek) * cos(h)) / _rad;
}

/// Sonnenaufgang und -untergang am Tag von [t] (null im Polarsommer/-winter).
({DateTime? aufgang, DateTime? untergang}) sonnenzeiten(DateTime t, {double lat = breite, double lng = laenge}) {
  const j0 = 0.0009;
  final lw = _rad * -lng, phi = _rad * lat;
  final mittag = DateTime(t.year, t.month, t.day, 12);
  final d = _tage(mittag);
  final n = (d - j0 - lw / (2 * pi)).roundToDouble();
  final ds = j0 + lw / (2 * pi) + n;
  final m = _mittlereAnomalie(ds), l = _ekliptik(m), dek = _dek(l, 0);
  final jNoon = _j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
  final h0 = -0.833 * _rad;
  final c = (sin(h0) - sin(phi) * sin(dek)) / (cos(phi) * cos(dek));
  if (c.abs() > 1) return (aufgang: null, untergang: null);
  final w = acos(c);
  final jSet = j0 + (w + lw) / (2 * pi) + n;
  final jUntergang = _j2000 + jSet + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
  final jAufgang = jNoon - (jUntergang - jNoon);
  return (aufgang: _ausJulian(jAufgang).toLocal(), untergang: _ausJulian(jUntergang).toLocal());
}

/// Mondphase: [anteil] beleuchtet (0–1), [phase] 0 = Neumond, 0.5 = Vollmond.
({double anteil, double phase}) mondphase(DateTime t) {
  final d = _tage(t);
  final m = _mittlereAnomalie(d), l = _ekliptik(m);
  final sDek = _dek(l, 0), sRa = _ra(l, 0);
  final ml = _rad * (218.316 + 13.176396 * d), mm = _rad * (134.963 + 13.064993 * d), f = _rad * (93.272 + 13.229350 * d);
  final lm = ml + _rad * 6.289 * sin(mm), b = _rad * 5.128 * sin(f);
  final dist = 385001 - 20905 * cos(mm);
  final mRa = _ra(lm, b), mDek = _dek(lm, b);
  const sdist = 149598000;
  final p = acos(sin(sDek) * sin(mDek) + cos(sDek) * cos(mDek) * cos(sRa - mRa));
  final inc = atan2(sdist * sin(p), dist - sdist * cos(p));
  final winkel = atan2(cos(sDek) * sin(sRa - mRa), sin(sDek) * cos(mDek) - cos(sDek) * sin(mDek) * cos(sRa - mRa));
  return (anteil: (1 + cos(inc)) / 2, phase: 0.5 + 0.5 * inc * (winkel < 0 ? -1 : 1) / pi);
}

/// Name der Mondphase („zunehmender Mond“ …) zu [phase] aus [mondphase].
String mondphaseName(double phase) => const [
      'Neumond',
      'zunehmende Sichel',
      'erstes Viertel',
      'zunehmender Mond',
      'Vollmond',
      'abnehmender Mond',
      'letztes Viertel',
      'abnehmende Sichel',
    ][(phase * 8).round() % 8];
