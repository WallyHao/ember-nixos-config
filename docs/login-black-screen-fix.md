# 2026-11-10 登录黑屏修复

实机日志：19:41:26 greetd 启动，19:41:27 输出 `expected equals sign on line, but found none`，以 status=1 退出；安装版本为 f2hc14rl2g6rsz7m3qz7w4xn8045gblv。

原因：NixOS 的 TOML 生成器将带多行 ASCII 图案的 default_session.command 输出为多行 literal string；锁定的 greetd 0.10.3 解析器无法读取。上一轮 desktop-config 不检查 greetd 配置，系统构建成功也未暴露此运行时兼容问题。

修复：modules/nixos/desktop/session.nix 用 writeShellScript 生成 hearth-greeter，脚本 exec tuigreet 并保留图案/参数；greetd TOML 的 command 仅保存单行 store 路径。认证、密码、桌面、字体未改。

针对性验证：
- 实际 Hearth toplevel 和 eval-user-environment 构建成功；更新现有断言，要求 greetd command 为单行 wrapper 路径。
- 生成 wrapper 通过 bash -n。
- 用锁定的 greetd 程序在 bubblewrap（隔离所有 namespace，仅只读 store、临时 /run、空 /etc、虚拟 /dev）中读取旧配置，复现原错误。新配置越过解析，报 PAM greetd service missing；空 /etc 下该后续错误符合预期。未启动宿主登录服务，不把该检查写成真实登录通过。
- 没有运行 VM。实机下一次启动的 greeter 显示待用户确认。

修复产物：/nix/store/cwcz6ig7z86fccdd9610g4py3lsfq1zv-nixos-system-hearth-26.11.20261107.dirty

内置盘挂载在 /mnt 后，由用户执行：

```sh
sudo nixos-install --root /mnt \
  --system /nix/store/cwcz6ig7z86fccdd9610g4py3lsfq1zv-nixos-system-hearth-26.11.20261107.dirty \
  --no-root-passwd --no-channel-copy
```

保留现有数据和密码，不格式化、不自动重启。
