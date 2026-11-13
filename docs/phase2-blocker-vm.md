# 第二阶段 VM 阻塞排障

更新：2026-11-10。**原两个阻塞已解决**：最终 vm-desktop 实际运行通过（250.92 s），vm-user-environment 通过（65.19 s），旧四个 VM 回归通过。产物与剩余验收见 [phase2-report.md](phase2-report.md)、[phase2-status.md](phase2-status.md)。整体阶段仍为 INCOMPLETE，不能仅凭排障结束标为完成。

## 原生 Nix store：9p 不能充当可写安装 store

旧测试库在安装后强制将 `/nix/store` 直接挂成 9p。Nix 打开 local store 会初始化 `.links` 等元数据，9p 导出的权限/xattr 语义不能满足这些操作。改用只读 local URI、export/import、单独挂 `.links` 都没有解决 store 本身的写入边界。

修复位于 `tests/vm/disko-test-lib.nix` 和 `tests/fixtures/hardware.nix`：

- 将 9p 共享挂到 `/nix/.ro-store`，来宾 mount 为只读，QEMU 导出也设置 `readonly=on`。
- `/nix/store` 使用 overlayfs：lower 为共享闭包，upper/work 位于来宾虚拟 Btrfs `/nix/.rw-store`，新包、元数据、GC whiteout 都留在来宾虚拟盘。
- 在安装 VM 内为目标系统的 `/mnt/nix/var/nix` 导入真实 closure registration；保持逻辑 `/nix/store` 前缀，重启后由来宾自己的数据库使用。
- VM 硬件 fixture 的 initrd 模块清单此前使用 mkForce，必须显式加入 overlay，不能假定上游自动添加仍会保留。

对应上游机制可查锁定 nixpkgs 的 `nixos/modules/tasks/filesystems/overlayfs.nix`、`nixos/modules/virtualisation/qemu-vm.nix` 和 `nixos/tests/qemu-vm-store.nix`。本项目只在测试库应用，生产 `/nix` 仍按未来磁盘布局提供，不增加生产 overlay。

`tests/vm/common.nix` 中原来总是 exit 0 的 Nix shim 已完全移除，HM 使用真实 Nix 和原生 GC root 行为。`vm-user-environment` 不再复制到另一个私有 URI 来规避问题：wallyhao 直接使用来宾默认 daemon 安装真实基础集合，并验证原生 history/rollback、GC 和重启。

GC 对照另外创建未被系统 extraDependencies 引用的小测试包：历史 generation 的包仍能执行，没有任何 root 的垃圾包被回收。未手写 profile symlink/manifest，没有额外 root，也没有宿主 GC。

## Niri：软件 renderer 的查找键不一致

旧报告中的“没有可用 render node”需要细化。日志实际显示：

```text
using as the render node: /dev/dri/renderD128
got render node: card0
error creating renderer for primary GPU: Error::NoDevice(... ty: Render)
```

虚拟显卡具有 render node，但软件 EGL 没有报告可用的 EGL render node，锁定 Niri 的初始化退回 card0，并以 card0 注册 renderer；之后主 renderer 查询仍使用 renderD128，因而找不到已注册项。仅移除 software-EGL guard 不会修复这个键不一致。

`tests/vm/desktop.nix` 保留测试专用软件 EGL 适配，同时让该单虚拟 GPU 的 primary renderer 选择 Primary 节点，与实际注册键一致。此适配没有进入生产包；VM 使用 KVM/QEMU 虚拟显卡和 Mesa llvmpipe，不向 VM 传真实 GPU，也不代表真实 Intel/NVIDIA 驱动效果已验证。

修复后测试已实际通过 Foot 窗口创建、Super+Return 和窗口内身份命令执行，不再停在 NoDevice。生成窗口需要时间，因此断言先等待 Niri 的真实窗口列表，不能看到进程就立即断言窗口存在。

## 连带修正的测试错误

- Wayland 的 `.lock` 是普通锁文件，原 `test -S ...wayland-*.lock` 永远不能证明 socket；现在检查真正的 Wayland socket。
- Noctalia IPC socket 按 WAYLAND_DISPLAY 区分。来宾实际使用 wayland-1，测试若省略该环境会误查 wayland-0 并报告“not running”。所有用户操作/面板探针使用实际显示环境。
- 用户 helper 把完整命令通过正确引用的 `sh -c` 放到 runuser 内执行，避免 pipeline 后半段误在 root 上运行。
- 面板验证读取 Noctalia 真实 status 的 activePanelId；不再以始终存在的 bar 图层冒充 launcher/clipboard/session 已打开。
- IPC 状态更新早于面板映射/键盘焦点。发送 Escape/Return 前等待真实 standalone/attached panel 图层和首帧；剪贴板截图还要求 OCR 看见测试内容，避免“状态已开、截图却空”的假证据。
- tuigreet --remember 可能直接进入 Password。探针通过上游支持的 Escape 返回空 Username，再逐个等待真实提示；不把用户名误输进密码框。
- 图形会话中 Ctrl+Alt+Delete 不一定重启；锁定 driver 的 reboot() 仅发送这个键。现在在来宾请求系统重启，检查内核 restart 日志和 boot ID 改变后重新连接。
- 原生 profile history 含 ANSI 颜色，断言前只移除颜色控制序列，仍验证真实 generation 内容。
- Noctalia 取得剪贴板所有权后，wl-copy 可能已经退出；测试接受“没有该进程”，仍明确断言来源不存在且剪贴板内容可读。

## 配置中同时发现的两处遗漏

- `y` 的 cwd 读取改用 command cat，避免 cat=bat 的别名污染目录；子程序失败时不 cd，并返回原失败码。Yazi 实际交互与取消仍须按完整验收清单验证，不能仅因函数存在就标 PASS。
- Neovim undo 子目录补入 preservation 白名单。此前只有创建目录、文档声称保存，实际规则缺失。

## 不变的边界

两份 lock、存储绑定、账户模块和 PAM 补丁均与修复前备份一致。没有宿主 activation、安装、实盘分区/格式化、EFI 写入或重启。storage-spec 仍为 null/null/false，不导出真实 nixosConfigurations.hearth。内置盘与实机性能仍未验证。
