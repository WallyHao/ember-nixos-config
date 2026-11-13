# Phase 2 status

更新：2026-11-10。**INCOMPLETE / INSTALLED / FIRST_BOOT_PENDING**。

后续用户已授权整块内置盘用于 Hearth，存储绑定和声明式布局见 [storage-binding.md](storage-binding.md)，本轮验证见 [storage-validation.md](storage-validation.md)。后续用户已在本地执行安装；见 [installation-status.md](installation-status.md)。首次实机启动仍未验证。

原 store/renderer 阻塞已修复；本次不将“两个阻塞修好”等同于第二阶段整体验收完成。最新证据见 [phase2-report.md](phase2-report.md)，原因与边界见 [phase2-blocker-vm.md](phase2-blocker-vm.md)。

最终实际运行：vm-desktop **PASS，250.92 s**；vm-user-environment **PASS，65.19 s**；原四个 VM、完整预览及配置校验回归通过。图形 VM 包含重新认证、真实重启、OCR 看到加密历史并选回内容。

| 范围 | 状态 | 已有证据 / 剩余内容 |
| --- | --- | --- |
| S01 HM 与依赖 | PASS | 完整预览、求值、配置校验；两份 lock 未变 |
| S02 登录与底座 | PARTIAL | 真实密码登录、会话退出/重登；portal 实际对话框、Polkit 挑战与取消、错误密码 greeter、TTY 救援登录尚需补验 |
| S03 桌面与配色 | PARTIAL | Foot 窗口和真实输入、launcher 面板、通知、剪贴板、会话面板取消已实际执行；完整键位、启动器实际启动应用、截图/帮助等尚需补验 |
| S04 终端/profile | PARTIAL | 真实 HM、Zsh/P10k/插件、Nixvim 保存/重启 undo、普通用户原生 profile/history/rollback/GC/重启通过；y 的真实交互/取消与 profile 桌面入口仍需补验 |
| S05 状态 | PARTIAL | 精确状态规则与 undo 遗漏已修正；加密历史及 keyring 的完整重启验收见报告，正常 passwd 后 keyring 同步仍需补验 |
| S06 总体验收 | INCOMPLETE | 旧四个 VM 回归通过；新增 VM 的最新结果见报告；仍未覆盖全部计划场景 |

## 当前剩余任务

1. 完成上述尚未执行的 GUI/认证/profile 桌面发现与启动场景，以及最终重启/关机动作的二次确认页与取消；不能只检查服务 active、配置解析或 IPC exit 0。
2. 正常 passwd 后退出/登录并读回原 Secret Service 数据和 Noctalia 历史。账户 PAM 持久化旧回归已通过，但不等于 keyring 密码同步已验证。
3. 修正 Noctalia 的首次运行网络行为：在无 NIC 日志中，shell.offline_mode=true 仍出现 official/community 插件源的 git clone 尝试。按锁定源码显式禁用未使用源和自动更新，并重新验证。没有安装插件，不等于没有源扫描/获取尝试。
4. 补齐计划中的状态内存快照、完整独立目录求值等证据；本次排障没有替它们补写 PASS。
5. 实盘已绑定；安装和所有真实显示、输入、电池、功耗指标继续等待后续任务。后续用户已授权输入法、代理、网络工具和 oh-my-pi，新增实现与本轮独立验收见 [实机准备](real-machine-preparation.md) 和 [准备验证结果](real-machine-preparation-report.md)；不把新增功能视为旧待验项全部完成。

本轮未激活或安装宿主、未改账户、未执行实盘分区/格式化、未写 EFI、未重启；未给 VM 传真实块设备/GPU。storage-spec 已绑定用户确认的内置 NVMe 与布局，layoutConfirmed=true，已导出真实 nixosConfigurations.hearth 供构建；后续实盘安装已由用户本地完成，首次启动待验证；见 installation-status.md。
