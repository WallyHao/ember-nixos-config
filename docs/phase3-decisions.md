# Phase 3 decisions

日期：2026-11-10。记录第三阶段每个关键 option 的锁定来源与验证方式。实际运行结果见
[phase3-report.md](phase3-report.md)，未完成项见 [phase3-status.md](phase3-status.md)。

## 锁定输入

| Input | Revision / hash | 作用 |
| --- | --- | --- |
| root nixpkgs | `f4a03c008967841f2a0b3cb7c436fc6fc31671f6`（未变） | Stylix、Niri 26.04、Foot、Noctalia 5.4.1、Fcitx5 5.1.23、eza 0.23.5、fzf 0.74.5、tuigreet 0.11.1 |
| stylix | `3e27b6c499e507df6e3bb8eca3614f5c95e28140`，narHash `sha256-2pkE97wOXAYIn2/Nhs9y+iR0qVT+g/3UtukXdkywxXc=` | 唯一颜色输入解析与 console/Foot target |
| stylix/base16 | `75ed5e5e3fce37df22e49125181fa37899c3ccd6` | `mkSchemeAttrs`、`withHashtag`、scheme meta/slug |
| home-manager | `2c0c1f01521469cf0271180c453c79782d53c2f6`（未变） | zsh/foot/noctalia/gtk 等 option |

`nix flake lock path:.` 只新增 `stylix` 及其传递节点；比对基线的结果：

- 原有 9 个节点（nixpkgs、flake-parts、disko、preservation、home-manager、nixvim 等）内容完全不变；只有根节点新增 `stylix` 引用。
- `software/flake.lock` 字节未变。
- `stylix.nixpkgs.follows = "nixpkgs"`、`stylix.flake-parts.follows = "flake-parts"`，避免第二套 nixpkgs/flake-parts。
- 未添加 `stylix.inputs.nur` 等自定义 override；NUR 仅在 firefox target 求值时才使用，`autoEnable=false` 下不启用。

## Stylix 接线

- `lib/mk-host.nix` 显式加入 `inputs.stylix.nixosModules.stylix`。该位置覆盖真实配置、preview 与 VM；不放在单个模块的 `imports` 中，因为 VM harness 用 `_module.args` 提供 `inputs`，模块级 `imports` 读取它会形成 `config` 递归。
- Stylix NixOS 模块的 `home-manager-integration.nix` 在 `home-manager` option 存在且 `stylix.enable` 时自动向 `home-manager.sharedModules` 注入 HM 模块；因此不重复导入 `homeManagerModules.stylix`。
- `stylix.enable=true`、`stylix.autoEnable=false`、`stylix.polarity="dark"`、`stylix.image=null`、`stylix.base16Scheme=<assets/themes/emberlight.json>`。
- `autoEnable=false` 意味着除显式 target 外，Starlight 不会启用 GTK/Qt、字体、光标、neovim 等 target（锁定源码 `stylix/target.nix` 的 `mkEnableTargetWith` 默认值 `cfg.autoEnable && autoEnable`）。
- `assets/themes/emberlight.json` 是唯一人工维护的 16 色输入。`modules/nixos/appearance/stylix.nix` 读取一次并补上 `scheme`、`author`、`system`、`variant`、`slug`。
  - `slug` 必须显式提供：base16.nix 的 `convert-scheme-to-common-format` 用 `raw.slug or slugify (raw.name or "untitled")`；不传 `slug` 时生成文件叫 `base16-untitled.*`。
