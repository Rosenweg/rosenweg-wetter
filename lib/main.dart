// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

import 'app.dart';
import 'attrappe.dart';
import 'seiten/haupt.dart';

/// rosenwegStarten (rosenweg_basis): Logdatei, Fehlerfang, Anmeldung
/// (Anmeldeschirm mit Karte, QR, Konto; an Stationen still per Kerberos;
/// auf geteilten Telefonen ueber Rosenweg Geraet) und der Updater
/// (aus auf Rosenweg-Stationen, Android, iOS). Erst danach kommt [Haupt].
void main() {
  final a = attrappe ? Attrappe(ausfall: attrappeAusfall) : null;
  rosenwegStarten(
    appAngaben,
    (sitzung) => Haupt(sitzung: sitzung, echtzeit: a?.echtzeit()),
    sitzung: a != null ? RosenwegSitzung(appAngaben, transport: a) : null,
  );
}
