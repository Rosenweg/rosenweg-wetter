// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import 'wetter_daten.dart';

/// Oeffentlicher Lese-Benutzer des Brokers fuer `wetter/r9/#` – derselbe wie
/// in wetter.html. Er kann nur diese Themen lesen; sein Passwort steht bewusst
/// im oeffentlichen Web-Code (Website docs/mqtt-display.md, „analog zu
/// wetter-public“). So geht „live“ auch mit Karten- und QR-Anmeldungen, die
/// keinen persoenlichen MQTT-Zugang bekommen.
const wetterLeser = MqttZugang.fest('wetter-public', 'wetter-public-a5aafd438e6f4dfb');

/// Alles, was die Seiten von der Wetterstation brauchen: rohe Live-Werte
/// (MQTT), Verlauf der letzten 24 h (API) und daraus die [Lage].
class WetterQuelle extends ChangeNotifier {
  WetterQuelle({required this.api, required this.echtzeit}) {
    _abo = echtzeit.abonnieren(themaFilter).listen((n) {
      _roh[n.feld] = n.text;
      _neuBewerten();
    });
  }

  final RosenwegApi api;
  final EchtzeitQuelle echtzeit;
  late final StreamSubscription<MqttNachricht> _abo;

  final _roh = <String, String>{};
  Map<String, Messreihe> _verlauf = const {};
  Lage _lage = const Lage(werte: {}, texte: {});
  Object? _verlaufFehler;
  bool _verlaufGeladen = false;

  Lage get lage => _lage;
  Map<String, Messreihe> get verlauf24 => _verlauf;
  Object? get verlaufFehler => _verlaufFehler;
  bool get verlaufGeladen => _verlaufGeladen;

  /// Noch gar nichts da (weder live noch Verlauf): Ladeanzeige statt Leer-Zustand.
  bool get wartet => _roh.isEmpty && !_verlaufGeladen && _verlaufFehler == null;

  /// Verlauf der letzten [stunden] (1–168) laden.
  Future<Map<String, Messreihe>> verlaufLaden(int stunden) async =>
      verlaufLesen(await api.get('/api/wetter/$station/history?h=$stunden'));

  /// 24-h-Verlauf neu laden (Start, zurueck in den Vordergrund, alle 5 min)
  /// und die Live-Verbindung anstossen, falls sie getrennt ist.
  Future<void> auffrischen() async {
    echtzeit.nochmals();
    try {
      _verlauf = await verlaufLaden(24);
      _verlaufFehler = null;
    } catch (e) {
      _verlaufFehler = e;
    }
    _verlaufGeladen = true;
    _neuBewerten();
  }

  void _neuBewerten() {
    _lage = lageBestimmen(_roh, _verlauf);
    notifyListeners();
  }

  @override
  void dispose() {
    _abo.cancel();
    echtzeit.schliessen();
    super.dispose();
  }
}
