# Phase 3 manual checklist

应用说明：本轮只交付代码、构建与隔离 VM 验证，不自动部署、重启或停止当前会话。
系统级（locale/console/greetd）与 HM 级（桌面/终端/输入法）随同一个 NixOS generation
生效；用户软件 profile 不需要重装。应用前确认当前运行的确实是 Hearth，并保留上一代
generation 用于回退。

## 应用前

1. 确认主机：

   ```sh
   hostname                 # hearth
   id -un                   # wallyhao
   readlink /run/current-system
   ```

2. 确认已安装的 profile 仍在：

   ```sh
   readlink ~/.local/state/nix/profiles/profile
   eza --version
   fzf --version
   fd --version
   zoxide --version
   ```

3. 把当前配置仓库更新到本阶段产物，记录当前 generation：

   ```sh
   cd ~/Workspace/hearth-nixos-config
   nixos-rebuild list-generations | tail -5
   ```

4. 需要时只读查看将应用的登录命令与颜色（不激活）：

   ```sh
   nix build --no-link --print-out-paths --no-update-lock-file path:.#packages.x86_64-linux.system-preview
   ```

## 应用（由用户执行）

具体 sudo 命令在部署上下文明确后给出；不要从开发工作区替用户执行。应用后先保留
上一代 generation，不要立即 GC。

## 应用后观察

### 登录界面

1. 完全退出 Niri 会话；greetd 不会因 activation 被打断（`restartIfChanged=false`）。
2. 在下一次登录界面确认：大号 Terminus 字体、无可见边框、居中的 Fastfetch nixos2 双色情况下仍等宽的 ASCII 雪花与
   `H E A R T H`、蓝紫图案/砖红提示/浅砂金操作色、星号密码和顶部时间。
3. 先输入错误密码，确认被拒绝且没有进入 Niri；再输入正确密码登录。
4. 确认 keyring 正常解锁，剪贴板历史仍可读。

### 语言与终端

1. 在 Foot 中运行 `locale`，确认 `LANG=en_US.UTF-8`，且没有 `LC_ALL`。
2. 运行一个失败命令（例如 `ls /nonexistent`），确认错误信息为英文。
3. 用 Fcitx5 输入中文，确认显示正常（字体、宽度、选择都能工作）。
4. 确认提示符：右侧时间、空行、`❯`，成功/失败/耗时/Git 状态颜色为 Hearth；
   没有第一次启动的 wizard。
5. `l`、`ls`、`la`、`ll 2`、`lt 2` 的行为与深度符合计划；带空格路径可以正常打开。
6. `Ctrl+r`/`Ctrl+t`/`Alt+c` 与 `Alt+j`/`Alt+k`/`Alt+l` 打开 fzf；Esc 取消后当前目录不变；
   Tab 打开 fzf-tab 且 `[`/`]` 可切换分组。

### 桌面

1. 普通平铺、最大化列、切换工作区后，Noctalia bar 仍完整可见，窗口不覆盖 bar。
   bar 贴顶、高 42px，设计窗口间隙 6px；左侧仅工作区大圆点（约 18px），右侧为托盘、
   网络、音量数字、电量数字、日期时间，文字约 22px；焦点边框为砖红至浅砂金渐变。
2. 窗口角为直角；foot 与 GTK 窗口都没有残留圆角。
3. 桌面空白区域是统一纯色 base00，没有内置壁纸、渐变或取色结果。
4. `Super+...` 原快捷键仍工作；全屏应用允许覆盖 bar（Niri 语义）。

### 输入法

1. 候选框字体为 20，内部间距 ContentMargin 12/8、TextMargin 8/6；外框为蓝紫/藕紫/砖红
   渐变，选中词为浅砂金底色及深色文字。
2. 候选为横向，每页最多 7 个；翻页、长词、标点在屏幕边缘和物理缩放下不裁切。
3. 退出并重新登录后主题仍为 Hearth；Rime 用户词库/词频没有被重置。
4. 只有一个 fcitx5 进程（`pgrep -u wallyhao -x -c .fcitx5-wrapped` 为 1）。

### 回退

1. 保留上一代 generation；如样式或输入异常，可在登录前从 boot menu 选择上一代或使用
   `nixos-rebuild --rollback`（由用户在实机执行）。
2. 用户运行时的选择（壁纸/主题/插件源）只在第一次 phase-3 激活时迁移一次；
   原迁移备份为 `~/.local/state/noctalia/settings.toml.pre-phase3`；本次 v2 外观修订还会做一次
   带版本标记的指定 bar/widget 键迁移，备份为 `settings.toml.pre-phase3-refinement`。
   第二次可读性修订（v3）备份为 `settings.toml.pre-phase3-readability`，保留之前所有备份。
3. Fcitx5 接管的文件备份为对应文件的 `.pre-hearth-phase3`；不会覆盖 `profile`、
   Rime 用户数据和同步数据。

## 仍需实机确认

- 物理分辨率/缩放下的 bar 间距是否合适；如需调整，记录测量依据再改 top strut。
- 真实显卡与显示器上的颜色、直角、字体渲染。
- 输入法候选框在真实屏幕边缘/多显示器下的定位。
- Wi-Fi、代理和其它原始功能在本 generation 上继续工作（本阶段未改这些模块）。