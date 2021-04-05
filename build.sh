#!/bin/bash
#
# This is free software, license use GPLv3.
#
# Copyright (c) 2021, teasiu
#

set -eu

proj_dir=$(pwd)

# clone openwrt
cd "$proj_dir"
rm -rf openwrt
git clone -b v19.07.7 https://github.com/openwrt/openwrt.git openwrt

# patch openwrt
cd "$proj_dir/openwrt"
cat "$proj_dir/patches"/*.patch | patch -p1

# obtain feed list
cd "$proj_dir/openwrt"
feed_list=$(awk '/^src-git/ { print $2 }' feeds.conf.default)

# clone feeds
cd "$proj_dir/openwrt"
./scripts/feeds update -a

# patch feeds
for feed in $feed_list; do
  [ -d "$proj_dir/patches/$feed" ] &&
    {
      cd "$proj_dir/openwrt/feeds/$feed"
      cat "$proj_dir/patches/$feed"/*.patch | patch -p1
    }
done

# modify firmware-info
cd "$proj_dir/openwrt"
Compile_Date=$(date +%Y%m%d)
AB_Firmware_Info=package/base-files/files/etc/openwrt_info
Openwrt_Version="R19.7.07-${Compile_Date}"
Owner_Repo="https://github.com/slitaz-cn/dragino2-19.07.7"
TARGET_PROFILE="dragino2"
Firmware_Type="bin"
echo "${Openwrt_Version}" > ${AB_Firmware_Info}
echo "${Owner_Repo}" >> ${AB_Firmware_Info}
echo "${TARGET_PROFILE}" >> ${AB_Firmware_Info}
echo "${Firmware_Type}" >> ${AB_Firmware_Info}

# addition packages
cd "$proj_dir/openwrt/package"
# luci-app-helloworld
svn co https://github.com/fw876/helloworld/trunk/luci-app-ssr-plus custom/luci-app-ssr-plus
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/shadowsocksr-libev custom/shadowsocksr-libev
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/pdnsd-alt custom/pdnsd-alt
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/microsocks custom/microsocks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/dns2socks custom/dns2socks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/simple-obfs custom/simple-obfs
svn co https://github.com/fw876/helloworld/trunk/tcping custom/tcping
svn co https://github.com/fw876/helloworld/trunk/xray-core custom/xray-core
svn co https://github.com/fw876/helloworld/trunk/xray-plugin custom/xray-plugin
svn co https://github.com/fw876/helloworld/trunk/shadowsocks-rust custom/shadowsocks-rust
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/v2ray-plugin custom/v2ray-plugin
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/trojan custom/trojan
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ipt2socks custom/ipt2socks
svn co https://github.com/fw876/helloworld/trunk/naiveproxy custom/naiveproxy
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/redsocks2 custom/redsocks2

svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/vlmcsd custom/vlmcsd
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-vlmcsd custom/luci-app-vlmcsd
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-ramfree custom/luci-app-ramfree
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-nfs custom/luci-app-nfs
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/wol custom/wol
svn co https://github.com/kenzok8/openwrt-packages/trunk/luci-app-aliddns custom/luci-app-aliddns
svn co https://github.com/teasiu/lede-other-apps/trunk/luci-app-autoupdate custom/luci-app-autoupdate
svn co https://github.com/teasiu/lede-other-apps/trunk/luci-app-admconf custom/luci-app-admconf
# luci-theme-argon
git clone -b v2.2.5 --depth 1 https://github.com/jerrykuku/luci-theme-argon.git custom/luci-theme-argon
#git clone https://github.com/xiaorouji/openwrt-passwall passwall
# clean up packages
cd "$proj_dir/openwrt/package"
find . -name .svn -exec rm -rf {} +
find . -name .git -exec rm -rf {} +

# zh_cn to zh_Hans
cd "$proj_dir/openwrt/package"
"$proj_dir/scripts/convert_translation.sh"

# install packages
cd "$proj_dir/openwrt"
./scripts/feeds install -a

# customize configs
cd "$proj_dir/openwrt"
cat "$proj_dir/config.seed" >.config
make defconfig

# build openwrt
cd "$proj_dir/openwrt"
make download -j8
make -j$(($(nproc) + 1)) || make -j1 V=s

# copy output files
cd "$proj_dir"
cp -a openwrt/bin/targets/*/* artifact
rm -rf artifact/packages

cd "$proj_dir"
cp -a artifact/openwrt-ar71xx-generic-dragino2-squashfs-sysupgrade.bin openwrt/bin/AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.${Firmware_Type}
rm -rf openwrt/bin/targets
rm -rf openwrt/bin/packages
cd "$proj_dir/openwrt/bin"
Legacy_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.${Firmware_Type}"
AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}"
if [ -f "${Legacy_Firmware}" ];then
			_MD5=$(md5sum ${Legacy_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${Legacy_Firmware} | cut -d ' ' -f1)
			touch ${AutoBuild_Firmware}.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${AutoBuild_Firmware}.detail
			echo "Legacy Firmware is detected !"
fi