- `config.lib.stylix.colors` 是锁定 base16.nix 的 `mkSchemeAttrs` 结果：顶层颜色为**裸**六位十六进制（如 `base08="b85753"`），`withHashtag.base08="#b85753"`。
- `hearth.appearance.colors` 从 `withHashtag` 派生，保留既有 `#RRGGBB` 兼容接口；`hearth.appearance.name` 取 `colors.scheme`。HM 适配器不再读取 JSON。
- `console.colors` 由 Stylix console target 生成，映射为：0 base00、1 base08、2 base0B、3 base0A、4 base0D、5 base0E、6 base0C、7 base05、8 base03、9-14 bright、15 base07。NixOS `console.nix` 将其写成 `vt.default_red/grn/blu` 内核参数。
- `stylix.targets.foot.enable=true`，并 `fonts.enable=false`：锁定 `modules/foot/hm.nix` 同时写字体、`dpi-aware`、`initial-color-theme`、`colors-<polarity>`、`alpha`。只关闭 font slice，保留 Hearth 的 `LXGW WenKai Mono:size=18`；颜色、alpha=1.0、暗色主题交给原生 target。
- 显式关闭与 Hearth 适配器冲突的 HM target：`fcitx5`、`fzf`、`noctalia`、`nixvim`。锁定 Stylix 确实分别提供这些 target（`modules/fcitx5/hm.nix`、`modules/fzf/hm.nix`、`modules/noctalia/hm.nix`、`modules/neovim/nixvim.nix`）。Niri/eza 没有 Stylix target；它们完全由 Hearth 适配器负责。

## 登录（A01）

- 锁定 tuigreet 0.11.1 `--help` 确认支持：`--no-config`、`--width`、`--container-padding`、`--prompt-padding`、`--asterisks`、`--greeting`、`--time`、`--remember`、`--theme`、`--cmd`。
- 参数用 `lib.escapeShellArgs` 拼接，theme 中的 `;` 不会被 greetd 的 shell 解释。
- 主题使用 ANSI 槽位名称：`container=black;text=white;border=black;title=yellow;greet=blue;prompt=red;input=white;time=darkgray;action=white;button=yellow`。`black`→slot 0→base00，`red`→slot 1→base08，`yellow`→slot 3→base0A，`blue`→slot 4→base0D，`white`→slot 7→base05，`darkgray`→slot 8→base03。
- 保留 `--time`、`--remember`；没有 `initial_session`、没有自动登录、没有记忆密码。
- `systemd.services.greetd.restartIfChanged=false`：应用新登录样式不重启正在运行的 greetd/桌面；下一次正常登录或启动才显示新样式。

## 默认语言（A02）

- `i18n.defaultLocale="en_US.UTF-8"`，supported locales 保留 `en_US.UTF-8/UTF-8` 与 `zh_CN.UTF-8/UTF-8`。
- NixOS `config/i18n.nix` 会把 `environment.sessionVariables.LANG` 设为 defaultLocale；未设置 `LC_ALL`，未设置 `i18n.extraLocaleSettings`。
- 时区仍 `Asia/Shanghai`，键盘仍 `us`；Fcitx5/Rime 与中文字体不变。
- 已运行的终端与 user manager 可能保留旧环境；需完整退出会话再登录，不能只在新 shell 临时 export。

## P10k（A03）

- `modules/home/terminal/resources/p10k.zsh` 来自 Folio `modules/terminal/cli/resources/p10k.zsh`，上游为 `romkatv/powerlevel10k/config/p10k-pure.zsh`（MIT），保留来源头注释；不引用 repo 外路径。
- 加载顺序：先 source 本地资源（其内部 `unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~...'`），再写 Hearth 颜色和 wizard/instant prompt 覆盖，最后 source `powerlevel10k.zsh-theme`。顺序反了资源会清掉颜色。
- 结构与 Folio 一致：左 `context dir vcs command_execution_time virtualenv prompt_char`，右 `time`，24 小时；`PROMPT_ADD_NEWLINE=true`；透明背景；无 segment 图标；`❯`/`❮`；耗时阈值 5 秒；VCS 异步、无自动 fetch。
- 颜色：目录 base05、目录分隔符/时间/context base04、目录高亮与成功 prompt base08、Git base0B、incoming/outgoing/virtualenv base0C、耗时 base0A、错误 prompt base08；root/SSH context 模板也替换为 Hearth 颜色。资源内的 `242`、`1`、`3` 等局部颜色不再可见。
- `POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true`，`POWERLEVEL9K_INSTANT_PROMPT=quiet`，`POWERLEVEL9K_MODE=nerdfont-complete`（symbols-only 字体已安装）。
- HM zsh 的 `initContent` 默认优先级 1000：位于 autosuggestions(700) 之后、shell aliases(1100) 与 syntax highlighting(1200) 之前（`modules/programs/zsh/default.nix`）。P10k 与 zsh widgets 都在 syntax highlighting 之前完成。
- 移除了 `programs.zsh.plugins` 的 fzf-tab 入口：它会在 900 无条件 source，无法做命令存在检查；改为在 tools.nix 的 guarded block 中手动 source 一次。

