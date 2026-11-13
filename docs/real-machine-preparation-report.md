# 实机准备扩展：实现与验证

历史记录：本报告的产物和 STORAGE_UNBOUND 边界属于存储绑定前。后续整盘布局、绑定和复验见 [storage-validation.md](storage-validation.md)。

日期：2026-11-10。**本轮要求的代码、构建与隔离 VM 验证已完成；实机安装、私有凭据配置和物理网络验收待用户进入系统后执行。**
原第二阶段其他待验项仍为 INCOMPLETE，不因本轮完成改写为全阶段完成。磁盘继续 STORAGE_UNBOUND。

## 实现

- 输入法：Fcitx5 + Rime + 雾凇拼音，Ctrl+Space 切换；Niri 就绪后启动唯一用户服务，禁用重复 XDG autostart；学习词库和配置持久化。
- 网络：复用 NetworkManager/resolved，提供 nmcli/nmtui，系统连接持久化，不写死 SSID、密码或接口名。
- 自动代理：Mihomo TUN、国内/LAN 直连、其他自动选节点，健康检查和 DIRECT 回退；本地混合端口仅 127.0.0.1:7890；DNS fake-IP 与 TUN DNS 劫持。
- 节点管理：hearth-proxy import/on/off/status/check。运行时私有 provider，不进入求值或 Nix store；无节点文件跳过启动；无效导入保留上次配置；关闭状态跨重启保存。
- Geo 数据：锁定 nixpkgs 提供 GeoIP/GeoSite，禁止运行时自动更新，无需启动时下载数据库。
- oh-my-pi：固定官方 18.18.6 Linux x64 发行文件及 SHA256，经 Nix 修补和封装；独立 #omp 与 #workstation（base + omp）profile；~/.omp 私有持久化，不改 P10k。
- 自动化入口：新增 vm-connectivity，纳入 just vm；CI 配置补齐新增的三项 VM。未触发远端 CI，不宣称远端运行通过。

具体操作见 [实机准备使用说明](real-machine-preparation.md)；选项来源见 [phase1-decisions.md](phase1-decisions.md)。

## 实际运行结果

| 检查 | 结果 |
| --- | --- |
| nix-shell ./shell.nix --run 'just fmt && just check' | exit 0；格式、ShellCheck、路径/凭据扫描及扫描负向自测、flake check --no-build 通过 |
| 完整 system-preview | 构建成功，未激活宿主 |
| desktop-config / eval-contracts / eval-user-environment | 构建通过 |
| software#omp | 构建通过；installCheck 真正运行 --version 和 --help |
| vm-user-environment | PASS，62.69 s；wallyhao 原生安装 workstation、运行 OMP、回滚、GC、重启及非秘密 OMP 设置读回 |
| vm-connectivity | PASS，112.17 s；仅来宾内 netns/veth/HTTP/SOCKS，下面列出真实流量断言 |
| vm-desktop | PASS，183.36 s；真实密码登录、Foot、通知/剪贴板/会话、中文输入与重启后重新登录 |
| vm-accounts | PASS，99.62 s；旧 PAM/改密/重启回归 |
| vm-persistence | PASS，49.07 s |
| vm-offline-boot | PASS，37.06 s，无 NIC |
| vm-offline-link | PASS，45.20 s，链路无 DHCP |

以上时间是完整功能测试耗时，含虚拟安装、OCR、编译和重启，**不是实机启动耗时**。

图形证据：打开 Foot，启动 command cat，Ctrl+Space 激活 Rime，输入 nihao 并选择“你好”，
真实 UTF-8 文件 /tmp/hearth-chinese-input 中断言包含“你好”；同时断言只有一个 Fcitx 进程。
[候选框截图](/nix/store/j4ay5bk65nmd9vcx259m54lpylidwpbb-vm-test-run-disko-hearth-vm-desktop/rime-chinese-input.png) 在合成器完成下一帧前抓取，展示了真实候选框；提交成功由文件内容断言证明。
原剪贴板历史在真实重启、重新认证后仍可选择并读取。

代理测试没有把“配置可解析”当成成功：

1. 无 provider 时服务不启动、没有 TUN、不阻塞离线登录。
2. 导入仅在 VM /run 生成的模拟节点，权限为 0600，目录为 0700；实际引擎完整解析。
3. 混合代理访问 HTTP，服务器观察到来自 SOCKS 出站的地址；监听不绑定通配地址。
4. 无应用代理参数的 HTTP 流量经过 TUN，再经 SOCKS 出站到测试地址。
5. 本地 DNS 监听返回 fake-IP；向没有 DNS 服务的外部测试地址发出的 UDP/53 被 TUN 接管并返回 fake-IP。
6. 停止模拟节点后回退直连，恢复模拟节点后自动恢复代理，服务器端地址证明路径变化。
7. 无效 provider 导入失败，旧文件哈希和运行服务保留。
8. off 移除 TUN 并恢复直连；重启后 provider 和关闭标记都保留，服务保持关闭。
9. 通过 nmcli 保存一条不自动激活的测试连接，重启后能读回，验证 NM 连接持久化。

## 最终产物

