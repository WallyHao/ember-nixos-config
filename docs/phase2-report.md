# 第二阶段排障与复验报告

更新：2026-11-10。**原 store/renderer 阻塞已解决；整体仍为 INCOMPLETE / STORAGE_UNBOUND。**

本报告替代 2026-11-09 的初始阻塞交付结果。下面的 VM 都在本轮真实运行过，最终单项回读可能命中这些本轮产物；不是将 no-build 检查当成 VM 执行。第二阶段尚未覆盖所有计划场景，接续任务见 phase2-status.md。

## 修复结果

- 来宾 /nix/store 改为只读共享 lower + 虚拟 Btrfs 持久 upper，并导入真实数据库。移除 HM 的假成功 Nix shim。
- wallyhao 通过真实来宾 daemon 原生安装基础 profile，验证 history/rollback；GC 回收无引用垃圾，同时保留历史 generation 的独立测试包；重启后当前与历史程序仍可执行。
- Niri 测试专用软件 EGL 适配统一 card0/renderD128 查找键。生产 Niri 仍为锁定包，不含该适配。
- 图形 VM 真实密码登录、Super+Return 打开 Foot、窗口内执行 id -u 得到 1000；启动器面板开关、通知显示、剪贴板选择与来源退出后的保持均通过。
- 退出桌面回到 greeter，重新认证后只有一个 Noctalia；加密历史可从面板选回。来宾真实重启后 boot ID 改变，再次密码登录、OCR 看到测试历史、选中并读回 clipboard 内容。
- 两个会话快捷键打开正确面板，Escape 取消并继续运行。这里证明面板开关，尚未证明最终动作的二次确认页全部行为。
- 生成窗口/面板时等待实际映射，避免进程或 IPC 状态先变而截图/输入过早。Wayland socket、实际显示环境、runuser pipeline、greeter remember 与 GUI 下重启的探针错误一并修正。
- y 的 cwd 读取避开 cat=bat，保留子程序失败码；Neovim undo 子目录补入持久化，并实际在重启后撤销此前已保存的编辑。

详细原因与源码位置见 [phase2-blocker-vm.md](phase2-blocker-vm.md)。

## 本轮产物

| 检查 | 结果 / VM 脚本耗时 | 最终 output |
| --- | --- | --- |
| `desktop-config` | PASS | `/nix/store/6ancqzvmwmnj0ks4sjp2vcxdvliqcc1y-hearth-desktop-config` |
| `eval-contracts` | PASS | `/nix/store/7saw3jq7f8rbdd7bz3blj1mixcfrbkky-hearth-eval-contracts` |
| `eval-user-environment` | PASS | `/nix/store/fmxccq8dbh3s8ijbzvm5xz8m8d3xqjhr-hearth-eval-user-environment` |
| `system-preview` | PASS | `/nix/store/mjrxwi15psiijnx4xbq7ip1acm10xpx5-nixos-system-hearth-26.11.20261107.dirty` |
| `vm-accounts` | PASS，124.18 s | `/nix/store/h4sxiax2ksg0ymh6jizh6j7n25j33idp-vm-test-run-disko-hearth-vm-accounts` |
| `vm-desktop` | PASS，250.92 s | `/nix/store/dp32qh3lia6xzxs6h4yzsrihcc0in2p9-vm-test-run-disko-hearth-vm-desktop` |
| `vm-offline-boot` | PASS，55.58 s | `/nix/store/fqzccb8zzbm6i46ky3fv9r81585zpzrb-vm-test-run-disko-hearth-vm-offline-boot` |
| `vm-offline-link` | PASS，43.38 s | `/nix/store/hpysw2rq8a7kir0gvycxhw72hqh01bbf-vm-test-run-disko-hearth-vm-offline-link` |
| `vm-persistence` | PASS，52.55 s | `/nix/store/5pl5ssbagvm7kapnl4iw3sg05pqaygzi-vm-test-run-disko-hearth-vm-persistence` |
| `vm-user-environment` | PASS，65.19 s | `/nix/store/syvqc9b37z50s41yxw021gbij0y9sjla-vm-test-run-disko-hearth-vm-user-environment` |

独立 software#base 构建/回读也成功：`/nix/store/3y1g9zdca56n2kd7q7qf6lm8sk2m1xqs-hearth-base`。
完整预览包含对 y 和 undo 的修正。desktop-config 实际使用锁定 Niri、Foot、Noctalia 与生成 Nixvim 配置做校验，其产物未因测试库修改而改变。

VM 耗时包括虚拟盘安装、交互、OCR、重启或 GC，不是系统启动时间。图形场景是 KVM/QEMU 虚拟显卡 + Mesa llvmpipe；没有真实 GPU passthrough，不证明实机图形/功耗表现。

## 复验命令

在 hearth-nixos-config/ 中执行。本轮实际分组执行过这些构建；图形与用户环境新增检查实际重跑，旧四个 VM 也因公共测试环境修改而重跑。

