# Phase 1 decisions

Locked nixpkgs source: `f4a03c008967841f2a0b3cb7c436fc6fc31671f6`
(`nixos-unstable`), release `26.11`. Local source inspected during
implementation at `/nix/store/02h6ym8j8qvxpjps56n9gx4gxqpg26a0-source`.
Preservation source: commit `00be7f7dd1a11ae0605386f2272288de7cf33abe`.
Disko source: commit `cedd626e11b635470fa6f9fdb8ad79b0075dd7f9`.

| Topic | Local file | Upstream option / source | Value | Verification |
| --- | --- | --- | --- | --- |
| State baseline | `inventory/default.nix` | `nixos/modules/misc/version.nix`; locked `.version = 26.11` | `26.11` literal | eval contract `identity-system`; no dynamic release expression |
| Hostname | `modules/nixos/identity.nix` | `networking.hostName` | inventory `hearth` | eval contract `identity-host` |
| User/UID/home | `inventory/default.nix` | `users.users` | `wallyhao`, 1000, `/home/wallyhao` | eval contract `identity-user`, VM `id -u` |
| Login shell | `modules/nixos/accounts.nix` | `programs.zsh.enable`, `users.users.<name>.shell` | `pkgs.zsh`; empty `~/.zshrc` via tmpfiles suppresses the zsh new-user wizard | eval contract `identity-shell`, VM `getent passwd` and login |
| Initial password | `users/wallyhao/bootstrap-password.nix` | `users.users.<name>.initialHashedPassword` | provided SHA-512 crypt hash; no plaintext option | hash prefix check; VM PAM login |
| Account backend | `modules/nixos/accounts.nix` | `nixos/modules/services/system/userborn.nix`: `passwordFilesLocation`, `importLegacyState` | userborn on, `/var/lib/nixos`, legacy import off, `mutableUsers = true` | eval `accounts-userborn`; patched PAM + account VM: initial login, passwd, two reboots, three userborn restarts, old-password rejection |
| Root/sudo | `modules/nixos/accounts.nix` | `users.users.root.hashedPassword`, `security.sudo.wheelNeedsPassword` | root `"!"`, wheel needs password, no autologin | eval `accounts-password`; VM `passwd -S root`, sudo |
| Boot loader | `modules/nixos/boot.nix` | `boot.loader.systemd-boot.*`, `boot.loader.timeout` | systemd-boot, timeout 0, limit 5, GRUB off | eval `boot-loader`; VM boots GPT/ESP layout |
| Initrd | `modules/nixos/boot.nix` | locked `systemd/initrd.nix`: scripted initrd removed; `boot.initrd.systemd.*` only | rely on the only initrd mode; no obsolete enable switch | eval `boot-initrd`; persistence VM |
| Initrd Btrfs | `hosts/laptop/hardware.nix`, `tests/fixtures/hardware.nix` | `boot.initrd.availableKernelModules` | include `btrfs` and `crc32c` for the virtual/preview Btrfs layout | VM boot; first VM run failed without `crc32c` |
| Default target | `suites/nixos/laptop.nix` | `systemd.defaultUnit` | `multi-user.target`, no autologin | eval `boot-default-target` |
| TLP | `modules/nixos/power.nix`, `hosts/laptop/power.nix` | `services/hardware/tlp.nix`, TLP settings names | TLP on, pd off; AC/BAT governor, EPP, platform profile, runtime PM | eval `power-*`; hardware effect NOT_MEASURED |
| Other power daemons | `modules/nixos/power.nix` | `power-profiles-daemon`, `auto-cpufreq`, `tuned` | all off; assertion rejects TLP+PPD | eval `power-exclusive`; negative `tlp-with-ppd` |
| NVIDIA | `hosts/laptop/hardware.nix` | `hardware/video/nvidia.nix` | enabled, open module, modesetting, PRIME offload, fine-grained RTD3; no sync/reverse-sync | eval `hardware-nvidia`; preview builds driver closure |
| GPU suspend | `hosts/laptop/hardware.nix` | `hardware.nvidia.powerManagement` | finegrained on, old systemd suspend enable off; kernel notifier default for open 595+ | eval; hardware runtime status NOT_MEASURED |
| Network | `modules/nixos/network.nix` | NetworkManager, resolved, firewall, timesyncd | NM sole manager, DNS systemd-resolved, firewall on, no ports | eval `network`; VM offline boot |
| Boot network wait | `modules/nixos/boot.nix`, `network.nix` | `systemd.services.NetworkManager-wait-online.enable` | false; networkd wait-online false | eval `network`; VM offline boot |
| Locale/time | `modules/nixos/foundation/locale.nix` | `i18n.*`, `time.timeZone` | `zh_CN.UTF-8`, en_US generated, `Asia/Shanghai` | eval `locale` |
| Filesystems | `modules/nixos/network.nix` | `boot.supportedFilesystems` | `ntfs`, `exfat` | eval `filesystems` |
| zram/swap | `modules/nixos/memory.nix` | `zramSwap.*`, `swapDevices`, `boot.resumeDevice` | zram 25%, zstd, priority 100; no disk swap/resume | eval `memory` |
| Nix resources | `modules/nixos/memory.nix` | `nix.settings.max-jobs/cores` | 2 jobs, 4 cores | eval `memory` |
| Nix features | `modules/nixos/foundation/nix.nix` | `nix.settings` | nix-command/flakes, XDG profiles, connect timeout 10, build-dir `/nix/var/nix/builds` | eval `maintenance`; build |
| Automatic updates | `modules/nixos/foundation/nix.nix` | `nix.gc`, `nix.optimise`, `system.autoUpgrade` | all automatic modes off | eval `maintenance` |
| GC | `modules/nixos/foundation/nix.nix` | `nix-env -p ... --delete-generations +5`, `nix-collect-garbage` | weekly timer, no boot replay | eval `maintenance`; VM profile roots |
| Journal | `modules/nixos/foundation/maintenance.nix` | `services.journald.settings.Journal` | persistent, 128M, 14day | eval `maintenance`; VM log survives reboot |
| TRIM | `modules/nixos/foundation/maintenance.nix` | `services.fstrim` | weekly, not persistent timer | eval `maintenance` |
| Package policy | `software/policy.nix` | `nixpkgs.config.allowUnfreePredicate` | only `nvidia-x11`, `nvidia-settings` by name | preview build closure |
| Persistence | `modules/nixos/persistence.nix` | preservation module options | system dirs + machine-id + random-seed + user dirs | eval `preservation-*`; VM reboot |
| Early persistence | `modules/nixos/persistence.nix` | `boot.initrd.systemd.tmpfiles`, preservation `inInitrd` | `/var/lib/nixos`, `/var/lib/userborn`, machine-id early; initrd pre-creates regular sources | eval; VM |
| Storage binding | `hosts/laptop/storage-spec.nix` | none (data) | null/null/false | eval `storage-unbound`; no `nixosConfigurations.hearth` |
| Preview storage | `tests/fixtures/storage.nix` | disko module | virtual `/dev/vda`, GPT, ESP, Btrfs `/persist`/`/nix`, tmpfs root | preview build; VM |
| VM hardware | `tests/fixtures/hardware.nix` | NixOS modules | no NVIDIA, TLP fixture-disabled, virtual drivers | VM checks |