| 检查 | store path |
| --- | --- |
| desktop-config | `/nix/store/6ancqzvmwmnj0ks4sjp2vcxdvliqcc1y-hearth-desktop-config` |
| eval-contracts | `/nix/store/7saw3jq7f8rbdd7bz3blj1mixcfrbkky-hearth-eval-contracts` |
| eval-user-environment | `/nix/store/fmxccq8dbh3s8ijbzvm5xz8m8d3xqjhr-hearth-eval-user-environment` |
| system-preview | `/nix/store/95p4njdymm9adrskvrkg0gpvz95rad4k-nixos-system-hearth-26.11.20261107.dirty` |
| vm-accounts | `/nix/store/vhfdn2c4yfxgaawg3k3dp170cvay169w-vm-test-run-disko-hearth-vm-accounts` |
| vm-connectivity | `/nix/store/wxwnrr5g0cbk87fqz05wxk33sw0nvmnv-vm-test-run-disko-hearth-vm-connectivity` |
| vm-desktop | `/nix/store/j4ay5bk65nmd9vcx259m54lpylidwpbb-vm-test-run-disko-hearth-vm-desktop` |
| vm-offline-boot | `/nix/store/ar31jfl91qv9a7n857vxb1ciwkbysis8-vm-test-run-disko-hearth-vm-offline-boot` |
| vm-offline-link | `/nix/store/2aszqbf2hg9ds0apsp4fp000r8pqc3wn-vm-test-run-disko-hearth-vm-offline-link` |
| vm-persistence | `/nix/store/4z92jy2zqwyrvmr6zsc37cmywybf69iv-vm-test-run-disko-hearth-vm-persistence` |
| vm-user-environment | `/nix/store/38zanvxbzq3bv3svr4jh6msyxbfqs2c7-vm-test-run-disko-hearth-vm-user-environment` |

- OMP：`/nix/store/6z9y6p3zxpnlm21dk2mpc3pawkyclrvq-oh-my-pi-18.18.6`
- workstation：`/nix/store/bxrbpbcyk2p0l9vf1sfawydnvvy2pmfz-hearth-workstation`

最终输出与当前 flake 求值结果逐项对应，所有输出存在；最终各命令 exit 0。
日志在本次工作环境的 /tmp，跨机器不保证保留；store 产物在被 GC 前可查询：

- `/tmp/hearth-preflight-check-final.log`
- `/tmp/hearth-preflight-regressions.log`
- `/tmp/hearth-preflight-desktop5.log`
- `/tmp/hearth-preflight-connectivity5.log`
- `/tmp/hearth-preflight-user3.log`
- `/tmp/hearth-preflight-omp2.log`
- `/tmp/hearth-preflight-artifacts.json`

复验在项目根目录执行：

```sh
nix-shell ./shell.nix --run 'just check'
nix build --no-link --no-update-lock-file path:./software#omp
nix build --no-link --no-update-lock-file path:.#packages.x86_64-linux.system-preview
nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.desktop-config
nix-shell ./shell.nix --run 'just vm'
```

## 排障记录与验证边界

- 官方 musl 文件并非无依赖静态 ELF，不能直接放进 NixOS PATH；最终改用固定 glibc 文件并 autoPatchelf，已在构建和 VM 中实际运行。
- Fcitx 包自带 autostart，最初与用户服务抢 D-Bus 名称；现已禁止重复入口，并等待 notify-ready 的 niri.service 后启动，实际单实例断言通过。
- 原 1 GiB 图形 VM 在首次词库编译时发生 OOM/panic；仅将图形 VM 容量改为 2 GiB，其他 VM 保持 1 GiB。没有通过关闭 OOM 检测或忽略错误使测试通过；未测量实机常驻内存。
- 修正测试夹具的 systemd-run 绝对路径、临时 unit 停止后被回收、OMP help 大小写、greeter OCR 的 Passuord 识别和 root 无法访问用户 FUSE 子目录的问题。
- 中文输入测试用 command cat 绕过用户 cat=bat 别名，实际提交文件而非只断言输入法 active。Noctalia IPC 等待加入命令超时，避免无限挂起。
- 图形 VM 继续使用已有的仅测试软件渲染补丁；生产 Niri 未增加补丁，不证明实机 GPU、缩放或候选框定位已经验收。
- 公网 DNS、真实订阅节点/协议、Wi-Fi 驱动/密码认证/休眠重连、VPN 共存仍待实机；本轮没有节点/订阅，未替用户生成或搬运凭据。
- OMP 没有账户/API key，验证 CLI 和状态/profile 持久化，未执行真实付费模型请求。软件 profile 必须由目标用户按使用说明安装，HM 不代装。
- 自动回退依赖健康探测；60 秒周期不是零中断保证，直连本身也必须可用。无订阅自动下载器，不支持把 Base64 节点链接列表直接当 YAML 导入。
- 原 Noctalia 插件源联网尝试、完整 portal/Polkit 和改密后 keyring 验收等旧阶段剩余项不在本轮被冒充完成。

两份 flake.lock、初始密码/PAM 模块与补丁、storage-spec 与排障前归档逐字节比较未变。
未激活/安装宿主，未操作真实块设备、EFI、账户或 Wi-Fi 凭据，未重启宿主，未给 VM 传真实磁盘/GPU/输入设备；
未导出真实 nixosConfigurations.hearth。storage-spec 继续 null/null/false。
