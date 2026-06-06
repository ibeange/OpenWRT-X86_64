#!/bin/bash
set -Ee -o pipefail

#=================================================
# File name: preset-nikki-core.sh
# System Required: Linux
# Version: 1.0
# Lisence: MIT
# Author: LovinYarn
# github: https://github.com/xuanranran
#=================================================
mkdir -p files/etc/nikki/run/ui/metacubexd

GEOIP_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat"
GEOSITE_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"
GEOIP_METADB_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.metadb"
ASN_MMDB_URL="https://cdn.jsdelivr.net/gh/P3TERX/GeoLite.mmdb@download/GeoLite2-ASN.mmdb"

wget -qO files/etc/nikki/run/GeoIP.dat "$GEOIP_URL"
wget -qO files/etc/nikki/run/GeoSite.dat "$GEOSITE_URL"
wget -qO files/etc/nikki/run/geoip.metadb "$GEOIP_METADB_URL"
wget -qO files/etc/nikki/run/ASN.mmdb "$ASN_MMDB_URL"

test -s files/etc/nikki/run/GeoIP.dat
test -s files/etc/nikki/run/GeoSite.dat
test -s files/etc/nikki/run/geoip.metadb
test -s files/etc/nikki/run/ASN.mmdb

pushd files/etc/nikki/run/ui/
curl -fsSL https://codeload.github.com/haishanh/yacd/zip/refs/heads/gh-pages -o yacd-dist-cdn-fonts.zip
curl -fsSL https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz -o compressed-dist.tgz
curl -fsSL https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages-cdn-fonts.zip -o dist-cdn-fonts.zip
tar zxf compressed-dist.tgz -C ./metacubexd
unzip -q dist-cdn-fonts.zip && unzip -q yacd-dist-cdn-fonts.zip
mv zashboard-gh-pages-cdn-fonts zashboard && mv yacd-gh-pages yacd
rm -rf yacd-dist-cdn-fonts.zip dist-cdn-fonts.zip compressed-dist.tgz
popd

# mkdir -p files/etc/fchomo/
# wget -qO- $GEOIP_URL > files/etc/fchomo/geoip.dat
# wget -qO- $GEOSITE_URL > files/etc/fchomo/geosite.dat
# wget -qO- $ASN_MMDB_URL > files/etc/fchomo/asn.mmdb
