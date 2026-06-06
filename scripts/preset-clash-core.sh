#!/bin/bash
set -Ee -o pipefail

mkdir -p files/etc/openclash/core

CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/meta/clash-linux-${1}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
ASN_MMDB_URL="https://cdn.jsdelivr.net/gh/P3TERX/GeoLite.mmdb@download/GeoLite2-ASN.mmdb"
Model_bin_URL="https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin"


wget -qO- "$CLASH_META_URL" | tar xOvz > files/etc/openclash/core/clash_meta
wget -qO files/etc/openclash/GeoIP.dat "$GEOIP_URL"
wget -qO files/etc/openclash/GeoSite.dat "$GEOSITE_URL"
wget -qO files/etc/openclash/ASN.mmdb "$ASN_MMDB_URL"
wget -qO files/etc/openclash/Model.bin "$Model_bin_URL"

test -s files/etc/openclash/core/clash_meta
test -s files/etc/openclash/GeoIP.dat
test -s files/etc/openclash/GeoSite.dat
test -s files/etc/openclash/ASN.mmdb
test -s files/etc/openclash/Model.bin

chmod +x files/etc/openclash/core/clash*
