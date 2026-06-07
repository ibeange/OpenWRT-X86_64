#!/bin/bash
set -Ee -o pipefail

# Clone community packages to package/community
mkdir package/community
pushd package/community

# Add openwrt-packages
git clone --depth=1 https://github.com/xuanranran/openwrt-package openwrt-package
git clone --depth=1 https://github.com/xuanranran/rely openwrt-rely
git clone --depth=1 https://github.com/immortalwrt/wwan-packages wwan-packages
if [ -f openwrt-package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh ]; then
    chmod 755 openwrt-package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh
else
    echo "Info: luci-app-onliner setnlbw.sh not found, skipping chmod."
fi
popd

# Update OpenClash Panel
pushd customfeeds/lovepackages/luci-app-openclash/root/usr/share/openclash/ui/
rm -rf yacd zashboard metacubexd/*
curl -fsSL https://codeload.github.com/haishanh/yacd/zip/refs/heads/gh-pages -o yacd-dist-cdn-fonts.zip
curl -fsSL https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz -o compressed-dist.tgz
curl -fsSL https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages-cdn-fonts.zip -o dist-cdn-fonts.zip
tar zxf compressed-dist.tgz -C ./metacubexd
unzip -q dist-cdn-fonts.zip && unzip -q yacd-dist-cdn-fonts.zip
mv zashboard-gh-pages-cdn-fonts zashboard && mv yacd-gh-pages yacd
rm -rf yacd-dist-cdn-fonts.zip dist-cdn-fonts.zip compressed-dist.tgz
popd

# Change default shell to zsh
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# Modify default IP
sed -i 's/192.168.1.1/10.1.0.1/g' package/base-files/files/bin/config_generate
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
FW_STATUS_DESC="ImmortalWrt SNAPSHOT ${FW_BUILDER} ${FW_VERSION}"
FW_FOOTER_DESC="${FW_NAME} ${FW_VERSION} ${FW_BUILDER}"

export FW_VERSION FW_BUILDER FW_STATUS_DESC FW_FOOTER_DESC

echo "[DIY] Status firmware version: ${FW_STATUS_DESC} / <compiled LuCI branch and short version>"
echo "[DIY] Footer version: Powered by <compiled LuCI branch> (<compiled LuCI short version>) / ${FW_FOOTER_DESC}"

# -------------------------------
# 方法 1：修改版本配置与 openwrt_release 模板
# -------------------------------
python3 <<'PY'
import os
from pathlib import Path

fw_version = os.environ["FW_VERSION"]
fw_builder = os.environ["FW_BUILDER"]
fw_status_desc = os.environ["FW_STATUS_DESC"]
fw_footer_desc = os.environ["FW_FOOTER_DESC"]

def update_key_value(path, values):
    path = Path(path)
    if not path.exists():
        return
    lines = path.read_text().splitlines()
    seen = set()
    out = []
    for line in lines:
        key = line.split("=", 1)[0]
        if key in values:
            out.append(f"{key}={values[key]}")
            seen.add(key)
        else:
            out.append(line)
    for key, value in values.items():
        if key not in seen:
            out.append(f"{key}={value}")
    path.write_text("\n".join(out) + "\n")

update_key_value(".config", {
    "CONFIG_VERSION_DIST": '"ImmortalWrt"',
    "CONFIG_VERSION_NUMBER": '"SNAPSHOT"',
    "CONFIG_VERSION_CODE": f'"{fw_builder} {fw_version}"',
})

update_key_value("package/base-files/files/etc/openwrt_release", {
    "DISTRIB_ID": "'ImmortalWrt'",
    "DISTRIB_RELEASE": "'SNAPSHOT'",
    "DISTRIB_REVISION": f"'{fw_builder} {fw_version}'",
    "DISTRIB_DESCRIPTION": f"'{fw_status_desc}'",
})

for root in ("customfeeds", "feeds", "package"):
    base = Path(root)
    if not base.exists():
        continue

    for path in base.glob("**/luci-base/src/Makefile"):
        text = path.read_text()
        old = "echo \"export const revision = '$(LUCI_VERSION)', branch = '$(LUCI_GITBRANCH)';\" > $@"
        new = "echo \"export const revision = '$$(printf '%s\\n' '$(LUCI_VERSION)' | cut -d. -f1,2)', branch = '$(LUCI_GITBRANCH)';\" > $@"
        if old in text:
            path.write_text(text.replace(old, new))

    for path in base.glob("**/luci-lua-runtime/src/mkversion.sh"):
        text = path.read_text()
        if "short_luciversion=" not in text:
            text = text.replace(
                "cat <<EOF > $1",
                "short_luciversion=\"$(printf '%s\\n' \"${2:-Git}\" | cut -d. -f1,2)\"\ncat <<EOF > $1",
            )
        text = text.replace('luciversion = "${2:-Git}"', 'luciversion = "${short_luciversion}"')
        path.write_text(text)

