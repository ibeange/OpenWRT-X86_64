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

# 移除 SNAPSHOT 标签
sed -i 's,-SNAPSHOT,,g' include/version.mk
sed -i 's,-SNAPSHOT,,g' package/base-files/image-config.in

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

echo "🏷️ 修改系统菜单信息 / Modifying firmware version information..."

echo "修改一级菜单名称"
sed -i 's/"网络存储"/"存储"/g' `grep "网络存储" -rl ./`

echo "修改二级菜单名称"

#状态
sed -i '/"admin\/status\/processes"/,/"order"/ s/"order":[[:space:]]*2/"order": 3/' feeds/luci/modules/luci-mod-status/root/usr/share/luci/menu.d/luci-mod-status.json
sed -i '/"admin\/status\/iptables"/,/"order"/ s/"order":[[:space:]]*3/"order": 4/' feeds/luci/modules/luci-mod-status/root/usr/share/luci/menu.d/luci-mod-status.json
sed -i '/"admin\/status\/firewall"/,/"order"/ s/"order":[[:space:]]*3/"order": 4/' feeds/luci/modules/luci-mod-status/root/usr/share/luci/menu.d/luci-mod-status.json

#系统
sed -i 's/"系统"/"系统设置"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"管理权"/"权限管理"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"重启"/"立即重启"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"备份与更新"/"备份升级"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"挂载点"/"挂载路径"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"启动项"/"启动管理"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"软件包"/"软件管理"/g' feeds/luci/applications/luci-app-package-manager/po/zh_Hans/package-manager.po
sed -i 's/"终端"/"命令终端"/g' feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po

#服务
sed -i 's|("OpenClash"), 50)|("OpenClash"), 3)|g' customfeeds/lovepackages/luci-app-openclash/luasrc/controller/*.lua
sed -i 's/"Vlmcsd KMS 服务器"/"KMS服务"/g' $(grep "KMS 服务器" -rl ./)

#网络
sed -i 's/"接口"/"网络接口"/g' `grep "接口" -rl ./`
sed -i 's/"Bandix 流量监控"/"流量监控"/g' customfeeds/lovepackages/luci-app-bandix/luci-app-bandix/po/zh_Hans/bandix.po
sed -i 's/msgstr "UPnP IGD 和 PCP"/msgstr "UPnP服务"/g' feeds/luci/applications/luci-app-upnp/po/zh_Hans/upnp.po
sed -i 's/msgstr "SQM 队列管理"/msgstr "队列管理"/g' feeds/luci/applications/luci-app-sqm/po/zh_Hans/sqm.po
sed -i 's/msgstr "3cat"/msgstr "端口转发"/g' feeds/luci/applications/luci-app-3cat/po/zh_Hans/3cat.po

echo "✅ 系统菜单信息修改完成 / Firmware version information modified"

# 修改开源站地址
sed -i '54,56d;63d' scripts/projectsmirrors.json

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