```sh
nix-shell ./shell.nix --run 'just check'
nix build --no-link --print-out-paths --no-update-lock-file -L \
  path:.#packages.x86_64-linux.system-preview \
  path:.#checks.x86_64-linux.desktop-config \
  path:.#checks.x86_64-linux.eval-user-environment \
  path:.#checks.x86_64-linux.eval-contracts \
  path:.#checks.x86_64-linux.vm-accounts \
  path:.#checks.x86_64-linux.vm-persistence \
  path:.#checks.x86_64-linux.vm-offline-boot \
  path:.#checks.x86_64-linux.vm-offline-link \
  path:.#checks.x86_64-linux.vm-desktop \
  path:.#checks.x86_64-linux.vm-user-environment
nix build --no-link --print-out-paths --no-update-lock-file 'path:./software#base'
```

最终 `just check` 为 **exit 0**，含格式、ShellCheck、路径/秘密扫描、自测和 flake no-build 检查；其最终 drv 与本报告构建产物一致。

扫描负向自测会故意输出假凭据和禁止路径告警，以证明发现能力；不代表仓库中存在那些测试凭据。六个 VM 的完整串口/关机检查均无挂载失败或 ordering cycle。账户旧回归仍覆盖正常 passwd、两次重启、userborn 与新旧密码验证；未改账户后端或删除 PAM 补丁。

| 检查 | Derivation，可用 nix log 读取 |
| --- | --- |
| `desktop-config` | `/nix/store/54y2xs09v4sryb0qr6hqs2gy9v8c0hr8-hearth-desktop-config.drv` |
| `eval-contracts` | `/nix/store/iwfm907chlf61pgrfkga4x3m547hw0yl-hearth-eval-contracts.drv` |
| `eval-user-environment` | `/nix/store/m0hsyplady9b61rpfhxxvamcsmy2qzr3-hearth-eval-user-environment.drv` |
| `system-preview` | `/nix/store/czhnz5i92skg3m4f62r18893f1iyd7vk-nixos-system-hearth-26.11.20261107.dirty.drv` |
| `vm-accounts` | `/nix/store/x30gaysf6721hdjm9vi5kvs51dpaahvf-vm-test-run-disko-hearth-vm-accounts.drv` |
| `vm-desktop` | `/nix/store/qvkq5lxq58xdcg9k6x11swy8yjj2dyzy-vm-test-run-disko-hearth-vm-desktop.drv` |
| `vm-offline-boot` | `/nix/store/y0a9jbrr3f5v3hyqk3r4y8c3cwvah0j1-vm-test-run-disko-hearth-vm-offline-boot.drv` |
| `vm-offline-link` | `/nix/store/y1nmp7n85fxnwp7257slpys8sjyclhs1-vm-test-run-disko-hearth-vm-offline-link.drv` |
| `vm-persistence` | `/nix/store/3k9zfzpsr8c31pmjs2rlpmi607p55kn5-vm-test-run-disko-hearth-vm-persistence.drv` |
| `vm-user-environment` | `/nix/store/rgw79x52wxph57zmahz2hilibn621nmx-vm-test-run-disko-hearth-vm-user-environment.drv` |

[Foot 截图](/nix/store/dp32qh3lia6xzxs6h4yzsrihcc0in2p9-vm-test-run-disko-hearth-vm-desktop/foot.png)、[重启后剪贴板截图](/nix/store/dp32qh3lia6xzxs6h4yzsrihcc0in2p9-vm-test-run-disko-hearth-vm-desktop/clipboard-restored.png)。其余图形截图位于同一 store 输出：`foot.png`、`launcher.png`、`notification.png`、`session-panel.png`、`clipboard-restored.png` 等。剪贴板恢复截图在 OCR 看到测试内容后采集；Foot 截图在身份命令执行成功后采集。

本地详细日志：`/tmp/hearth-phase2-desktop-final3.log`、`/tmp/hearth-phase2-user-undo.log`、`/tmp/hearth-phase2-regressions.log`、`/tmp/hearth-phase2-check-final.log`。临时日志可能被清理，以上 drv/store paths 是复验入口。

## 不能据此宣称第二阶段完成

尚需补齐真实 portal/Polkit 挑战与取消、错误密码 greeter、TTY 救援登录、完整键位与截图/帮助、启动器实际启动应用、外壳重启与其启动应用的生命周期、Yazi/y 真实交互和取消、profile 桌面入口发现/启动、正常 passwd 后 keyring/历史恢复等。

无 NIC 日志还发现 shell.offline_mode=true 时默认 official/community 插件源仍会尝试 git clone。这次记录了真实问题，尚未修改；下一步应按锁定 Noctalia 的插件源 schema 显式关闭不用的源及自动更新，而非删除失败日志或声称完全无网络尝试。

计划要求的完整状态内存快照、独立目录求值等未由本次排障补验，不擅写 PASS。远端 GitHub CI 未触发。

宿主未激活、未安装、未改账户、未分区/格式化、未写 EFI、未重启。两份 lock、storage-spec、账户模块和 PAM 补丁与修复前备份一致；storage-spec 为 null/null/false，未导出真实 nixosConfigurations.hearth。实盘安装与实机性能全部待后续任务。