## eza / fzf（A04）

- 不启用 `programs.eza` / `programs.fzf`：锁定 HM `modules/programs/fzf.nix` 的 `programs.fzf.enable` 会向 `home.packages` 加入 fzf，违反 profile 归属边界。eza/fzf/fd/zoxide 仍由 `software/` profile 提供。
- eza 在 `command -v eza` 成功后才定义函数；函数调用 `command eza`，避免 alias/函数自递归。`l`/`ls`/`la` 固定 `--tree --group-directories-first -L 1`，`ll` 默认 1、`lt` 默认 5，首参数为整数时作为深度并使用 `"$@"` 透传空格路径。
- 锁定 eza 0.23.5 的 `src/theme/lsc.rs` 测试确认支持 `38;2;R;G;B` RGB 语法；`src/theme/mod.rs` 要求 `reset` 必须是第一个 entry，否则默认扩展名颜色会保留。因此 `EZA_COLORS` 以 `reset:` 开头，再给出全部 Hearth 角色：
  - `di` base0D、`ln` base0C、`ex` base0B、`or` base08、`tw/su/sf` base0A、`fi` base05、`da/uu/un/gu/gn/lc/sn/sb/hd/lp/xx` base04。
  - RGB 分量取自 `config.lib.stylix.colors.<baseXX>-rgb-r/g/b`，不重复解析 JSON。
- fzf 手动集成：先检查 `command -v fzf`，再 export 唯一的 `FZF_DEFAULT_OPTS`（HM fzf 未启用，因此不会出现第二个定义），source 锁定 `pkgs.fzf` 的 key-bindings/completion 与 `pkgs.zsh-fzf-tab` 插件。
- fzf 选项与 Folio 一致：`--height=45% --layout=reverse --border=sharp --info=inline --prompt='> ' --pointer='>' --marker='+'`；颜色键为 fzf 真实名称 `bg/bg+/fg/fg+/hl/hl+/info/prompt/pointer/marker/spinner/header/border`，值来自 Hearth。
- `fd` 存在时设置 `FZF_DEFAULT_COMMAND` 与 `FZF_CTRL_T_COMMAND` 为 `fd --type f --hidden --follow --exclude .git`，`FZF_ALT_C_COMMAND` 为 `--type d`；不写宿主 store 路径。
- 键位：保留 fzf 原生 Ctrl-r/Ctrl-t/Alt-c，新增 `Alt+j` 历史、`Alt+k` 文件、`Alt+l` 目录，Tab → `fzf-tab-complete`；`zstyle ':fzf-tab:*' use-fzf-default-opts yes` 复用同一套颜色与布局；`switch-group '[' ']'`；`menu no`。不覆盖 Ctrl+Space 与 Super 快捷键。
- zoxide 仍在命令存在时初始化；compinit 由 HM `enableCompletion` 只执行一次。

## Niri（A05）

