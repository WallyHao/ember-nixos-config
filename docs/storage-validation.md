# 内置 NVMe 声明式存储验证

2026-11-10。**配置与隔离虚拟盘验证通过；STORAGE_BOUND / NOT_INSTALLED。**
用户已授权整盘 Hearth 布局。本轮没有执行真实分区、格式化、安装、EFI 写入或宿主重启。
设计和用户数据边界见 [storage-binding.md](storage-binding.md)。原第二阶段未覆盖的桌面/认证场景不因本轮通过而被宣称完成。

## 本轮实际通过

- `nix-shell ./shell.nix --run 'just check'`：exit 0，含格式、ShellCheck、路径/凭据扫描、负向自测与 flake check --no-build。
- 真实 `nixosConfigurations.hearth.config.system.build.toplevel`：构建成功。
- `checks.storage-layout`：真实 disko 脚本生成并通过 bash -n；只解析、复制供审阅，绝不执行。
- system-preview、eval-contracts、eval-user-environment：构建成功；desktop-config 已有输出仍通过 flake 检查。
- 七项 VM 实际运行通过，均在本轮共享 Btrfs 子卷布局上启动；仅使用虚拟块设备和虚拟显卡。

| VM | 结果 | 完整测试耗时 |
| --- | --- | --- |
| accounts | PASS | 95.41 s |
| connectivity | PASS | 105.58 s |
| desktop | PASS | 186.77 s |
| offline-boot | PASS | 38.05 s |
| offline-link | PASS | 34.93 s |
| persistence | PASS | 46.87 s |
| user-environment | PASS | 66.92 s |

测试耗时包含虚拟安装、登录、OCR、构建/GC、重启，并非实机冷启动性能。
图形 VM 使用原有测试专用软件渲染补丁和 2 GiB 内存；其余默认 1 GiB。真实 GPU、启动、功耗仍待实机。

新的 VM fixture 直接调用 hosts/laptop/storage-layout.nix，仅把设备改为 /dev/vda、ESP 缩为 512 MiB。
测试器在虚拟安装过程中映射到自己的虚拟目标盘；未传真实 by-id、NVMe 或 USB 块设备。
原密码持久化、Home Manager、Nix profile 回滚/GC/重启、中文输入、剪贴板和代理/DNS 场景均保留。
公共检查没有发现 ordering cycle、删除依赖任务或挂载失败。

## 真实配置求值结果

- deployment：storageBound=true、installable=true；这表示导出构建目标，不表示已获执行安装的操作指令或已经安装。
- 目标设备：/dev/disk/by-id/nvme-eui.5cdfb804515050ab；只读解析为 /dev/nvme0n1，UMIS 512 GB / 476.9 GiB。
- GPT label：hearth-esp、hearth-system，避免使用通用 disk-main-* 标签。
- /boot：/dev/disk/by-partlabel/hearth-esp，vfat，umask=0077/noatime。
- /nix、/persist：同一 /dev/disk/by-partlabel/hearth-system；分别 subvol=@nix 和 subvol=@persist；均 neededForBoot=true。
- 两个子卷均 noatime/compress=zstd:1/nodiscard；沿用每周非补跑 fstrim。
- /：tmpfs，size=2G/mode=755。无磁盘 swap/resume；无 LUKS；无自动快照或备份服务。
- 实盘在结束时仍无子分区、文件系统或挂载点，与本轮开始时一致。

真实目标与预览的 toplevel 可能相同：两者生成相同的按 Hearth GPT 标签挂载的 fstab，
真实磁盘身份与不同 ESP 容量属于 disko 分区脚本的输入；真实脚本已单独构建/解析。
不能把相同 store path 当成实际分区已经完成的证据。

## 最终产物

| 检查 | store path |
| --- | --- |
| system-preview | `/nix/store/w0k5flkjlvril4419rqh219j7m883amx-nixos-system-hearth-26.11.20261107.dirty` |
| storage-layout | `/nix/store/il3ngpf1462llm88b5pxx6wcklsq9kj6-hearth-storage-layout` |
| eval-contracts | `/nix/store/ssdxk1i01iqlj4i4z17jvbvw8rr8wnrk-hearth-eval-contracts` |
| eval-user-environment | `/nix/store/cxyvk4d4lpvvb9frhfacjcwrldjpvpwa-hearth-eval-user-environment` |
| desktop-config | `/nix/store/6ancqzvmwmnj0ks4sjp2vcxdvliqcc1y-hearth-desktop-config` |
| vm-accounts | `/nix/store/9l59k59q4b4kia9j7pddyp80yvp09b4s-vm-test-run-disko-hearth-vm-accounts` |
| vm-persistence | `/nix/store/14mq7rxvjv04bxmdpxfpdicbzawkgqd1-vm-test-run-disko-hearth-vm-persistence` |
| vm-offline-boot | `/nix/store/2c7yhwkscrjhl4iqkl4lxvvyaw8q1zl5-vm-test-run-disko-hearth-vm-offline-boot` |
| vm-offline-link | `/nix/store/xkn9f9lb902hyf75603ln1nl3xaywmdc-vm-test-run-disko-hearth-vm-offline-link` |
| vm-desktop | `/nix/store/sw3xsalizpaz72sqv8z0ysca0b8lfk08-vm-test-run-disko-hearth-vm-desktop` |
| vm-user-environment | `/nix/store/7b3lmygmd9gcnv2cz3vcsifrmcs0jadq-vm-test-run-disko-hearth-vm-user-environment` |
| vm-connectivity | `/nix/store/1gqzz6mmxg3i01x5ja2xsvl9455jyab2-vm-test-run-disko-hearth-vm-connectivity` |

全部 12 个检查输出存在，并与最终 flake check 中的 drv 对应。
两份 flake.lock、账户/PAM 模块及本地补丁与原归档逐字节比较未变。
存储绑定与 fixture 的变化是本轮有意实现，没有升级锁定依赖。

日志和只读求值证据位于本次工作环境，/tmp 不保证跨机器或重启保留：

- /tmp/hearth-storage-check-final.log
- /tmp/hearth-storage-build-final.log
- /tmp/hearth-storage-vm-final.log
- /tmp/hearth-storage-desktop.log
- /tmp/hearth-storage-connectivity.log
- /tmp/hearth-storage-artifacts.json
- /tmp/hearth-storage-deployment.json
- /tmp/hearth-storage-filesystems.json

## 门槛与扫描

原 storage-unbound 的固定断言改为当前已绑定契约；另用完整 null/null/false 的合成 inventory
断言拒绝部署，部分绑定的负向求值也继续保留。预览仍明确断言 device=/dev/vda。
路径扫描只允许 hosts/laptop/storage-spec.nix 上一个严格形状的 EUI by-id 赋值行；
新增负向自测证明同类物理盘引用放进共享模块仍被拒绝。没有放行整个 hosts/ 或 modules/ 目录。

本轮最初虚拟盘构建在加入最终 Hearth GPT 标签后主动停止并重跑；以上仅记录最终标签版本的通过产物。
没有通过删减测试、忽略失败或实际操作目标盘来让结果通过。远端 CI 未运行。
