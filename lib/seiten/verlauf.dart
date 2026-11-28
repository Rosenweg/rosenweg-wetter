// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../quelle.dart';
import '../wetter_daten.dart';

/// „Verlauf“: je Messwert eine Karte mit den letzten 24 h; Antippen = gross
/// mit Zeitraum 1 h bis 7 Tage. Messwerte ohne Werte (oder die seit Stunden
/// stehen, weil der Aussensensor ausgefallen ist) stehen gesammelt unten in
/// einem Satz statt als leere Diagramme.
class VerlaufSeite extends StatelessWidget {
  const VerlaufSeite({super.key, required this.quelle});
  final WetterQuelle quelle;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: quelle,
        builder: (context, _) {
          if (!quelle.verlaufGeladen) return const LadeAnzeige(text: 'Lade Verlauf …');
          final fehler = quelle.verlaufFehler;
          if (fehler != null && quelle.verlauf24.isEmpty) {
            return FehlerAnzeige(text: fehlerText(fehler), nochmals: quelle.auffrischen);
          }
          final l = quelle.lage;
          final mit = <Feld>[], ohne = <Feld>[];
          for (final f in verlaufFelder) {
            final r = quelle.verlauf24[f.name];
            final ausgeblendet = l.aussenAusgefallen && f.aussen;
            (r == null || r.leer || ausgeblendet ? ohne : mit).add(f);
          }
          return RefreshIndicator(
            onRefresh: quelle.auffrischen,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (mit.isEmpty)
                  const _KeinVerlauf()
                else
                  LayoutBuilder(builder: (context, c) {
                    final spalten = c.maxWidth >= 720 && mit.length > 1 ? 2 : 1;
                    final breite = (c.maxWidth - (spalten - 1) * 12) / spalten;
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final f in mit)
                        SizedBox(width: breite, child: _Karte(feld: f, reihe: quelle.verlauf24[f.name]!, quelle: quelle)),
                    ]);
                  }),
                if (ohne.isNotEmpty && mit.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Hinweis(
                    'Ohne Werte in den letzten 24 Stunden: ${ohne.map((f) => f.titel).join(', ')}.'
                    '${l.aussenAusgefallen ? ' Der Aussensensor der Wetterstation liefert zurzeit nichts.' : ''}',
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _KeinVerlauf extends StatelessWidget {
  const _KeinVerlauf();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(Icons.show_chart, size: 48, color: f.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Noch kein Verlauf', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Die Wetterstation hat in den letzten 24 Stunden keine brauchbaren Werte geliefert.',
              style: t.bodyMedium?.copyWith(color: f.onSurfaceVariant), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _Karte extends StatelessWidget {
  const _Karte({required this.feld, required this.reihe, required this.quelle});
  final Feld feld;
  final Messreihe reihe;
  final WetterQuelle quelle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => VerlaufGross(feld: feld, quelle: quelle),
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(feld.symbol, size: 18, color: feld.farbe),
              const SizedBox(width: 8),
              Expanded(child: Text(feld.titel, style: t.titleSmall)),
              Text(reihe.text(reihe.letzter?.wert), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: f.onSurfaceVariant),
            ]),
            const SizedBox(height: 6),
            Kleinverlauf(reihe: reihe),
            const SizedBox(height: 4),
            Text(
              '24 h · tiefster ${reihe.text(reihe.kleinster)} · höchster ${reihe.text(reihe.groesster)}',
              style: t.bodySmall?.copyWith(color: f.onSurfaceVariant),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Ein Messwert gross, mit Zeitraum-Wahl (1 h … 7 Tage).
class VerlaufGross extends StatefulWidget {
  const VerlaufGross({super.key, required this.feld, required this.quelle});
  final Feld feld;
  final WetterQuelle quelle;

  @override
  State<VerlaufGross> createState() => _VerlaufGrossState();
}

class _VerlaufGrossState extends State<VerlaufGross> {
  Zeitraum _zeitraum = Zeitraum.kurz[2];
  Messreihe? _reihe;
  Object? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() {
      _fehler = null;
      _reihe = null;
    });
    try {
      final z = _zeitraum;
      final alle = await widget.quelle.verlaufLaden(z.dauer.inHours);
      if (mounted && z == _zeitraum) setState(() => _reihe = alle[widget.feld.name]);
    } catch (e) {
      if (mounted) setState(() => _fehler = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final r = _reihe;
    final jetzt = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(widget.feld.titel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ZeitraumWahl(
              gewaehlt: _zeitraum,
              geaendert: (z) {
                setState(() => _zeitraum = z);
                _laden();
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_fehler != null)
            SizedBox(height: 280, child: FehlerAnzeige(text: fehlerText(_fehler!), nochmals: _laden))
          else if (r == null)
            const SizedBox(height: 280, child: LadeAnzeige())
          else ...[
            Verlaufsdiagramm(
              reihe: r,
              von: jetzt.subtract(_zeitraum.dauer),
              bis: jetzt,
              hoehe: 300,
              nullLinie: widget.feld == regenrate || widget.feld == uv || widget.feld == sonne,
              leerText: 'Keine Werte in diesem Zeitraum.',
            ),
            const SizedBox(height: 12),
            if (!r.leer)
              Text(
                'jetzt ${r.text(r.letzter?.wert)} · tiefster ${r.text(r.kleinster)} · höchster ${r.text(r.groesster)}',
                textAlign: TextAlign.center,
                style: t.bodyMedium,
              ),
            const SizedBox(height: 4),
            Text('Antippen oder darüberfahren zeigt Zeit und Wert.',
                textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: f.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
