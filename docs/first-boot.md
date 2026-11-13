# Hearth 首次启动

首次实机启动已发生，Wi-Fi 初始化问题的修正待应用，见 wifi-first-boot-fix.md。选择内置 NVMe 的 Linux Boot Manager，从密码 greeter 登录 wallyhao；首次登录后用 passwd 修改初始密码。

## 先安装已缓存的软件 profile

由 wallyhao 在 Foot 中执行，无需 sudo：

```sh
cd ~/Workspace/hearth-nixos-config
just profile-install
```

如果当前系统还没有 just，先运行同一个安装入口：

```sh
./scripts/hearth profile-install
```

该入口不需要网络或 sudo，安装基础工具和 OMP；重复执行不会新建相同 profile generation。
它仅允许在 Hearth 上由 wallyhao 执行，避免把软件误装到当前 USB 系统。
首次安装使用 software/bootstrap-workstation 中记录的已缓存路径，不需要手写长 store path。

安装环境已成功把该 closure 复制到新系统，并完成目标数据库与 254 个依赖路径的只读校验。这个 profile 包含基础终端工具和 oh-my-pi；Home Manager 不自动安装它。
安装完成后在新 Foot 窗口检查 git --version、yazi --version、omp --version。
首次离线安装使用固定 store path；之后的日常软件管理说明见 software/README.md。

## 基本检查

- hostname 应为 hearth；findmnt /nix、findmnt /persist 应为内置盘的 Btrfs 子卷。
- Super+Return 打开 Foot；首次词库部署后用 Ctrl+Space、nihao、空格输入“你好”。
- nmtui 连接自己的 Wi-Fi；没有复制移动硬盘上的网络密码或私有代理凭据。
- 代理节点尚未导入时保持直连；自己的节点用 hearth-proxy import 导入，具体见 real-machine-preparation.md。
- omp 首次运行需要你选择模型并认证；没有预置 API key。
- 之后检查音量、亮度、显示、休眠与功耗；现有 VM 通过不代表这些实机项目通过。

配置仓库位于 ~/Workspace/hearth-nixos-config。根目录为 tmpfs，只有 preservation 白名单的数据会跨重启保存。
不要把新的、尚未加入白名单的家目录路径当作永久存储。

## 第三阶段外观与易用性

第三阶段的 Stylix 颜色、英文默认、tuigreet 样式、P10k/eza/fzf、Niri 直角与 strut、
Noctalia 纯色背景以及加大的 Fcitx5 候选框随同一个 NixOS generation 应用，无需重装系统或
profile。应用步骤与逐项观察清单见 [phase3-manual-checklist.md](phase3-manual-checklist.md)；
设计与锁定来源见 [phase3-decisions.md](phase3-decisions.md)。

- 登录样式在下一次正常退出/登录或启动时出现；应用 generation 不会重启当前桌面。
- 语言在完整退出会话后生效；旧终端可能保留旧环境。
- Noctalia 运行时 theme/wallpaper/plugin-source 覆盖只在第一次 phase-3 激活时迁移一次，
  备份为 `~/.local/state/noctalia/settings.toml.pre-phase3`。
- Fcitx5 接管的 `classicui.conf` 与 `themes/hearth/*` 文件各保留一份
  `.pre-hearth-phase3` 备份；`profile`、Rime 用户数据与同步数据不动。
