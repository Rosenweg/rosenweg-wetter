#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# ============================================================================
# linux/paket/bauen.sh — Rosenweg Wetter als Debian-Paket
# ============================================================================
# Fuer die Stationen von Rosenweg OS (Debian 13, amd64), verteilt vom
# PXE-Server (os-stationen pakete/rosenweg-wetter/, Vorlage dafuer:
# linux/paket/paket.conf), und fuer eigene Debian-Rechner ueber /apps.
# Aus der App-Vorlage von rosenweg-basis (Muster: rosenweg-salz, rosenweg-vm).
#
#   linux/paket/bauen.sh              Werkzeuge, flutter build linux, Paket
#   linux/paket/bauen.sh --nur-paket  nur das Paket aus build/linux/x64/release/bundle
#   linux/paket/im-container.sh       im Bau-Container CT 141, siehe dort
#
# rosenweg_basis: im CI-Lauf ueber git (pubspec.yaml, oeffentlich); im
# Bau-Container aus ../rosenweg-basis (pubspec_overrides.yaml), das
# im-container.sh in der Fassung aus pubspec.yaml danebenlegt.
#
# Ergebnis: linux/paket/out/rosenweg-wetter_<version>_amd64.deb + Pruefsumme.
# ============================================================================
set -euo pipefail

HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WURZEL="$(cd "$HIER/../.." && pwd)"
cd "$WURZEL"

die() { echo "FEHLER: $*" >&2; exit 1; }
export LC_ALL=C.UTF-8
log() { echo "== $*"; }

NUR_PAKET=0
[ "${1:-}" = "--nur-paket" ] && NUR_PAKET=1

PAKET=rosenweg-wetter
PROGRAMM=rosenweg_wetter
ZIEL=/opt/rosenweg-wetter
BUENDEL="$WURZEL/build/linux/x64/release/bundle"

# pubspec 'version: 0.1.0+1' -> Debian '0.1.0-1' (Baunummer = Paketrevision)
APP_VERSION="$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\)+\([0-9]\+\).*/\1-\2/p' pubspec.yaml)"
[ -n "$APP_VERSION" ] || die "Keine Version 'x.y.z+n' in pubspec.yaml."
ARCH=amd64
DATEI="${PAKET}_${APP_VERSION}_${ARCH}.deb"

if [ -z "${RW_STAND:-}" ] && git -C "$WURZEL" rev-parse --git-dir >/dev/null 2>&1; then
    RW_STAND="$(git -C "$WURZEL" rev-parse --short=12 HEAD)"
    git -C "$WURZEL" diff --quiet HEAD -- 2>/dev/null || RW_STAND="$RW_STAND+geaendert"
    : "${SOURCE_DATE_EPOCH:=$(git -C "$WURZEL" log -1 --format=%ct)}"
fi
RW_STAND="${RW_STAND:-unbekannt}"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"

# Nur Debian 13 / amd64: dpkg-shlibdeps rechnet Paketnamen dieses Systems.
CODENAME="$(. /etc/os-release; echo "${VERSION_CODENAME:-}")"
[ "$CODENAME" = trixie ] || die "Gebaut wird auf Debian 13 (trixie), nicht auf ${CODENAME:-?}."
[ "$(dpkg --print-architecture)" = "$ARCH" ] || die "Nur $ARCH."

NOETIG="dpkg-dev binutils patchelf librsvg2-bin file lintian"
[ "$NUR_PAKET" -eq 1 ] || NOETIG="$NOETIG clang cmake ninja-build pkg-config xz-utils curl unzip git
        ca-certificates libgtk-3-dev liblzma-dev libstdc++-14-dev libsecret-1-dev libjsoncpp-dev"