- 锁定 niri 26.04。`layout.struts` 是 `layout` 内的节点，值单位为 compositor 逻辑像素；显式 `top=8`、其余 0。
- Noctalia bar 保持 34 px、顶部、`reserve_space=true`（layer-shell exclusive zone）。Niri 额外 8 px 是 Hearth 的呼吸空间；不复制 Folio 仓库默认或已生成配置中的负 top strut。
- `window-rule.geometry-corner-radius=0`，只有一条 window-rule，无例外恢复圆角；保留 `prefer-no-csd`、gaps 16、focus ring 宽度 3、列宽/工作区/按键。
- 颜色（focus ring base08、背景 base00、overview base00）继续通过 `hearth.appearance.colors` 从 Stylix 派生。
- 不硬编码显示器名称/分辨率/刷新率/缩放；`tile_pos_in_workspace_view.y >= 42` 的 VM 断言只用于证明 34+8 的顶部预留，不当作像素级视觉验收。

## Noctalia（A06）

锁定 Noctalia 5.4.1 源码（nixpkgs 包；检查时 store 名 `srdcxbw5wryvyl9fvkyfqka57yd5dk5x-source`，配置中不引用该绝对路径）：

- 声明字段来自 `src/config/schema/config_schema.cpp` 的 `wallpaperSchema`/`themeSchema`/`pluginsSchema`：
  - `[wallpaper] enabled`、`fill_mode`、`fill_color`（ColorSpec：角色 token 或固定 hex）、`transition_on_startup`、`automation.enabled`。
  - `[[plugins.source]]` 的 `name`、`kind`、`location`、`enabled`；`[plugins].auto_update` 只接受 `"all"|"official"|"none"`（boolean 形式已不支持）。
- 背景策略：`wallpaper.enabled=true`、`fill_color=base00`、`transition_on_startup=false`、`automation.enabled=false`，不设置 `[wallpaper.default].path`（该表只从运行时 overrides 读取，不在 `wallpaperSchema` 中）。
- 渲染依据 `src/shell/wallpaper/wallpaper.cpp`：fill node 始终铺满 surface；无图片 texture 时只显示 `fill_color`。若 `wallpaper.enabled=false` 则完全不创建 wallpaper layer，桌面只剩 Niri 背景，因此本计划选择 enabled=true。
- 首次运行特殊路径 `ConfigService::firstRunWallpaperPath()`：`.setup-complete` 不存在且没有已配置壁纸时，会返回内置 `noctalia-wallpaper.png`。`setup_wizard_enabled=false` 使向导不运行，因此 Hearth 的激活脚本创建 `.setup-complete`（空标记）以走到纯色分支。它不是主题字段，也不删除任何状态。
- `settings.toml` 优先级：`config_merge.h` 注明 state-dir `settings.toml` 在 config-dir 之后 overlay；`config_service.cpp` 的 `deepMerge(merged, effectiveOverrides)` 让 runtime 值获胜，数组整体替换。因此迁移必须删除 appearance-owned 的 runtime key。
- 迁移脚本 `modules/home/desktop/noctalia-state.py`（tomlkit，保留格式/注释/其余状态）：
  - 只删除 wallpaper 的 default/last/monitors/monitor/automation 与 enabled/fill_mode/fill_color/transition*/directory*/per_monitor_directories；theme 的 mode/source/builtin/community_palette/custom_palette/wallpaper_scheme/shell_mode/pure_black_dark/sync_color_scheme；plugins 的 auto_update/source。
  - 保留 `wallpaper.favorite`、`plugins.enabled` 以及所有其他 runtime 状态。
  - 首次修改前备份 `settings.toml.pre-phase3`；完成后写 `.hearth-phase3-appearance` 版本标记，重复激活直接跳过，不再覆盖用户之后的选择。解析失败时不写标记，下一次激活可重试。
  - 激活顺序 `entryBetween ["linkGeneration"] ["writeBoundary"]`：在 HM 链接 managed 文件之前、writeBoundary 之后运行。
