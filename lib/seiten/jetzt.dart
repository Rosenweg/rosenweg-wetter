// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../quelle.dart';
import '../sonne_mond.dart';
import '../wetter_daten.dart';

/// „Jetzt“: Temperatur gross, darunter nur die Werte, die die Station gerade
/// wirklich liefert, dann Sonne und Mond (gerechnet, gehen immer).
class JetztSeite extends StatefulWidget {
  const JetztSeite({super.key, required this.quelle, this.jetzt});
  final WetterQuelle quelle;

  /// Uhr (Tests, Bildschirmfotos).
  final DateTime Function()? jetzt;

  @override
  State<JetztSeite> createState() => _JetztSeiteState();
}

class _JetztSeiteState extends State<JetztSeite> {
  Timer? _minute;

  DateTime get _jetzt => (widget.jetzt ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    // Sonnenstand und Tag/Nacht jede Minute nachfuehren
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.quelle,
        builder: (context, _) {
          final q = widget.quelle;
          final l = q.lage;
          return RefreshIndicator(
            onRefresh: q.auffrischen,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Kopf(lage: l, quelle: q, jetzt: _jetzt),
                const SizedBox(height: 12),
                if (q.wartet)
                  const Padding(padding: EdgeInsets.all(24), child: LadeAnzeige(text: 'Verbinde mit der Wetterstation …'))
                else ...[
                  if (l.ersatz != null) ...[
                    Hinweis(
                      '${l.ersatz!.hinweis}. Die Wetterstation am Rosenweg 9 liefert zurzeit keine brauchbaren Werte; '
                      'die Werte stammen von einer Messstation'
                      '${l.ersatz!.abstandKm != null ? ' rund ${l.ersatz!.abstandKm!.round()} km' : ''} entfernt und können abweichen.',
                      art: HinweisArt.warnung,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (l.aussenAusgefallen) ...[
                    Hinweis(
                      'Der Aussensensor der Wetterstation liefert zurzeit keine Werte'
                      '${l.ausgefallenSeit != null ? ' (seit mindestens ${_dauer(l.ausgefallenSeit!)} unverändert)' : ''}. '
                      'Temperatur, Wind, Sonne und Regen sind deshalb ausgeblendet.',
                      art: HinweisArt.warnung,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (l.leer) ...[const _Leer(), const SizedBox(height: 12)],
                  for (final (titel, symbol, felder) in gruppen)
                    if (felder.any((f) => l[f] != null)) ...[
                      Abschnitt(
                        titel: titel,
                        symbol: symbol,
                        kind: LayoutBuilder(builder: (context, c) {
                          // so viele Spalten wie passen (mind. 2), Kacheln fuellen die Breite
                          final n = ((c.maxWidth + 8) / 168).floor().clamp(2, 6);
                          final breite = (c.maxWidth - (n - 1) * 8) / n;
                          return Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final f in felder)
                              if (l[f] != null) SizedBox(width: breite, child: _Kachel(feld: f, wert: l[f]!, lage: l)),
                          ]);
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
                _SonneMond(jetzt: _jetzt),
                const SizedBox(height: 8),
                Text(
                  l.ersatz == null
                      ? 'Wetterstation Rosenweg 9, Kaiseraugst. Berechnete Werte ohne Gewähr.'
                      : 'Ersatzwerte: Quelle MeteoSchweiz (Open Government Data), Station ${l.ersatz!.stationText}. Berechnete Werte ohne Gewähr.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      );
}

class _Kopf extends StatelessWidget {
  const _Kopf({required this.lage, required this.quelle, required this.jetzt});
  final Lage lage;
  final WetterQuelle quelle;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final temp = lage[temperatur];
    final rh = lage[feuchte];
    final gef = gefuehlt(temp, rh, lage[wind]);
    final tau = taupunkt(temp, rh);
    final tag = sonnenhoehe(jetzt) > 0;
    final sol = lage[sonne];
    final (symbol, himmel) = !tag
        ? (Icons.nightlight_round, 'Nacht')
        : sol == null
            ? (Icons.wb_sunny_outlined, 'Tag')
            : sol > 400
                ? (Icons.wb_sunny, 'sonnig')
                : sol > 80
                    ? (Icons.wb_cloudy_outlined, 'leicht bewölkt')
                    : (Icons.cloud_outlined, 'bewölkt');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(symbol, size: 56, color: tag ? const Color(0xFFCA8A04) : f.primary, semanticLabel: himmel),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (temp != null) ...[
                  Text(temperatur.text(temp), style: t.displayMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      'Aussentemperatur',
                      if (gef != null && gef.art != 'wie gemessen') 'gefühlt ${temperatur.text(gef.wert)} (${gef.art})',
                    ].join(' · '),
                    style: t.bodyMedium,
                  ),
                  if (tau != null)
                    Text('Taupunkt ${temperatur.text(tau)}${temp - tau < 2.5 ? ' · Nebel oder Tau möglich' : ''}',
                        style: t.bodySmall?.copyWith(color: f.onSurfaceVariant)),
                ] else ...[
                  Text('Keine aktuelle Temperatur', style: t.titleLarge),
                  Text('Die Wetterstation meldet gerade keine Aussentemperatur.',
                      style: t.bodyMedium?.copyWith(color: f.onSurfaceVariant)),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          EchtzeitAnzeige(quelle: quelle.echtzeit, veraltetNach: const Duration(minutes: 10)),
        ]),
      ),
    );
  }
}

class _Leer extends StatelessWidget {
  const _Leer();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: f.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Die Wetterstation liefert gerade keine Werte.', style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Sobald wieder Werte ankommen, erscheinen sie hier von selbst.',
              style: t.bodyMedium?.copyWith(color: f.onSurfaceVariant), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({required this.feld, required this.wert, required this.lage});
  final Feld feld;
  final double wert;
  final Lage lage;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final hinweis = feld == blitze ? _letzterBlitz(lage) : hinweisZu(feld, wert, lage);
    return Semantics(
      container: true,
      label: '${feld.titel}: ${feld.text(wert)}${hinweis != null ? ', $hinweis' : ''}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: f.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(feld.symbol, size: 16, color: f.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(feld.titel, style: t.labelMedium?.copyWith(color: f.onSurfaceVariant), maxLines: 2)),
            ]),
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: feld.text(wert, einheitDazu: false), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (feld.einheit.isNotEmpty) TextSpan(text: ' ${feld.einheit}', style: t.bodyMedium),
            ])),
            if (hinweis != null) Text(hinweis, style: t.bodySmall?.copyWith(color: f.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  static String? _letzterBlitz(Lage l) {
    final s = int.tryParse(l.texte['lightning_time'] ?? '');
    if (s == null || s <= 0) return null;
    return 'zuletzt ${zeitpunktText(DateTime.fromMillisecondsSinceEpoch(s * 1000))}';
  }
}

class _SonneMond extends StatelessWidget {
  const _SonneMond({required this.jetzt});
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final s = sonnenzeiten(jetzt);
    final m = mondphase(jetzt);
    String uhr(DateTime? d) => d == null ? '–' : zeitpunktText(d, jetzt: d);
    final a = s.aufgang, u = s.untergang;
    final laenge = a != null && u != null ? u.difference(a) : null;
    return Abschnitt(
      titel: 'Sonne und Mond',
      symbol: Icons.wb_twilight,
      erklaerung: 'Gerechnet für Kaiseraugst, nicht gemessen.',
      kind: Column(children: [
        ListTile(
          leading: const Icon(Icons.wb_twilight),
          title: Text('Aufgang ${uhr(a)} · Untergang ${uhr(u)}'),
          subtitle: laenge == null ? null : Text('Tageslänge ${laenge.inHours} h ${laenge.inMinutes % 60} min'),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(mondphaseName(m.phase)),
          subtitle: Text('${(m.anteil * 100).round()} % beleuchtet'),
        ),
      ]),
    );
  }
}

/// „26 Stunden“, „3 Tagen“ (Dativ, nach „seit mindestens“).
String _dauer(Duration d) {
  if (d.inHours < 48) return '${d.inHours} Stunden';
  return '${d.inDays} Tagen';
}
