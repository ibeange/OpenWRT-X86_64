#!/bin/bash

# 颜色输出
color() {
    case "$1" in
        cr) echo -e "\e[1;31m${2}\e[0m" ;;  # 红色
        cg) echo -e "\e[1;32m${2}\e[0m" ;;  # 绿色
        cy) echo -e "\e[1;33m${2}\e[0m" ;;  # 黄色
        cb) echo -e "\e[1;34m${2}\e[0m" ;;  # 蓝色
        cp) echo -e "\e[1;35m${2}\e[0m" ;;  # 紫色
        cc) echo -e "\e[1;36m${2}\e[0m" ;;  # 青色
        cw) echo -e "\e[1;37m${2}\e[0m" ;;  # 白色
    esac
}

# 状态显示和时间统计
status_info() {
    local task_name="$1" begin_time=$(date +%s) exit_code time_info
    shift
    "$@"
    exit_code=$?
    [[ "$exit_code" -eq 99 ]] && return 0
    if [[ -n "$begin_time" ]]; then
        time_info="==> 用时 $(($(date +%s) - begin_time)) 秒"
    else
        time_info=""
    fi
    if [[ "$exit_code" -eq 0 ]]; then
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "⏳ $task_name") [ $(color cg ✔) ] $(color cw "$time_info")
    else
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "⏳ $task_name") [ $(color cr ✖) ] $(color cw "$time_info")
    fi
}

# 查找目录
find_dir() {
    find $1 -maxdepth 3 -type d -name "$2" -print -quit 2>/dev/null
}

# 打印信息
print_info() {
    printf "%s %-40s %s %s %s\n" "$1" "$2" "$3" "$4" "$5"
}

# 添加整个源仓库(git clone)
git_clone() {
    local repo_url branch target_dir current_dir
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    target_dir="${1:-${repo_url##*/}}"
    git clone -q $branch --depth=1 "$repo_url" "$target_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        return 1
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if [[ -d "$current_dir" ]]; then
        rm -rf "$current_dir"
        mv -f "$target_dir" "${current_dir%/*}"
        print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
    else
        mv -f "$target_dir" "$destination_dir"
        print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
    fi
}

# 添加源仓库内的指定目录
clone_dir() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        rm -rf "$temp_dir"
        return 1
    }
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [[ -d "$source_dir" ]] || \
        source_dir=$(find "$temp_dir" -maxdepth 4 -type d -name "$target_dir" -print -quit) && \
        [[ -d "$source_dir" ]] || {
            print_info $(color cr 查找) "$target_dir" [ $(color cr ✖) ]
            continue
        }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if [[ -d "$current_dir" ]]; then
            rm -rf "$current_dir"
            mv -f "$source_dir" "${current_dir%/*}"
            print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
        else
            mv -f "$source_dir" "$destination_dir"
            print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
        fi
    done
    rm -rf "$temp_dir"
}

# 添加源仓库内的所有子目录
clone_all() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        rm -rf "$temp_dir"
        return 1
    }
    process_dir() {
        while IFS= read -r source_dir; do
            local target_dir=$(basename "$source_dir")
            local current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
            if [[ -d "$current_dir" ]]; then
                rm -rf "$current_dir"
                mv -f "$source_dir" "${current_dir%/*}"
                print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
            else
                mv -f "$source_dir" "$destination_dir"
                print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
            fi
        done < <(find "$1" -maxdepth 1 -mindepth 1 -type d ! -name '.*')
    }
    if [[ $# -eq 0 ]]; then
        process_dir "$temp_dir"
    else
        for dir_name in "$@"; do
            [[ -d "$temp_dir/$dir_name" ]] && process_dir "$temp_dir/$dir_name" || \
            print_info $(color cr 目录) "$dir_name" [ $(color cr ✖) ]
        done
    fi
    rm -rf "$temp_dir"
}

# Clone community packages to package/community
mkdir package/community
pushd package/community

# Add openwrt-packages
git clone --depth=1 https://github.com/xuanranran/openwrt-package openwrt-package
git clone --depth=1 https://github.com/xuanranran/rely openwrt-rely
git clone --depth=1 https://github.com/immortalwrt/wwan-packages wwan-packages
chmod 755 openwrt-package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh
popd

# v2ray-server
rm -rf feeds/luci/applications/luci-app-v2ray-server
clone_dir https://github.com/kiddin9/kwrt-packages luci-app-v2ray-server
clone_dir https://github.com/sbwml/openwrt_helloworld xray-core
# 调整 V2ray服务器 到 VPN 菜单 (修正路径)
sed -i 's/services/vpn/g' package/community/luci-app-v2ray-server/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/community/luci-app-v2ray-server/luasrc/model/cbi/v2ray_server/*.lua
sed -i 's/services/vpn/g' package/community/luci-app-v2ray-server/luasrc/view/v2ray_server/*.htm

# UU游戏加速器
clone_dir https://github.com/kiddin9/kwrt-packages luci-app-uugamebooster
clone_dir https://github.com/kiddin9/kwrt-packages uugamebooster

# 关机
clone_all https://github.com/sirpdboy/luci-app-poweroffdevice

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
sed -i "s/ImmortalWrt/Ethan/g" package/base-files/files/bin/config_generate

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