- 插件离线缺口：`auto_update="none"`，`official` 与 `community` 两个默认 git source 均 `enabled=false`。锁定 `docs/user/plugins/index.mdx` 与 `config_types.cpp` 确认 `enabled=false` 阻止扫描和更新；`shell.offline_mode` 不能替代。
- 保留 bar widgets、notification、clipboard、Polkit、session panel；palette 的所有颜色从兼容接口派生，调色板键名为 `customPalettes.emberlight`。

## 输入法（A07）

- 进程与服务仍由 `modules/nixos/desktop/input-method.nix` 的唯一 `hearth-fcitx5.service` 管理；HM 只写外观文件。
- 主题格式依据锁定 Fcitx5 5.1.23 自带 `share/fcitx5/themes/default-dark/theme.conf` 的键：`NormalColor`、`HighlightCandidateColor`、`HighlightColor`、`HighlightBackgroundColor`、`PageButtonAlignment`、`[InputPanel/Background]`、`[InputPanel/Background/Margin]`、`[InputPanel/ContentMargin]`、`[InputPanel/TextMargin]`、`[InputPanel/PrevPage]`、`[InputPanel/NextPage]`、`[InputPanel/ShadowMargin]`、`[Menu/*]`。
- 面板背景 base01、正文 base05、边线/高亮候选 base08、弱文字 base04（Menu separator）、高亮背景透明；九宫格 margin 18、ContentMargin 12/8、TextMargin 8/6、ShadowMargin 0。
- `classicui.conf`：`Theme=hearth`、`Font=LXGW WenKai Mono 20`、`Vertical Candidate List=False`、`PreferTextIcon=False`。`fc-scan` 在锁定 `lxgw-wenkai-1.530` 上确认 family 为 `LXGW WenKai Mono`（无 `GB`）。
- `panel.png` 由 SVG 经锁定 librsvg 在构建期生成，不增加运行时转换进程。
- Rime patch 增加 `menu/page_size: 7`，保留原 `rime_ice_suggestion` 与 `schema_list`；不重置用户词典/词频。
- `~/.config/fcitx5` 与 `~/.local/share/fcitx5` 整体持久化：仅在 `linkGeneration` 前对 `classicui.conf`、`themes/hearth/theme.conf`、`themes/hearth/panel.png` 做存在性判断和一次性 `.pre-hearth-phase3` 备份，不覆盖整个目录。

## Foot（A08）

- `main.pad="15x15"`、字体 18、block cursor、不闪烁、不启用 server，全部保留。
- 颜色表、`alpha`、`dpi-aware`、`initial-color-theme` 由 Stylix 原生 Foot target 唯一生成（`modules/foot/hm.nix`）；本模块只保留 `cursor` 与 `selection-*` 等 target 未负责的键。
- `foot --check-config` 在 `desktop-config` check 中实际通过；`alpha` 序列化为 `1.000000`，为不透明。

## 证据文件

- 生成配置由 HM 断言与 `desktop-config` check 校验；VM 真实交互与截图见 phase3-report。
- 实机未验证项（物理缩放下 bar 间距、真实显卡下颜色、输入法边缘定位等）保留 `REAL_MACHINE_PENDING`，不写成 PASS。

## 2026-11-10 实机反馈后的外观修订（覆盖上文同名旧值）