## Deliberately not decided

- Secrets backend (sops/vaultix/etc.) and any real recipient/ciphertext.
- Automatic proxy behavior and subscription source.
- Desktop/session stack and user software profiles.
- Disk layout, capacity, swap, hibernation, and installation method.
- Battery charge thresholds, fan curves, undervolt, or kernel parameter tuning.
- Any real measured power/boot/memory target.

## Local compatibility fix: PAM password writes through userborn symlinks

The locked upstream gap is real: stock Linux-PAM 1.7.2 atomically replaces
`/etc/shadow`, removing userborn's symlink on the tmpfs root. The local patch
`patches/pam-unix-password-symlink.patch` resolves the target and performs the
temporary write/rename in the persistent directory. Existing file owner/mode
and file fsync are retained. This is not a shutdown copy or an individual-file
bind mount.

Sources inspected at the locked revisions:

- nixpkgs `pkgs/by-name/li/linux-pam/package.nix` and Linux-PAM
  `modules/pam_unix/passverify.c`, functions `unix_update_shadow` and
  `unix_update_passwd`;
- nixpkgs `nixos/modules/services/system/userborn.nix` and userborn 1.0.1
  `rust/userborn/src/main.rs`, `ensure_shadow`: an initial password does not
  overwrite an existing mutable user's changed hash;
