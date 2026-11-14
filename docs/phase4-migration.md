# Ember 迁移说明

本文件描述源码已准备的迁移方法，不表示已经部署或复制私有资料。
源码迁移后已按用户要求进行针对性验证；结果见 phase4-report.md，部署命令见 phase4-deployment.md。

## 1. 名称与数据边界

| canonical Ember | 兼容旧值/保持不变 |
| --- | --- |
| ember-nixos-config、scripts/ember | 旧源码目录链接、scripts/hearth shim |
| nixosConfigurations.ember | hearth 输出临时指向同一个 Ember 配置 |
| ember.*、lib.ember、emberLaptop | 新源码内部统一 Ember；不维护两套模块 |
| ember-proxy、ember-fcitx5、ember-yazi | hearth-proxy/helper 与旧 flake origin 的迁移兼容 |
| ember-base、ember-workstation | 精确记录已存在的旧 Hearth store path，不伪造替换 |
| Emberlight | 不再使用旧 Hearth 主题、Noctalia 动态主题或 Folio 的旧 RGB |

用户、UID、home、stateVersion、现有密码、PAM 修复、keyring、Rime、OMP 与软件
profile 的持久路径不变。GPT 标签、HEARTH_EFI/HEARTH_SYSTEM、by-id、子卷均不变。
旧 `.local/state/noctalia` 仅保留数据以便回退；无旧 shell、主题迁移器或 IPC 动作运行。

## 2. 外观移植

只移植 Folio 的独立 renderer、CSS、输入状态 observer 与 GB 字体包定义。
不引入 Folio manager/YANG/subscriber 框架；不复制个人词库或整套账号配置。

- Waybar：36px 栏高、18px 字体、圆点9/14px、左工作区/右输入语言与日期时间。
- Fuzzel：40×8、18号、无图标、3px直角边框、Folio 原内边距与交互。
- Mako：18号、右上、1px直角边框、5秒、无历史。
- Niri：gaps16/top-12、纯色3px焦点环、直角，不保留 Hearth 渐变。
- Fcitx5：18号、Folio 原边距、透明选中背景/强调色文字，主题名 emberlight。
- 所有 RGB 来自 Stylix 解析的 assets/themes/emberlight.json。
- 登录保留17×32 ASCII、44列输入区域、ter-v32n 与单行 greetd wrapper，配色角色
  通过原生 Stylix console palette 映射；不把多行图案重新写进 greetd TOML。

额外工具按需补位：独立 Polkit agent、纯色 swaybg、运行时 cliphist、swaylock/swayidle、
Fuzzel 控制/电源菜单、wpctl、brightnessctl、nmtui、pavucontrol。桌面必需工具不依赖
用户先装 profile。虚拟桌面的验证结果另列；实机睡眠、硬件操作与外观仍需观察。

新剪贴板只保留会话内历史，位于 XDG_RUNTIME_DIR、锁屏与退出时清理；不将其明文
DB 持久化。旧 Noctalia 跨重启加密历史保留原数据，不解密导入，也不声称等价替代。

## 3. 复用 Folio 的资料，不复用代理配置方法

代理仍采用 Ember 的 TUN、规则分流、DNS 和 AUTO/NODES 结构。
外来 sources 只允许节点与 HTTP 订阅来源/访问认证，不导入规则、DNS、监听器或命令。
静态节点和订阅 URL 都保存在 root 私有的 `/var/lib/hearth-proxy/sources.yaml`；
运行时 config.yaml、节点、订阅缓存及私有服务日志也在该目录；service.log/validation.log
只供本地 root 排错，不应粘贴到聊天。旧目录名是为了保留原有状态。

`just migrate-folio-data` 是本地资料复制入口，需在 Folio 运行、内置盘已挂载到 /mnt，
由用户本地 sudo 验证身份。它会：

1. 验证 persist/boot 两个挂载点为原有 HEARTH_SYSTEM/HEARTH_EFI 标签。
2. 从 `/var/lib/folio-mihomo/config.json` 与其私有 provider/cache 来源中筛选实际
   proxies、订阅 URL/认证头；不把 Folio 的 rules/DNS/proxy-groups 拷成 Ember 配置。
