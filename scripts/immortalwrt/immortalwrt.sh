#!/bin/bash

# Clone community packages to package/community
mkdir package/community
pushd package/community

# Add openwrt-packages
git clone --depth=1 https://github.com/xuanranran/openwrt-package openwrt-package
git clone --depth=1 https://github.com/xuanranran/rely openwrt-rely
git clone --depth=1 https://github.com/immortalwrt/wwan-packages wwan-packages
chmod 755 openwrt-package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh
popd

# Update OpenClash Panel
pushd customfeeds/lovepackages/luci-app-openclash/root/usr/share/openclash/ui/
rm -rf yacd zashboard metacubexd/*
curl -sSL https://codeload.github.com/haishanh/yacd/zip/refs/heads/gh-pages -o yacd-dist-cdn-fonts.zip
curl -sSL https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz -o compressed-dist.tgz
curl -sSL https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages-cdn-fonts.zip -o dist-cdn-fonts.zip
tar zxf compressed-dist.tgz -C ./metacubexd
unzip -q dist-cdn-fonts.zip && unzip -q yacd-dist-cdn-fonts.zip
mv zashboard-gh-pages-cdn-fonts zashboard && mv yacd-gh-pages yacd
rm -rf yacd-dist-cdn-fonts.zip dist-cdn-fonts.zip compressed-dist.tgz
popd

# Change default shell to zsh
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# Modify default IP
sed -i 's/192.168.1.1/10.1.0.7/g' package/base-files/files/bin/config_generate
sed -i "s/ImmortalWrt/EthanWRT/g" package/base-files/files/bin/config_generate

# ===============================
# Modify firmware version branding
# ===============================

echo "🏷️ 修改固件版本信息 / Modifying firmware version information..."

# ===== 基本变量 =====
BUILD_DATE="$(date +%Y.%m.%d)"
FW_NAME="EthanWRT"
FW_VERSION="R${BUILD_DATE}"
FW_BUILDER="Compiled by Ethan"
FW_DESC="${FW_NAME} ${FW_VERSION} ${FW_BUILDER}"

echo "[DIY] Firmware description: ${FW_DESC}"

# -------------------------------
# 方法 1：修改 openwrt_release 模板（LuCI 右下角最关键）
# -------------------------------
if [ -f "package/base-files/files/etc/openwrt_release" ]; then
    sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='${FW_DESC}'/" \
        package/base-files/files/etc/openwrt_release
fi

# -------------------------------
# 方法 2：修改 include/version.mk（影响 RELEASE / 版本生成）
# -------------------------------
if [ -f "include/version.mk" ]; then
    sed -i "s/^RELEASE:=.*/RELEASE:=${FW_NAME} ${FW_VERSION}/" include/version.mk
    sed -i "s/^VERSION_REPO:=.*/VERSION_REPO:=${FW_BUILDER}/" include/version.mk
fi

# -------------------------------
# 方法 3：修改 Config-build.in 默认显示（低优先级，做兼容）
# -------------------------------
if [ -f "config/Config-build.in" ]; then
    sed -i "s/default \".*\"/default \"${FW_DESC}\"/" config/Config-build.in
fi

echo "✅ 固件版本信息修改完成 / Firmware version information modified"


sed -i 's/"网络存储"/"存储"/g' `grep "网络存储" -rl ./`

# 修改开源站地址
# sed -i '/@OPENWRT/a\\t\t"https://source.cooluc.com",' scripts/projectsmirrors.json
sed -i 's/mirror.iscas.ac.cn/mirrors.ustc.edu.cn/g' scripts/projectsmirrors.json
# sed -i '6,8d;15,18d;33,36d' scripts/projectsmirrors.json

sed -i 's/services/network/g' customfeeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json
sed -i 's/services/vpn/g' customfeeds/luci/applications/luci-app-frpc/root/usr/share/luci/menu.d/luci-app-frpc.json
sed -i 's/services/network/g' customfeeds/luci/applications/luci-app-3cat/root/usr/share/luci/menu.d/luci-app-3cat.json
sed -i 's/services/vpn/g' customfeeds/luci/applications/luci-app-tailscale-community/root/usr/share/luci/menu.d/luci-app-tailscale-community.json

# other
rm -rf target/linux/x86/base-files/etc/board.d/02_network
rm -rf package/base-files/files/etc/banner
cp -f $GITHUB_WORKSPACE/data/banner package/base-files/files/etc/banner
cp -f $GITHUB_WORKSPACE/data/02_network target/linux/x86/base-files/etc/board.d/02_network

echo -e "\n# Kernel - LRNG" >> .config
echo "CONFIG_KERNEL_LRNG=y" >> .config
echo "# CONFIG_PACKAGE_urandom-seed is not set" >> .config
echo "# CONFIG_PACKAGE_urngd is not set" >> .config

# Del luci-app-attendedsysupgrade
sed -i '18d' customfeeds/luci/collections/luci-nginx/Makefile
sed -i '17d' customfeeds/luci/collections/luci/Makefile
sed -i '16s/ \\$//' customfeeds/luci/collections/luci/Makefile