- nixpkgs `nixos/modules/system/activation/top-level.nix`,
  `system.replaceDependencies.replacements`: substitute the compatible PAM
  closure instead of globally rebuilding all PAM dependents.

The account VM now proves normal user-initiated passwd changes survive two
reboots and three explicit userborn restarts, with the old password rejected
and root locked. The earlier claim that the patched configuration accepts
both passwords was a terminal-echo error in the test; see
[phase1-blocker-password.md](phase1-blocker-password.md).

The patch is local maintenance work. An input upgrade must re-run these tests;
this does not claim the locked upstream has been fixed.

## Early account mounts across switch-root and shutdown

`inInitrd = true` establishes the account directories early, but does not by
itself retain early dependency semantics in generated stage-2 mount units.
The target's two account mount units therefore explicitly use
`DefaultDependencies = false`, before userborn and umount, with umount
conflicts. A drop-in gives `persist.mount` the same early behavior without
specifying its device, type, or layout. userborn requires just its account
mounts; journald requires its journal directory.

Sources: preservation `lib.nix` (`mkMountUnits`); the locked userborn unit's
ordering before device tmpfiles; generated VM systemd dependency-cycle logs;
NixOS `nixos/lib/systemd-unit-options.nix` (`overrideStrategy = asDropin`).
Verification: account VM across two reboots and final poweroff; the common
VM helper checks the entire serial log and persistent journal, including
shutdown rather than only `journalctl -b`. NixOS test-driver
`machine/__init__.py` provides `get_console_log()` across guest reboots.

## 2026-11-10：实机准备扩展

用户明确授权输入法、自动代理、网络连接工具和 oh-my-pi；本轮不受旧阶段的组件延期约束，仍禁止宿主激活与实盘操作。