fehlt=""
for p in $NOETIG; do dpkg -s "$p" >/dev/null 2>&1 || fehlt="$fehlt $p"; done
if [ -n "$fehlt" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        log "Installiere:$fehlt"
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        # shellcheck disable=SC2086
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends $fehlt >/dev/null
    else
        die "Es fehlen:$fehlt (als root ausführen oder von Hand installieren)."
    fi
fi

if [ "$NUR_PAKET" -eq 0 ]; then
    # shellcheck source=werkzeuge.env
    . "$HIER/werkzeuge.env"
    # Derselbe Cache wie rosenweg-vm: im Bau-Container liegt Flutter schon da.
    C="${RW_CACHE:-$HOME/.cache/rosenweg-vm-ci}"; mkdir -p "$C"
    if [ ! -x "$C/flutter-$FLUTTER_VERSION/bin/flutter" ]; then
        log "Lade Flutter $FLUTTER_VERSION"
        curl -fsSL -o "$C/flutter.txz" "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_$FLUTTER_VERSION-stable.tar.xz"
        echo "$FLUTTER_SHA256  $C/flutter.txz" | sha256sum -c --quiet -
        mkdir -p "$C/flutter-$FLUTTER_VERSION"
        tar -xJf "$C/flutter.txz" -C "$C/flutter-$FLUTTER_VERSION" --strip-components=1 --no-same-owner
        rm "$C/flutter.txz"
    fi
    export PATH="$C/flutter-$FLUTTER_VERSION/bin:$PATH"
    export PUB_CACHE="$C/pub-cache"
    export FLUTTER_SUPPRESS_ANALYTICS=true CI=true

    log "flutter build linux"
    flutter config --no-analytics --enable-linux-desktop >/dev/null
    flutter pub get >/dev/null
    flutter build linux --release
fi

[ -x "$BUENDEL/$PROGRAMM" ] || die "$BUENDEL/$PROGRAMM fehlt — erst bauen (ohne --nur-paket)."

log "Paket $DATEI"
ARBEIT="$HIER/arbeit"
BAUM="$ARBEIT/debian/$PAKET"
rm -rf "$ARBEIT" "$HIER/out"
mkdir -p "$BAUM$ZIEL" "$HIER/out"
cp -a "$BUENDEL/." "$BAUM$ZIEL/"

install -D -m 0755 "$HIER/rosenweg-wetter" "$BAUM/usr/bin/rosenweg-wetter"
install -D -m 0644 "$HIER/ch.rosenweg4303.wetter.desktop" "$BAUM/usr/share/applications/ch.rosenweg4303.wetter.desktop"

# Symbole: Detailstufe nach Groesse wie rosenweg-basis werkzeug/logo/erzeugen.sh
# (bis 40 px ohne Weg, bis 108 px vereinfacht).
L="$WURZEL/assets/logo"
for s in 16 22 24 32 48 64 96 128 256 512; do
    q="$L/rosenweg-wetter.svg"
    if [ "$s" -le 40 ]; then q="$L/rosenweg-wetter-winzig.svg"; elif [ "$s" -le 108 ]; then q="$L/rosenweg-wetter-klein.svg"; fi
    d="$BAUM/usr/share/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$d"
    rsvg-convert -w "$s" -h "$s" "$q" -o "$d/rosenweg-wetter.png"
done
install -D -m 0644 "$L/rosenweg-wetter.svg" "$BAUM/usr/share/icons/hicolor/scalable/apps/rosenweg-wetter.svg"

DOC="$BAUM/usr/share/doc/$PAKET"
install -d -m 0755 "$DOC"
{
    echo "Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/"
    echo "Upstream-Name: Rosenweg Wetter"
    echo "Source: https://github.com/Rosenweg/rosenweg-wetter"
    echo
    echo "Files: *"
    echo "Copyright: Rosenweg 4303"
    echo "License: GPL-3.0-or-later"
    echo " Der volle Text steht in /usr/share/common-licenses/GPL-3."
    echo " Lizenzen der eingebauten Dart-Pakete: in der App unter \"Über\" → Lizenzen."
} > "$DOC/copyright"
{
    echo "$PAKET ($APP_VERSION) trixie; urgency=medium"
    echo
    echo "  * Gebaut aus rosenweg-wetter $RW_STAND."
    echo
    echo " -- Rosenweg Technik <root@localhost>  $(LC_ALL=C date -u -R -d "@$SOURCE_DATE_EPOCH")"
} | gzip -9n > "$DOC/changelog.Debian.gz"

for so in "$BAUM$ZIEL"/lib/lib*_plugin.so; do
    [ -e "$so" ] || continue
    # shellcheck disable=SC2016
    patchelf --set-rpath '$ORIGIN' "$so"
done
for f in "$BAUM$ZIEL/$PROGRAMM" "$BAUM$ZIEL"/lib/lib*_plugin.so; do
    [ -e "$f" ] && strip --strip-unneeded --remove-section=.comment --remove-section=.note "$f"
done

install -d -m 0755 "$BAUM/usr/share/lintian/overrides"
cat > "$BAUM/usr/share/lintian/overrides/$PAKET" <<'EOF'
# Flutter-Buendel unter /opt, Engine mit eingebauten Bibliotheken, AOT-Code
# ohne NEEDED (Begruendung wie bei rosenweg-vm).
rosenweg-wetter: dir-or-file-in-opt [opt/rosenweg-wetter/*]
rosenweg-wetter: embedded-library * [opt/rosenweg-wetter/lib/libflutter_linux_gtk.so]
rosenweg-wetter: shared-library-lacks-prerequisites [opt/rosenweg-wetter/lib/libapp.so]
rosenweg-wetter: bogus-mail-host *
rosenweg-wetter: bogus-mail-host-in-debian-changelog *
rosenweg-wetter: root-in-contact *
rosenweg-wetter: initial-upload-closes-no-bugs *
rosenweg-wetter: no-manual-page [usr/bin/rosenweg-wetter]
EOF

find "$BAUM" -type d -exec chmod 0755 {} +
find "$BAUM" -type f -exec chmod 0644 {} +
chmod 0755 "$BAUM$ZIEL/$PROGRAMM" "$BAUM/usr/bin/rosenweg-wetter"

mkdir -p "$ARBEIT/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: %s\n' "$PAKET" "$PAKET" "$ARCH" > "$ARBEIT/debian/control"
mapfile -t ELF < <(find "$BAUM$ZIEL" -type f \( -name '*.so' -o -name "$PROGRAMM" \) | sort)
SHLIBS="$(cd "$ARBEIT" && dpkg-shlibdeps -O -l"$BAUM$ZIEL/lib" "${ELF[@]}" 2>"$ARBEIT/shlibdeps.log" \
          | sed -n 's/^shlibs:Depends=//p')"
[ -n "$SHLIBS" ] || { cat "$ARBEIT/shlibdeps.log" >&2; die "dpkg-shlibdeps ergab keine Abhängigkeiten."; }

# Zur Laufzeit (dlopen bzw. Programmaufruf, darum nicht in dpkg-shlibdeps):
# - Browser fuer die Anmeldung (xdg-open).
# - Stille Anmeldung mit dem Kerberos-Ticket der Sitzung: rosenweg_basis
#   laedt libgssapi_krb5.so.2 per FFI (Paket libgssapi-krb5-2).
# Gespeicherte Anmeldung braucht einen Secret-Service-Dienst; ohne ihn gilt
# sie bis Programmende (rosenweg_basis Schluesselbund) — darum nur empfohlen.
DEPENDS="$SHLIBS, libgssapi-krb5-2, xdg-utils"
RECOMMENDS="gnome-keyring"

GROESSE="$(du -sk --apparent-size "$BAUM" | cut -f1)"
install -d -m 0755 "$BAUM/DEBIAN"
cat > "$BAUM/DEBIAN/control" <<EOF
Package: $PAKET
Version: $APP_VERSION
Architecture: $ARCH
Maintainer: Rosenweg Technik <root@localhost>
Installed-Size: $GROESSE
Depends: $DEPENDS
Recommends: $RECOMMENDS
Section: utils
Priority: optional
Homepage: https://github.com/Rosenweg/rosenweg-wetter
Description: Rosenweg Wetter
 Wetterstation am Rosenweg 9: aktuelle Werte live, Verlauf bis 7 Tage, Sonne und Mond.
 Mit dem Rosenweg-Konto anmelden (an den Stationen still mit der
 Domänenanmeldung). Auf den Stationen aktualisiert os-stationen das Paket,
 auf anderen Debian-Rechnern die App selbst (Quelle: /apps).
 .
 Gebaut aus rosenweg-wetter $RW_STAND.
EOF
(cd "$BAUM" && find . -path ./DEBIAN -prune -o -type f -printf '%P\0' | sort -z | xargs -0 md5sum > DEBIAN/md5sums)
chmod 0644 "$BAUM/DEBIAN/control" "$BAUM/DEBIAN/md5sums"

dpkg-deb --root-owner-group -Zxz --build "$BAUM" "$HIER/out/$DATEI" >/dev/null
echo "$DATEI" > "$HIER/out/DATEI"

if command -v lintian >/dev/null 2>&1; then
    log "lintian"
    lintian --tag-display-limit 0 "$HIER/out/$DATEI" 2>&1 | sed 's/^/   /' || true
fi

echo
echo "Gebaut: $HIER/out/$DATEI ($(du -h "$HIER/out/$DATEI" | cut -f1))"
echo "Depends: $DEPENDS"
echo "VERSION=$APP_VERSION"
echo "SHA256_$ARCH=$(sha256sum "$HIER/out/$DATEI" | cut -d' ' -f1)"
