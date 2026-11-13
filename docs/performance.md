# Performance evidence

The user goals are lower idle power, faster boot, and lower initial memory.
Configuration values are implementation evidence, not measured results.

## 1. Configuration evidence (phase 1)

| Goal | Evidence |
| --- | --- |
| No boot menu countdown | `boot.loader.timeout = 0`, `configurationLimit = 5` |
| No network-blocked login | `NetworkManager-wait-online` disabled; no update-on-boot service |
| No discrete GPU polling | no persistence daemon, no Dynamic Boost daemon, no `nvidia-smi` loop |
| Conservative power policy | TLP sole executor with AC/BAT EPP/platform-profile values |
| Low background base | no SSH, Avahi, CUPS, Docker, libvirt, fwupd, desktop session |
| Bounded memory pressure | zram 25%, no disk swap, bounded Nix parallelism |
| Bounded logs/GC | journald 128 MiB / 14 days; weekly system-profile trim |

## 2. VM results (phase 1)

VM results prove account, persistence, and offline-boot behavior in a virtual
machine. They do not predict laptop battery power or real NVMe boot time.

2026-11-09 修复后的复验（KVM）：

| 场景 | kernel | initrd | userspace | 合计 |
| --- | --- | --- | --- | --- |
| `vm-offline-boot`：目标来宾无网卡 | 331 ms | 4.305 s | 3.188 s | 7.825 s |
| `vm-offline-link`：链路存在，无 DHCP | 548 ms | 4.343 s | 2.813 s | 7.706 s |

两种场景均到达本地登录目标，`NetworkManager-wait-online` 和
`nixos-upgrade` 不在关键链。完整生命周期日志无依赖环。
这些是单次 VM 测试数据，不能推算真实笔记本性能或电池功耗；也不是实机
UEFI 默认菜单和恢复菜单的行为验收。最初报告的 3.340 s userspace /
6.929 s 合计属于旧测试定义下的历史数据，不与当前场景混用。

## 2b. Phase 2 configuration evidence

Phase 2 adds a graphical session, so phase-1 TTY numbers must not be compared
directly with the new entry path. Configuration evidence currently available:

| Goal | Evidence |
| --- | --- |
| No graphical autologin | greetd without `initial_session`; `getty.autologinUser = null` |
| Local rescue path | tty2 getty enabled; tty1 owned by greetd |
| No network wait | existing NetworkManager-wait-online and networkd-wait-online disabled |
| Bounded resident services | one Noctalia user service; no Waybar/Mako/Fuzzel/cliphist/polkit-gnome |
| No weather/telemetry polling | Noctalia offline mode, telemetry off, external IP off |
| Single audio server | PipeWire/WirePlumber; PulseAudio daemon disabled |
| Single power owner | TLP; no power-profiles-daemon/TLP-PD/auto-cpufreq/tuned |
| No duplicate file manager | Yazi only in the independent profile; HM ships a hint wrapper |

Phase 2 graphical boot, greeter-ready, idle-without-Foot, and one-Foot VM
timings are recorded only after `vm-desktop` actually runs. They remain VM
numbers, not battery or internal-disk claims. The virtual display uses
`virtio-gpu-pci` and software GL; this is not a hardware rendering result.

## 3. Real installed-system measurements (NOT_MEASURED)

All of the following remain `NOT_MEASURED` until Hearth is installed on the
internal disk with an authorized layout.

| Target | Measurement conditions | Record |
| --- | --- | --- |
| Boot | at least 3 cold boots on the internal disk; separate firmware/loader/kernel/initrd/userspace; exclude password entry | `systemd-analyze time`, `critical-chain`, relevant `blame`; confirm no automatic menu wait and that the recovery menu is reachable |
| Idle memory | TTY system stable for 120 s, no maintenance shell, agent, build, or desktop; sample repeatedly | `MemTotal`, `MemAvailable`, `MemTotal - MemAvailable`, service RSS; do not treat cache as a leak or tmpfs `size=` as usage |
| Idle power | battery discharge, fixed brightness/refresh, Wi-Fi state recorded, no external display, no build, 5-minute stable sample | average W from battery energy delta; GPU `runtime_status`; never use charging `power_now` as discharge power |
| Suspend/resume | recorded sleep mode, repeated cycles and one fixed-duration suspend | wake success, network recovery, GPU errors, drain rate; hibernation is not offered |

Investigation budgets, not user promises: zero artificial loader wait; no
network timeout in the local login path; TTY idle memory around 768 MiB and
userspace boot around 5 s as review thresholds. Exceeding a threshold requires
a cause list, not hiding features or changing the measurement definition.

The old "USB + full desktop" system and a future "NVMe + TTY" system are not a
controlled comparison; do not report a percentage improvement from their
difference.

## 2026-11-10：第二阶段 VM 排障复验

vm-desktop 250.92 s，vm-user-environment 65.19 s；这是整个 VM 测试脚本
时间，含安装、OCR/交互、GC 或重启，不是开机耗时。图形 VM 使用虚拟
显卡和 Mesa llvmpipe，仅验证功能；未以该结果推断笔记本功耗或空闲内存。
六个 VM 的原始日志和 drv/output 见 phase2-report.md。

本次没有补测计划要求的 greeter/空闲桌面/单个 Foot 三状态内存快照，
也没有新的实机测量。原有实机 NOT_MEASURED 状态继续有效。