| 决策 | 锁定来源 / 实现 | 验证方式 |
| --- | --- | --- |
| Fcitx5/Rime/雾凇 | 原 nixpkgs 锁定修订的 `nixos/modules/i18n/input-method/{default,fcitx5}.nix` 与 `pkgs/by-name/{fc/fcitx5-rime,ri/rime-ice}/package.nix`；fcitx5-rime 5.1.16、雾凇 2026.06.30 | 系统构建；图形 VM 实际在 Foot 提交中文；用户数据持久化 |
| 会话与输入协议 | 唯一 `hearth-fcitx5` user unit；随 graphical-session 生命周期；保留 native Wayland 输入，不全局强制 GTK_IM_MODULE | 图形 VM 检查 unit、词库部署、Ctrl+Space 和提交内容；依据 [Fcitx Wayland 文档](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland) |
| 网络工具 | 原 NetworkManager + resolved；增加 networkmanager 包的 nmtui，沿用 system-connections 持久化 | VM 命令入口、服务、创建并重启读回连接；真实无线网卡仍待实机 |
| Mihomo 后端 | 原 nixpkgs 锁定 mihomo 包；自有 hearth-proxy service 不依赖 network-online；未采用上游 module 的 network-online requires | 独立 netns 模拟上游、SOCKS、HTTP；检查无节点离线启动、导入、TUN/代理、停止恢复直连 |
| 路由与 DNS | TUN auto-route/auto-redirect、fake-IP；LAN/CN 直连，其他 AUTO；60 秒健康检查与 DIRECT fallback；不设置全局代理变量 | [Mihomo TUN 官方文档](https://wiki.metacubex.one/config/inbound/tun/)；VM 测试与实机节点验收 |
| Geo 数据 | 原锁定的 v2ray-geoip / v2ray-domain-list-community，部署为服务状态目录内的 store 数据链接；关闭自动更新 | 真正解析配置、启动；不在登录或服务启动时拉取 Geo 数据 |
| 节点凭据 | 运行时 root-only provider YAML，目录 0700、文件 0600，系统持久化；Nix 只保存路径；导入只提取 proxies | VM 导入有效/无效配置、权限、重启读回；不在宿主放置节点 |
| OMP | 官方 [v18.18.6](https://github.com/can1357/oh-my-pi/releases/tag/v18.18.6) 的 `omp-linux-x64`，SHA256 `a8059b95de5eaba0b3fb6f7182842d661feae29cb2931cdbeba2986db4751ecb`；autoPatchelfHook + makeWrapper | derivation installCheck 真正运行 version/help；VM 普通用户 profile 安装与重启执行；不调用付费模型 |
| OMP 状态 | 官方同 tag 的 nix/home-manager.nix 明确使用可写 `~/.omp/agent`；本项目只创建和持久化 `.omp`，不部署凭据或覆盖用户 config | VM 私有目录与自有非秘密设置的重启读回；实际登录由用户完成 |

原两份 flake.lock 未升级；OMP 使用固定哈希的 fetchurl，不增加未锁定 flake 输入。
使用说明与本轮结果分别见 real-machine-preparation.md 和 real-machine-preparation-report.md。

## 2026-11-10：内置 NVMe 整盘绑定与共享 Btrfs 布局

用户明确确认清空 /dev/nvme0n1、不保留数据，并授权为整盘 Hearth 编写最佳声明式布局。
只读核实稳定 EUI 路径，存储身份只写在 hosts/laptop/storage-spec.nix。layoutConfirmed=true
表示设计绑定已按授权确定，不表示格式化或安装已经发生。该绑定现在导出 nixosConfigurations.hearth。

- GPT：ESP 2 GiB，FAT32，GPT label hearth-esp；余量单个 Btrfs，GPT label hearth-system。
- Btrfs 子卷 @nix 与 @persist，共享容量池；不硬分 Nix store/个人文件比例。
- 根继续 tmpfs、上限 2 GiB；无磁盘 swap/resume，沿用 zram。
- 两个子卷相同 noatime/compress=zstd:1/nodiscard；沿用每周 fstrim 与非 Persistent 定时器。
- /nix 与 /persist 都 neededForBoot；保留 preservation 与密码挂载顺序修复。
- 锁定 disko 源 cedd626e11b635470fa6f9fdb8ad79b0075dd7f9 的 lib/types/{gpt,btrfs,filesystem}.nix
  确认 GPT label、subvolumes、extraArgs、mountOptions 与脚本生成 API。
- 共享 storage-layout.nix；VM 仅替换 device 为虚拟盘、ESP 为 512 MiB。不向 VM 传物理盘，
  不执行真实 diskoScript。真实脚本只构建并 bash -n。
- 路径扫描仅放行 storage-spec.nix 上 targetDisk 赋值的一行 nvme-eui by-id 形式；共享模块的真实盘引用仍被拒绝。
  未绑定的合成 inventory 和部分绑定仍保留拒绝测试，不把部署门槛改成无条件通过。

容量选择及 tmpfs 用户数据白名单边界见 storage-binding.md；实际验证结果见 storage-validation.md。

## 2026-11-10：AX203 固件初始化的实机修正

首次实机日志暴露 initrd 内缺少回退固件 -89。两个完整固件树对应文件完全相同，
但模块元数据只列 -100，旧 initrd 确实有 iwlwifi、没有 -89 或 iwlmvm。
本地 NVMe 不依赖 Wi-Fi，故移出 initrd、在 stage 2 同时加载 iwlwifi/iwlmvm；
NM backend 与 powersave 对齐 USB 系统，不改内核、不改锁、不添加禁用 11ax 等无关参数。
实际构建、initrd 内容检查和离线 VM 通过，实机网络复验仍待应用后进行。
完整来源与证据见 wifi-first-boot-fix.md。当前连接只在运行时以 root-only keyfile 复制，绝不进入求值。

## 2026-11-10：第三阶段外观与易用性

新增并锁定 Stylix `3e27b6c499e507df6e3bb8eca3614f5c95e28140`（narHash
`sha256-2pkE97wOXAYIn2/Nhs9y+iR0qVT+g/3UtukXdkywxXc=`），只新增该 input 及其传递节点；
已有 9 个锁节点与 `software/flake.lock` 未变。`assets/themes/emberlight.json` 仍是唯一人工维护
的 16 色输入，`config.lib.stylix.colors` 成为唯一解析来源；console 与 Foot 使用原生 target，
其余消费者通过兼容接口派生。

英文默认、tuigreet 布局、P10k/eza/fzf、Niri 直角与 top strut 8、Noctalia 纯色背景与插件源
禁用、Fcitx5 候选框（字号 20）以及 Foot `15x15` 的完整 option 定位、迁移与边界见
[phase3-decisions.md](phase3-decisions.md)。应用清单与实机待验项见
[phase3-manual-checklist.md](phase3-manual-checklist.md)，运行证据见
[phase3-report.md](phase3-report.md)。