- 保留当时 Stylix 的 16 色映射结构（2026-11-13 已换为 Emberlight，见文末），取消“所有强调均用 base08”的视觉处理。Niri 焦点环为 base08 → base0A、55° 渐变；输入法边框为 base0D → base0E → base08，候选高亮为 base08 → base0A、base00 深色字。没有新增第二份手写色板。
- Noctalia 显式关闭默认浮动 bar 的屏幕边缘距离和向内附加留白，保留 34px exclusive zone；Niri gaps=16、top=-10，设计窗口至 bar 间隙为 6px，焦点环宽 3px。左右和底部窗口间距保持原值。物理缩放下的结果待用户观察。
- 状态栏左右各一组，中心留空、两端 padding=24、组内 spacing=14；左侧 launcher/workspaces/media/notifications/clipboard/control-center，右侧 tray/network/volume/battery/clock/session。媒体最长 180px、无媒体时隐藏。工作区用无文字、等宽等高圆点；焦点红、占用蓝紫、空闲暗紫、紧急藕紫。
- 保留 tuigreet 和既有 PAM；使用 Terminus ter-v32n（16×32）控制台字体、居中的小型 NixOS ASCII 雪花与 Hearth 字标。border=black 与 ANSI 黑色背景一致，视觉上隐藏框线；没有声称 tuigreet 支持不存在的 border-disable 参数。文字登录不能绘制 SVG/任意字体大小或真彩渐变。该 console 字体也适用于救援 TTY。小型 ASCII 图案参考 neofetch 的 nixos_small。
- Noctalia 迁移标记升级 v2；旧版标记会触发一次指定 bar/widget 外观键迁移，备份为 settings.toml.pre-phase3-refinement，不触碰插件启用列表、收藏、网络标签等其他状态。后续激活不再覆盖用户新改的值。
- 按用户要求不运行 VM：desktop-config、eval-user-environment 与实际 Hearth toplevel 构建成功；用临时状态目录确认 v1 → v2 迁移、无关状态保留及第二次不修改。仅最初选择的 Python 环境缺少 tomlkit，随后用实际构建包装器的 Python 完成该检查。
- 系统产物：`/nix/store/f2hc14rl2g6rsz7m3qz7w4xn8045gblv-nixos-system-hearth-26.11.20261107.dirty`。本轮没有激活实机或重启；实际外观等待用户反馈。


## 2026-11-10 第二次实机反馈：可读性与 Logo

- 状态栏厚度 42px、内容 scale=1.25、文字 font_scale=1.25；基础 body 14px 时约 22px。工作区 pill_scale 从 0.4 调至 0.9，16px 基准 × 1.25 × 0.9 ≈ 18px；等宽等高圆点，不变成长胶囊。Niri top=-10、gaps=16 仍保留 6px 窗口间隙。
- 左侧只保留工作区；右侧 tray/network/volume/battery/clock。移除 launcher/media/notifications/clipboard/control-center/session 的栏按钮，不禁用对应服务或快捷键。网络保留放大状态图标，音量 show_glyph=false、电量 display_mode=none，两者保留数字。日期时间不附加图标。
- Noctalia 迁移标记 v3，新增 scale/font_scale 和相关标签/图标键；一次备份 settings.toml.pre-phase3-readability，保留以前的备份。
- Logo 来自 Fastfetch MIT 许可的 nixos2（版本 6a82126aa99a81bd4c083f37ef52c140c1438c40），17 行、32 列的 ASCII 轮廓雪花。原文件、许可证及来源放在 modules/nixos/desktop/resources/。先按可见宽度补齐行，再替换 ANSI 色标；修复逐行居中扭曲形状及反斜杠人工转义问题。红/浅砂金使用 Stylix ANSI 槽，不引入 Nerd Font 字符，不在登录时下载或运行 Fastfetch。
- 实际构建的 wrapper 截获参数检查：17 行等宽、32 列、纯 ASCII、niri-session 参数保留，bash -n 通过。实际 greetd 在空 /etc 的 bubblewrap 中越过配置解析，进入预期的 PAM 缺失检查；不等于真实登录完成。
- desktop-config、eval-user-environment、Hearth toplevel 构建成功；没有 VM 测试。本轮初次构建命令误从外层目录调用，因无 flake.nix 立即退出，随后在项目目录构建通过。
- 新产物：/nix/store/w1bjl1fm33ia75z20xzzl5g0prxvfbd5-nixos-system-hearth-26.11.20261107.dirty。内置盘当前未挂载，本轮尚未部署；实机外观需用户确认。

## 2026-11-13 调色板切换：Emberlight（覆盖上文全部颜色值）