3. 写入目标 `/mnt/persist/var/lib/hearth-proxy/sources.yaml`，目录0700、文件0600，
   已有 sources 和相同 UUID 的网络资料先做私有备份；关闭标记保留。
4. 按 UUID 复制 `/etc/NetworkManager/system-connections` 的连接资料到目标持久目录。
   root:root、0600；不复制 machine-id、keyring、账号或 Folio 网络管理框架。
5. 仅输出数量和状态，不输出节点、URL、SSID 或密码，不改变 Folio 活跃服务。

若报告 connections_needing_agent_secret 大于0，表示部分连接的 keyfile 不含可复用
密码，需要在本地授权会话补齐；不能将复制 keyfile 等同于所有连接认证已完成。
订阅格式不支持或节点重名等问题会明确失败，工具不猜测/制造节点、不向第三方转换站发送链接。
资料复制包含多个目标文件，不声称整个过程原子；失败后先查看私有备份与目标状态再重试。

当前源私有目录不可由本会话免密码读取，**该步骤尚未执行**。不要通过聊天粘贴私有资料。

## 4. 目标机源码目录与 profile 过渡

当前工作区的 canonical 源目录已改为 ember-nixos-config，hearth-nixos-config 是兼容链接。
目标机的持久仓库尚未自动改名。准备复制新源码时：

- 原目录存在、新目录不存在：将目标的旧目录移动为新目录，再建立旧名称的相对链接。
- 新旧目录都已有内容：先比较/保存各自变更，不能盲目覆盖或执行 rm -rf。
- 新源码复制到新目录，旧链接必须一直解析到同一个新目录，保证 native profile 的旧
  `originalUrl=path:.../hearth-nixos-config/software` 还能读取软件 flake。
- 新 helper 同时识别旧/新 origin，已跟踪的条目走原生升级。旧缓存路径和旧
  `workstation` bundle 记录在 software/bootstrap/legacy-workstations.json，仅移除明确识别的
  旧缓存，不动其他软件。当前 profile 使用逐包 entry；`just profile list` 直接显示包名。
- 并存迁移优先级依据现有旧 bundle 计算，逐包安装成功后才删除旧缓存。迁移可能产生
  两代原生 profile；需要回到迁移前时使用 just profile history 查看记录，再 rollback 指定代。

日常命令不变，无需 sudo：

```sh
cd ~/Workspace/ember-nixos-config
just proxy status
just proxy on
just proxy off
just proxy import ~/Downloads/provider.yaml
just profile install
just profile list
just profile history
just profile rollback
```

代理导入/启停在底层需要 sudo。旧 Hearth generation 可以用兼容 helper 做原有操作，
但订阅源的新增支持需要实际更新到 Ember 的新系统服务后才能使用。
新软件缓存路径来自实际 Ember 逐包构建；部署时还需把 `just software-build`
输出的 closure 复制到目标，只复制 `bootstrap/packages` 文本不代表离线安装缓存已到位。

## 5. 最终验证和应用顺序

1. 针对性检查和最终 Ember toplevel 结果见 phase4-report.md；不要部署早期产物。
2. 检查当时 hostname、根盘与挂载。Folio 上只更新内置盘挂载目标，不能对 Folio switch。
3. 在 Folio 上挂载原内置盘，运行 just migrate-folio-data，由用户本地输入 sudo。
4. 处理目标源码目录/旧链接，复制新源码与软件缓存 closure。
5. 应用最终 system closure；系统、PAM、hostname、登录和桌面服务需要此步骤，不是
   只同步 Just 文件即可。具体 sudo 命令及 store path 必须取自最终结果，另行提供。
6. 保留上一代 Hearth 系统，正常卸载；由用户安排启动 Ember。不要自动重启。
7. 实机观察登录、外观、输入、Polkit、锁屏、音量/亮度、网络、订阅与 profile。

不需要重新分区或格式化，不删除原节点/Noctalia/keyring/profile。回退使用上一代系统，
旧源码链接与数据保留；若重启后需进一步排错，读取目标持久日志而非猜测驱动问题。
