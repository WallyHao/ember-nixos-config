# Ember 第四阶段实现与针对性验证报告

日期：2026-11-13。源码备份：`/tmp/ember-phase4-before-1794544966`。
未在宿主激活、安装用户 profile、改变活跃网络/代理或操作实盘分区。

## 实现

- 配置目录、hostname、inventory、options、flake、CLI 统一为 Ember；保留必要旧名称兼容。
  wallyhao/UID1000、密码、stateVersion、硬盘标签与持久数据身份不变。
- Emberlight 是 Stylix 的唯一色板；登录标题明确为 **EMBERLIGHT**，主机名为 ember。
  登录使用 Fastfetch MIT NixOS ASCII 图案、17×32、44列居中表单、ter-v32n。
  greetd TOML 仍只含单行 wrapper 路径，避免旧解析器导致的黑屏问题。
- Waybar/Fuzzel/Mako/Niri/Fcitx5 采用 Folio 外观参数，颜色来自 Emberlight；撤除 Noctalia。
  独立 Polkit、壁纸、运行时剪贴板、swaylock/swayidle、控制菜单、媒体/亮度操作补齐职责。
- profile 通过原生 Nix 管理，提供 `just profile install`；保留旧 origin/bundle 的有界迁移。
- 代理保留 Ember 的规则/DNS/TUN，仅复用 Folio 节点、订阅与必要认证数据。
  私有资料工具按 UUID 复制已保存连接；敏感资料不会写入源码或 Nix store。

## 通过的实际检查

| 检查 | 结果 |
| --- | --- |
| Bash 语法、ShellCheck、Nix 格式、bootstrap 指纹 | PASS |
| `bash tests/cli.sh` 模拟后端 | PASS：参数传递、失败保留、旧缓存迁移、幂等、配置变更与离线路径 |
| 代理 normalize/assemble 数据检查 | PASS：节点/URL/认证保留、排除外来策略、拒绝非法数据、私有权限 |
| 最终真实系统、eval-contracts、eval-user-environment、desktop-config 构建 | PASS |
| greetd 实际配置/启动参数 | PASS：TOML 可解析、wrapper 语法正常、17行等宽图案、EMBERLIGHT、niri-session |
| vm-connectivity | PASS，102.68秒；仅虚拟网络，无实盘或真实订阅 |

代理 VM 覆盖：初始无网络、虚拟上游、节点导入/检查、TUN、DNS/fake-IP、节点故障 DIRECT
回退与恢复、非法来源保留旧配置、关闭后撤销、disabled/网络资料跨重启持久化。

真实系统构建命令：

```sh
nix build --no-link --print-out-paths --no-update-lock-file \
  path:.#nixosConfigurations.ember.config.system.build.toplevel \
  path:.#checks.x86_64-linux.eval-contracts \
  path:.#checks.x86_64-linux.eval-user-environment \
  path:.#checks.x86_64-linux.desktop-config
```

最终产物：

- 系统：`/nix/store/kv4ik3z11gfc3bp2y88zi9sgikvm1sx2-nixos-system-ember-26.11.20261107.dirty`
- eval-contracts：`/nix/store/l66vmn4p2z0m8fva621dmg509297krfq-ember-eval-contracts`
- eval-user-environment：`/nix/store/niqbzrpi18lvjjwhhbydlkzg7qnlcp4p-ember-eval-user-environment`
- desktop-config：`/nix/store/7y3vkvirhn4pjm1bzdk8wfc1371wb90g-ember-desktop-config`
- 迁移工具：`/nix/store/kjqj1qpwrgbxc0973kyw2qxf712zc3kd-ember-migrate-folio-data`
- 软件：`/nix/store/y9a83bvmj5pg06rx5b3xdj2lny07ar09-ember-workstation`
- 代理 VM：`/nix/store/a842ya2gs3knkmpbfhhq406qr5rr195z-vm-test-run-disko-ember-vm-connectivity`

## 桌面验证与修复

只运行与新桌面相关的 VM，没有重跑 accounts/persistence/offline 等全套历史测试。
测试发现真实问题后只重跑受影响桌面；代理通过后不重复运行。

1. 壁纸、剪贴板和 Polkit 在 Wayland 环境导入前启动，导致启动失败。
   修正为 After graphical-session.target/niri.service，并提供失败重试间隔。
2. 此锁定版 Home Manager 的 Mako 模块不生成 systemd unit，只有配置和 DBus 包。
   补齐完整 DBus 服务（ExecStart、BusName、会话依赖），避免空服务。
3. 图形 VM 的 root 读取用户 portal FUSE 目录受限；改为会话用户查找 socket。
   此项是测试脚本修复，不是生产权限放宽。
4. 通知默认仅显示5秒，OCR 未及时命中；改为测试通知延时30秒并通过 Mako 自身列表确认接收，保留截图。

修复后已观察到 EMBERLIGHT 登录、错误密码拒绝/正确密码登录，以及 Waybar、Mako、
壁纸、Polkit、剪贴板全部 active；离线 profile 安装及幂等、OMP、Foot 真实输入、启动器检查通过。Mako 消息接收及剪贴板文字/图片恢复也已通过。完整桌面 VM 未整体通过。

后续权限测试首先误用了未启用的 pkexec wrapper；实际日志为 `pkexec must be setuid root`。
生产默认没有启用该可选入口，不能据此判断 Polkit agent 失败。测试已改为 pkcheck
和仅虚拟机提供的认证 action，但按用户再次要求收敛测试，已停止该轮重跑。
因此权限弹窗取消、锁屏/解锁及电源确认仍为 **NOT_VERIFIED**，不记为 PASS。
未扩大系统提权设置来迎合测试。

## 实机与私有资料边界

虚拟测试使用仅测试的 Niri software-EGL overlay；生产没有该覆盖。
不把虚拟 llvmpipe 结果当成实机 GPU/睡眠/性能结果。

Folio 的实际 root 私有资料还未复制，需要用户在本地执行 sudo；虚拟来源通过不表示
真实订阅可达。真实 Wi-Fi、输入法体验、亮度/音频、休眠/唤醒和外观需要进入 Ember 观察。
旧 Noctalia 数据保留，新剪贴板为会话历史，不宣称跨重启历史等价。

部署命令见 [phase4-deployment.md](phase4-deployment.md)。

## 后续：默认安装 Zen

默认软件列表新增 `zen`，复用 Folio 的 zen-browser-flake rev a12d482485d877cc066516ea256b435b209a1a8c，
仅浏览器包，不引入 Folio 扩展或个人 profile。新增 `.config/zen` 0700 持久化。
软件集合构建通过，`zen-beta --version` 为 `Mozilla Zen 1.22.2b`；真实系统构建通过。
本次没有 VM 重跑。上面的较早构建/VM 记录保留原有含义。

- 当前系统：`/nix/store/43dcm9956whxg9gb1a5s19xfi4m06kbb-nixos-system-ember-26.11.20261107.dirty`
- 当前软件：`/nix/store/w6asvpz4dw32i6pifjp6y7gwf40aj4c7-ember-workstation`

bootstrap 缓存及指纹同步更新；前一代 Ember 缓存加入精确迁移清单，安装成功后再清理旧条目。
