#!/usr/bin/env bash
# Writes docs/appcast.xml, the Sparkle update feed served by GitHub Pages.
# It lists only the newest release: the notarized zip, signed with the
# EdDSA key in the login keychain (account "leftovers").
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
SIGNATURE=$(.build/artifacts/sparkle/Sparkle/bin/sign_update --account leftovers dist/Leftovers.zip)
URL="https://github.com/arpwal/leftovers/releases/download/v$VERSION/Leftovers.zip"
# The short plain-language notes, shown inside Sparkle's update window.
NOTES_HTML="<ul>$(sed -n 's/^- \(.*\)$/<li>\1<\/li>/p' dist/notes.md 2>/dev/null | tr -d '\n')</ul>"
cat > docs/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Leftovers</title>
    <link>https://arpwal.github.io/leftovers/</link>
    <item>
      <title>Leftovers $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[$NOTES_HTML<p><a href="https://github.com/arpwal/leftovers/blob/main/CHANGELOG.md">All changes</a></p>]]></description>
      <enclosure url="$URL" $SIGNATURE type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
echo "Wrote docs/appcast.xml (v$VERSION, build $BUILD)"
