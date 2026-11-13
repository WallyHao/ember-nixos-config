# 实机安装状态

2026-11-10。**INSTALLED / FIRST_BOOT_DONE / WIFI_FIX_APPLY_PENDING**。

用户已明确授权将当前配置安装到内置 NVMe；本地 sudo 命令由用户在终端执行。助手的进程仍无 sudo 权限。

已确认：

- 内置 NVMe 已有 HEARTH_EFI / hearth-esp 2 GiB FAT32 和 HEARTH_SYSTEM / hearth-system 约 474.9 GiB Btrfs。
- /mnt 为 tmpfs；/mnt/nix、/mnt/persist 分别挂载 @nix、@persist。当前 USB 系统仍运行在原盘。
- /mnt/nix/var/nix/profiles/system-1-link 指向 /nix/store/w0k5flkjlvril4419rqh219j7m883amx-nixos-system-hearth-26.11.20261107.dirty。
- 用户提供的 nixos-install 输出为 installation finished；已复制 systemd-boot/回退 EFI 文件，并创建 EFI 启动项。
- 用户提供的 bootctl list 显示目标 ESP 默认启动项指向对应 kernel/initrd 和同一 Hearth init store path。
- bootctl 的 Version string 警告明确为 accepting anyway；reported/absent 来自正在运行的固件/旧启动记录，不是目标 ESP 本地启动项缺失。
- userborn 配置包含 wallyhao UID 1000 和 nixbld 组；安装 chroot 中 nixbld 尚未创建的警告没有中断安装，实际组创建仍待首次启动。

安装收尾与首次启动：

- workstation closure 已使用单次 --no-check-sigs 成功复制。通过只读 local store 查询确认 254 个闭包路径已注册并存在；未永久修改签名策略。
- 配置仓库已保存到 /persist/home/wallyhao/Workspace/hearth-nixos-config，111 个文件逐一 SHA256 校验一致，目录 UID 1000（新系统为 wallyhao）。
- 系统闭包只读校验：1490 个依赖路径已在目标数据库注册，且目标磁盘文件存在；系统 profile 指向已构建产物。
- 退出所有 /mnt 下的终端后，用户可 sync、sudo umount -R /mnt，再关机。关机后再拔出 USB 并从内置盘启动；助手未执行关机或重启。
- 第一次登录后由 wallyhao 原生安装已缓存的软件 profile；见 first-boot.md。缓存就绪不等于 profile 已经安装。
- 实机图形、无线、显卡、省电、Keyring 改密等仍待实际进入系统验证。

首次登录步骤见 first-boot.md。不要再次运行分区程序；那会删除这次已经安装的系统。

## 首次实机反馈

用户已实际进入 Hearth，但 AX203 无法扫描网络。日志已定位为 initrd 固件缺失；修正已构建、尚未安装到目标，见 wifi-first-boot-fix.md。当前 profile 仍为第一代，下一步仅更新已安装系统和当前 Wi-Fi 连接，不重新分区。
