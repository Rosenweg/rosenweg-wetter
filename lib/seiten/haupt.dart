// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../quelle.dart';
import 'jetzt.dart';
import 'verlauf.dart';

/// Die App nach der Anmeldung: zwei Bereiche, „Jetzt“ (Live-Werte, Sonne und
/// Mond) und „Verlauf“ (Diagramme bis 7 Tage). Am Handy unten, ab 840 px
/// (Stationen) als Leiste links.
///
/// Eine [WetterQuelle] fuer beide Bereiche: eine MQTT-Verbindung, ein
/// 24-h-Verlauf, nachgeladen beim Oeffnen, beim Zurueckkommen und alle 5 min.
class Haupt extends StatefulWidget {
  const Haupt({super.key, required this.sitzung, this.echtzeit});
  final RosenwegSitzung sitzung;

  /// Fuer Tests und die Attrappe; sonst der Broker der Anlage.
  final EchtzeitQuelle? echtzeit;

  @override
  State<Haupt> createState() => _HauptState();
}

class _HauptState extends State<Haupt> {
  late final WetterQuelle _quelle = WetterQuelle(
    api: widget.sitzung.api,
    echtzeit: widget.echtzeit ?? RosenwegMqtt(wetterLeser, kennungVorsilbe: 'rwwetterapp'),
  );

  @override
  void dispose() {
    _quelle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sitzung = widget.sitzung;
    return BeimOeffnen(
      pruefen: _quelle.auffrischen,
      alle: const Duration(minutes: 5),
      child: RosenwegGeruest(
        titel: Text(sitzung.app.name),
        logo: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/logo/rosenweg-wetter-klein.png', semanticLabel: 'Logo'),
        ),
        aktionen: [_Menue(sitzung: sitzung)],
        ziele: [
          GeruestZiel(
            titel: 'Jetzt',
            symbol: Icons.wb_sunny_outlined,
            gewaehltSymbol: Icons.wb_sunny,
            seite: (_) => JetztSeite(quelle: _quelle),
          ),
          GeruestZiel(
            titel: 'Verlauf',
            symbol: Icons.show_chart_outlined,
            gewaehltSymbol: Icons.show_chart,
            seite: (_) => VerlaufSeite(quelle: _quelle),
          ),
        ],
      ),
    );
  }
}

/// Menue oben rechts: Anmeldung (echter Stand aus der Basis), Ueber, Abmelden.
/// Auf geteilten Telefonen meldet Rosenweg Geraet ab, dann gibt es den Punkt nicht.
class _Menue extends StatelessWidget {
  const _Menue({required this.sitzung});
  final RosenwegSitzung sitzung;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Mehr',
        onSelected: (w) async {
          switch (w) {
            case 'anmeldung':
              await zeigeAnmeldung(context, sitzung);
            case 'ueber':
              await zeigeUeber(context, sitzung.app);
            case 'abmelden':
              if (await frage(context, 'Abmelden?', 'Danach musst du dich neu anmelden.', ja: 'Abmelden')) {
                await sitzung.abmelden();
              }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'anmeldung', child: Text('Anmeldung: ${sitzung.name ?? 'angemeldet'}')),
          PopupMenuItem(value: 'ueber', child: Text('Über ${sitzung.app.name}')),
          if (!sitzung.geteiltesTelefon) const PopupMenuItem(value: 'abmelden', child: Text('Abmelden')),
        ],
      );
}
