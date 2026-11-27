// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/painting.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Angaben der App fuer rosenweg_basis.
///
/// kennung = applicationId (Android) = Bundle-ID (iOS/macOS) = GTK-ID (Linux)
/// = Schema des Ruecksprungs (ch.rosenweg4303.wetter:/anmeldung, in Authentik
/// bei rosenweg-apps eintragen) = Paket im App-Katalog (/apps, Updater).
const appAngaben = RosenwegApp(
  kennung: 'ch.rosenweg4303.wetter',
  name: 'Rosenweg Wetter',
  ordner: 'rosenweg-wetter',
  beschreibung: 'Wetterstation am Rosenweg 9: aktuelle Werte live, Verlauf bis 7 Tage, Sonne und Mond.',
  quelle: 'https://github.com/Rosenweg/rosenweg-wetter',
  logo: AssetImage('assets/logo/rosenweg-wetter-512.png'),
  // Farbe des Anmeldeschirms wie der Logo-Grund (assets/logo/erzeugen.sh GRUPPE);
  // neue-app.sh setzt sie aus werkzeug/logo/flutter-apps.txt
  gruppe: RosenwegGruppe.bewohner,
);

/// --dart-define=RW_ATTRAPPE=1: ohne Anmeldung und ohne Server, mit
/// erfundenen Vorfuehrdaten (Entwicklung, Bildschirmfotos, Tests).
const attrappe = bool.fromEnvironment('RW_ATTRAPPE');