- 来源：用户提供的 `/home/folio/Temp/emberlight/index.html`（`base16-emberlight` 预览页）。16 色取自页面 `:root` 的 `--base00`…`--base0F`，与页面内 base16 YAML 片段一致；未引入第二份颜色数据。
- 唯一输入改为 `assets/themes/emberlight.json`：`name="Emberlight"`、`author="seeds #120b13 #753843 #c43433 #fedd81"`、`system="base16"`、`variant="dark"`。Stylix 仍只启用 `console`（系统）与 `foot`（HM）target，`autoEnable=false` 不变。
- 关键槽位：base00 `#120B13`、base02 `#301D2A`、base03 `#5A3A4A`、base05 `#DCC9D2`、base08 `#B85753`、base0A `#EDD5A2`、base0D `#8C90C2`、base0E `#AE90C0`、base0F `#753843`。`base08` 相对旧值变暗，登录提示色因此从珊瑚变为砖红；`base0D` 从雾蓝变为蓝紫。
- 所有适配器继续通过 `config.lib.stylix.colors` / `hearth.appearance.colors` 派生，没有逐组件手改 hex：console、Foot、Noctalia、Niri、P10k、eza、fzf、Nixvim、Fcitx5 同步变化。
- Noctalia 调色板键由 `hearth` 改为 `emberlight`，生成文件为 `~/.config/noctalia/palettes/emberlight.json`，`theme.custom_palette="emberlight"`；`noctalia-state.py` 的迁移版本升至 `hearth-phase3-appearance-v4`，会再清理一次 runtime 的 `theme.custom_palette`，避免残留的 `"hearth"` 指向已删除的调色板；之后仍不覆盖用户的新选择。`hearth.appearance.*` 模块命名空间和 Fcitx5 主题名 `hearth` 属于系统/组件标识，未重命名。
- tuigreet 仍使用 ANSI 槽位名（`black`/`white`/`yellow`/`blue`/`red`/`darkgray`），不写死 hex；登录配色随 console 调色板变化。控制台颜色经 `vt.default_*` 内核参数生效，实机需要在**下一次启动**后观察；`greetd.restartIfChanged=false` 不会中断当前桌面。
- 可读性风险：新 base03 `#5A3A4A` 在 base00 上约 1.97:1，登录界面右上角时间用 `darkgray`（slot 8→base03）会明显变暗；这是预览页对“注释/弱信息”的定位。若实机不可读，可把 tuigreet 的 `time` 改为 base04（`#8B6F80`，约 4.32:1），或将 theme 改为从 `config.lib.stylix.colors.withHashtag` 生成 hex；本轮未擅自改变既有角色映射。
- 验证（本轮实际执行）：
  - `eval-user-environment`：通过；断言 `stylix.base16Scheme.base00=="#120B13"`、`console.colors` 含 `b85753`、Noctalia 键为 `emberlight`。
  - `desktop-config`：通过；生成的 `foot.ini` 为 `background=120b13`、`foreground=dcc9d2`、`regular1=b85753`、`regular4=8c90c2`、`bright0=5a3a4a`，`alpha=1.0`。
  - `system-preview` toplevel：构建成功；`hearth.appearance.name=="Emberlight"`，slug 为 `emberlight`。
  - `console.colors` 实测为 `["120b13","b85753","8aa073","edd5a2","8c90c2","ae90c0","7ba29b","dcc9d2","5a3a4a","b85753","8aa073","edd5a2","8c90c2","ae90c0","7ba29b","faf3f1"]`。
  - 生成物抽查：`.zshrc` 的 `POWERLEVEL9K_DIR_FOREGROUND='#dcc9d2'`、eza 使用 `38;2;140;144;194`；Fcitx5 `HighlightCandidateColor=#120b13`；Noctalia `custom_palette="emberlight"`、`fill_color="#120b13"`。
  - VM 测试另行记录；未运行的部分不写成通过。
