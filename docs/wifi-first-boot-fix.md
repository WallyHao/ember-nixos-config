# AX203 首次实机 Wi-Fi 故障与修正

2026-11-10。**首次实机启动已发生；Wi-Fi 故障已定位，修正构建通过，等待用户应用并实机复验。**

## 证据

- 用户回传的 Hearth 日志：Intel AX203 被识别，但在 14:41:36 加载 iwlwifi-so-a0-hr-b0-89.ucode 返回 -2，随后 no suitable firmware found。
- 当前 USB 系统同一设备正常工作，使用 iwlwifi、89.b20dcd1f.0 和 wpa_supplicant。
- 两套完整 firmware 树中的 -89.ucode.zst SHA256 完全一致，不是目标系统完全没有固件包。
- 实际解开旧 initrd：有 iwlwifi.ko，没有 iwlmvm.ko，也没有必需的 -89 固件。
- 两套内核的 modinfo 只为这个固件族通告 -100.ucode；Nix 的 makeModulesClosure 按模块元数据筛选 initrd 固件，不能自动包含该卡实际回退需要的 -89。

## 实现

AX203 不参与本机 NVMe 的根文件系统挂载。移出 initrd.availableKernelModules 的 iwlwifi，
改在完整根文件系统可用后通过 boot.kernelModules 加载 iwlwifi 与 iwlmvm。
保留原内核、固件包和锁定输入，避免为初始化时机问题盲目换内核或固件。
NetworkManager 明确使用 wpa_supplicant、powersave=false，对齐当前可用 USB 系统的 NM 设置；既有 TLP 策略继续保留。

锁定来源：nixpkgs f4a03c008967841f2a0b3cb7c436fc6fc31671f6 的
nixos/modules/system/boot/stage-1.nix、pkgs/build-support/kernel/modules-closure.sh、
nixos/modules/services/hardware/udev.nix（激活时配置完整固件搜索路径），以及 services/networking/networkmanager.nix。

## 已运行验证

- 新真实系统构建：/nix/store/8gwc837dnkvy66gh5y7c38irrmfywyaa-nixos-system-hearth-26.11.20261107.dirty。
- 实际解开新 initrd：不再含提前加载的 iwlwifi/iwlmvm；stage-2 modules-load 配置同时包含两个模块。
- 完整 firmware 树中必需的 -89 固件存在；新 NM 配置为 wpa_supplicant / wifi.powersave=2。
- just check exit 0，含格式、ShellCheck、路径/凭据扫描及负向自测、flake check --no-build。
- vm-offline-boot 实际 PASS，31.37 s；该 VM 没有真实无线硬件，不能证明实机扫描或认证通过。
- initrd 文件从 59354462 字节降为 50756981 字节；这是构建产物体积，不是实机内存/启动性能测试。

日志：/tmp/hearth-wifi-build.log、/tmp/hearth-wifi-check.log、/tmp/hearth-wifi-offline.log。
旧/新 initrd 清单分别保存在 /tmp/hearth-old-initrd-contents.txt、/tmp/hearth-wifi-new-initrd-contents.txt。

## 当前连接复用

用户明确要求复用当前可用 Wi-Fi。通过 NM D-Bus 只读取元数据找到当前连接对应的 keyfile；
该连接 autoconnect=yes、permissions 为空，可供新系统用户使用。
下一步由用户以 sudo 将这个文件原样复制到目标 /persist/etc/NetworkManager/system-connections，root:root 0600。
只复制当前连接，不复制其他旧系统配置，不读取或打印密码，不把连接凭据放入 Nix store 或仓库。
目标 NetworkManager 的 system-connections 持久化规则已存在。

## 应用与验证边界

目前目标 system profile 仍是第一代 w0k5...，尚未应用这次修正。禁止重新分区。
使用 nixos-install --root /mnt --system 上述新产物 --no-root-passwd --no-channel-copy 更新已挂载的目标，
保留已有 Btrfs、用户状态、密码与软件 profile。需要本地 sudo，助手不能代输密码。

下一次进入 Hearth 后检查：nmcli device status、nmcli device wifi list，
以及 journalctl -k 中 loaded firmware version / op_mode iwlmvm 是否成功。
已保存连接应由 NetworkManager 自动尝试连接；校园网门户认证或公网可达性仍需现场验证。