footer_line = f"Powered by {{{{ version.luciname }}}} ({{{{ version.luciversion }}}}) / {fw_footer_desc}"

for root in ("customfeeds", "feeds", "package"):
    base = Path(root)
    if not base.exists():
        continue

    for path in base.glob("**/ucode/template/themes/**/footer.ut"):
        text = path.read_text()
        original = text

        if "themes/bootstrap/footer.ut" in str(path):
            start = text.find("\t\t\t<span>")
            end = text.find("\t\t\t</span>", start)
            if start != -1 and end != -1:
                replacement = (
                    "\t\t\t<span>\n"
                    f"\t\t\t\t{footer_line}\n"
                    "\t\t\t</span>"
                )
                text = text[:start] + replacement + text[end + len("\t\t\t</span>"):]

        elif "themes/material/footer.ut" in str(path):
            lines = text.splitlines()
            out = []
            skip_next = False
            for line in lines:
                if skip_next:
                    skip_next = False
                    continue
                if "Powered by {{ version.luciname }}" in line:
                    indent = line[:len(line) - len(line.lstrip())]
                    out.append(f"{indent}{footer_line}")
                    skip_next = "version.distname" not in line
                elif "version.distname" in line:
                    continue
                else:
                    out.append(line)
            text = "\n".join(out) + "\n"

        elif "themes/argon/footer.ut" in str(path):
            lines = text.splitlines()
            out = []
            skip_theme_separator = False
            for line in lines:
                if "Powered by {{ version.luciname }}" in line:
                    indent = line[:len(line) - len(line.lstrip())]
                    out.append(f"{indent}<span class=\"luci-link\">{footer_line}</span>")
                    skip_theme_separator = True
                elif skip_theme_separator and (
                    "footer-separator" in line
                    or "ArgonTheme" in line
                    or "version.distname" in line
                ):
                    continue
                else:
                    out.append(line)
            text = "\n".join(out) + "\n"

        elif "Powered by {{ version.luciname }}" in text:
            text = text.replace(
                "Powered by {{ version.luciname }} ({{ version.luciversion }})",
                footer_line,
            )

        if text != original:
            path.write_text(text)
PY

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
find customfeeds package feeds -path '*/luci-app-netdata/root/usr/share/luci/menu.d/luci-app-netdata.json' -type f \
    -exec sed -i 's/"title": "Netdata"/"title": "网络监控"/g' {} +
find customfeeds package feeds -path '*/luci-app-netdata/po/zh_Hans/netdata.po' -type f \
    -exec sed -i '/msgid "Netdata"/{n;s/msgstr "Netdata"/msgstr "网络监控"/;}' {} +
find customfeeds package feeds -path '*/root/usr/share/luci/menu.d/*.json' -type f \
    -exec sed -i '/"admin\/system\/plugins"/,/"title"/ s/"title": "[^"]*"/"title": "鉴权扩展"/' {} +
