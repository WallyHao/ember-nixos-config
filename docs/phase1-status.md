# 第一阶段状态

更新：2026-11-09。

整体：**`CODE_AND_VM_COMPLETE / INSTALLED / FIRST_BOOT_PENDING`**。
后续用户已授权整块内置盘的布局与绑定，见 [storage-binding.md](storage-binding.md) 和 [storage-validation.md](storage-validation.md)。下方阶段一验收记录保留其原始时点与边界。
密码子任务：**`A05_RESOLVED`**。原验收 R1–R5 与本轮新发现的关机依赖环均已
处理并通过对应检查；真实磁盘仍未绑定，安装和实机测量仍待后续授权。

## 完成证据

- `nix-shell ./shell.nix --run 'just check'`：exit 0。包含格式、ShellCheck、
  gitleaks 凭据扫描、覆盖 `modules/` 的路径扫描、扫描负向自测和
  `nix flake check --no-build`。
- `system-preview`、`eval-contracts`、`vm-accounts`、`vm-persistence`、
  `vm-offline-boot`、`vm-offline-link` 的 `nix build`：exit 0。
- R1：正常 `passwd` 后新密码立即有效；旧密码和任意错误密码明确拒绝；
  两次系统重启和三次 userborn 重启后新密码仍有效，持久 shadow 哈希一致。
- R2：账户目录和底层 `persist.mount` 的早期/关机顺序已修正；公共 VM 检查
  覆盖完整串口日志、持久 journal 和最终关机，未发现 ordering cycle。
- R3：统一 `tests/vm/login.exp` 要求明确 `Login incorrect` 或认证后的
  `HEARTH_LOGIN:wallyhao` 身份标记；timeout、EOF、输入回显和错误接受/拒绝
  都有负向对照，错误原因被断言。
- R4：`vm-persistence` 使用原生 `nix profile install`、`remove`、
  `wipe-history` 和 guest-private store GC；没有手工 generation 链接、额外
  GC roots，也没有对宿主 store 执行 GC。
- R5：gitleaks 规则和精确 bootstrap-hash 例外、`modules/` 路径扫描、扫描
  执行失败与无匹配区分、假凭据/禁止路径负向自测均通过。
- 网络场景：无 NIC 与链路存在但无 DHCP 两种 VM 均到达本地登录目标；
  `NetworkManager-wait-online` 和 `nixos-upgrade` 不在关键链；记录 KVM 模式
  与 userspace 时间。

## 边界

- 真实目标仍未导出 `nixosConfigurations.hearth`；storage-spec 保持
  `null/null/false`。
- 未在宿主激活、安装、分区、写 EFI、改账户或重启；所有账户/安装/重启操作
  只发生在隔离 VM 的虚拟盘。
- 未触发远端 GitHub CI；不声明远端工作流通过。
- 内置盘安装、真实冷启动、功耗、初始内存、GPU runtime PM、休眠和固件行为
  仍为 `NOT_MEASURED`。

复验命令和产物见 [phase1-report.md](phase1-report.md)。