find customfeeds package feeds -path '*/po/zh_Hans/*.po' -type f \
    -exec sed -i '/msgid "Plugins\?"/{n;s/msgstr "插件"/msgstr "鉴权扩展"/;}' {} +
find customfeeds package feeds -path '*/root/usr/share/luci/menu.d/*.json' -type f \
    -exec sed -i '/"admin\/system\/poweroffdevice"/,/"title"/ s/"title": "[^"]*"/"title": "立即关机"/' {} +
find customfeeds package feeds -path '*/po/zh_*.po' -type f \
    -exec sed -i '/msgid "关机"/{n;s/msgstr "关机"/msgstr "立即关机"/;}' {} +
find customfeeds package feeds -path '*/luci-app-cloudflared/root/usr/share/luci/menu.d/luci-app-cloudflared.json' -type f \
    -exec sed -i 's/"title": "Cloudflare Zero Trust Tunnel"/"title": "Cloudflare 零信任隧道"/g' {} +
find customfeeds package feeds -path '*/luci-app-cloudflared/po/zh_Hans/cloudflared.po' -type f \
    -exec sed -i '/msgid "Cloudflare Zero Trust Tunnel"/{n;s/msgstr ".*"/msgstr "Cloudflare 零信任隧道"/;}' {} +

#服务
python3 <<'PY'
import json
from pathlib import Path

orders = {
    "admin/services/udpxy": 10,
    "admin/services/udproxy": 10,
    "admin/services/nikki": 20,
    "admin/services/momo": 30,
    "admin/services/lucky": 40,
    "admin/services/mosdns": 50,
    "admin/services/msd_lite": 60,
    "admin/services/msd-lite": 60,
    "admin/services/rtp2httpd": 60,
    "admin/services/vlmcsd": 70,
    "admin/services/openclash": 80,
}

for root in ("customfeeds", "package", "feeds"):
    base = Path(root)
    if not base.exists():
        continue
    for path in base.glob("**/root/usr/share/luci/menu.d/*.json"):
        try:
            data = json.loads(path.read_text())
        except Exception:
            continue
        changed = False
        for menu_path, order in orders.items():
            item = data.get(menu_path)
            if isinstance(item, dict):
                item["order"] = order
                changed = True
        if changed:
            path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
PY
sed -i 's|("OpenClash"), [0-9]\+)|("OpenClash"), 80)|g' customfeeds/lovepackages/luci-app-openclash/luasrc/controller/*.lua
sed -i 's/"Vlmcsd KMS 服务器"/"KMS服务"/g' $(grep "KMS 服务器" -rl ./)

#网络
sed -i 's/"接口"/"网络接口"/g' `grep "接口" -rl ./`
find feeds customfeeds package -path '*/luci-mod-network/root/usr/share/luci/menu.d/luci-mod-network.json' -type f \
    -exec sed -i '/"admin\/network\/routes"/,/"title"/ s/"title": "[^"]*"/"title": "网络路由"/' {} +
find feeds customfeeds package -path '*/luci-mod-network/po/zh_Hans/network.po' -type f \
    -exec sed -i '/msgid "Routing"/{n;s/msgstr "路由"/msgstr "网络路由"/;}' {} +
find customfeeds package feeds -path '*/luci-app-bandix/root/usr/share/luci/menu.d/luci-app-bandix.json' -type f \
    -exec sed -i '/"admin\/network\/bandix"/,/"title"/ s/"title": "[^"]*"/"title": "流量监控"/' {} +
if [ -f customfeeds/lovepackages/luci-app-bandix/po/zh_Hans/bandix.po ]; then
    sed -i 's/"Bandix 流量监控"/"流量监控"/g;s/msgstr "Bandix"/msgstr "流量监控"/g' customfeeds/lovepackages/luci-app-bandix/po/zh_Hans/bandix.po
else
    echo "Info: luci-app-bandix zh_Hans translation not found, skipping rename."
fi
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
