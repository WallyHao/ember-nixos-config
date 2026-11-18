# 手机 ↔ 电脑传文件（常驻服务，浏览器接收端）

2026-11-18 · 状态：待批准（第 2 版：改为开机自启的常驻服务）

## 意图

手机和电脑之间传少量小文件（一次 3–4 个），两端都在同一个 Wi-Fi。

**形态**：电脑上有一个开机就运行的服务，手机浏览器打开固定地址就是它的界面，
可以直接浏览、上传、下载。不需要在电脑上敲任何命令，也不需要手机装任何 App。

为什么不做现成的：微信/QQ 体积大；LocalSend、KDE Connect、Tailscale、Termux+sshd
都要在手机上装东西。剩下的唯一形态就是“电脑跑服务，手机用浏览器”。

## 目标

- 开机即就绪（systemd 服务，`wantedBy = multi-user.target`，崩溃自动重启）。
- 手机端零安装：浏览器打开地址（可加书签），页面里点选/拖拽上传下载。
- 电脑端零操作：把文件丢进共享目录即可出现在手机页面上；手机上传的落在同一目录。
- 只改本仓库的 Nix 配置，走现有模块约定与 `just build` 流程。

## 非目标

- 不在同一网络时的传输（移动数据、外网）。
- 手机 App、专用客户端、账号体系、同步语义（这是手动搬运，不是 sync）。
- 断点续传、分块上传、GB 级大文件优化。
- HTTPS 证书、多用户、公网暴露。
- 开机前就要可用（服务依赖用户态文件系统挂载完成，实际是在挂载后立刻启动）。

## 反目标

- 需要用户在电脑上先手动启动一个进程才能传文件。
- 需要在手机上装 App 或敲命令。
- 密码、密钥出现在 `/nix/store`、仓库或 Nix 表达式求值里。
- 共享目录重启后丢失（`/` 是 tmpfs，只有 `preservation` 列出的目录留得住）。
- 为了 4 个小文件引入数据库、Web 前端构建、容器等额外运行时。

## 约束（来自当前仓库与实测）

- `networking.firewall.enable = true`、`allowedTCPPorts = [ ]`：必须声明端口。
- `services.openssh.enable = false`：不走 SSH/scp/rsync。
- `modules/network/default.nix` 用 `lib/module-dir.nix` 自动导入同目录 `*.nix`，
  新增一个文件即生效，不需要改 import 列表。
- `justfile` 约定命令不带参数。
- home 是 tmpfs + `preservation`；`Downloads` 已持久化，其余目录需显式登记。
- 主机激活需要用户明确指示；本设计只到 `just build` 与本地验证。

## 方案

### A. miniserve 常驻服务（选中）

`miniserve` 0.35.0，单二进制 Rust，自带网页文件列表 + 上传表单 + basic auth。

实测（本机，0.35.0，二进制缓存直接可下载）：

```
POST /upload?path=/  (field: file)  → 303，文件落到共享目录
GET  /t.txt                         → 200，内容一致
无凭据 → 401；带凭据 → 200
方式一 -a/--auth；推荐 --auth-file（凭据不进 argv、不进 store）
```

- 网页界面自带 `input[type=file]` + Upload 按钮，手机上就是标准文件选择器。
- 启动时会把绑定的地址写进日志（`journalctl -u file-drop -b | grep http://`），
  手机按那个地址打开一次再加书签。`-q/--qrcode` 只在该页面内生成二维码，
  对首次配对没有帮助，因此不启用。
- 代价：常开一个端口；`/nix/store` 里的二进制本身不可信，需要 basic auth 兜底。

### B. dufs（原方案，已排除）

dufs 0.47.0 在你 pin 的 nixpkgs 里**不在二进制缓存**，本地构建在
`aws-lc-sys` 处失败：

```
error: Cannot build '/nix/store/4fgzrqacan6kgvq7m2mbds538lywnacm-dufs-0.47.0.drv'
AWS_LC_SYS_USE_SYSTEM=1 requires a system-installed AWS-LC, but none was found.
```

为一个文件服务引入 Rust 工具链或 overlay 换 nixpkgs 版本，代价明显大于收益。

### C. filebrowser

也在缓存里，功能更多（用户库、配额、分享链接、WebDAV），但需要数据库文件和
登录体系，属于为 3–4 个小文件买一整套应用。不选。

**选 A**：缓存可用、依赖最少、自带上传与认证、单进程无状态。

## 手机上传是怎么走的（实测 0.35.0）

页面顶部就是上传区，不需要进二级菜单：

```
http://<本机IP>:7373/            ← 书签
┌────────────────────────────────────┐
│ Ember 文件互传        [ 选择文件 ]   │  ← 可多选
│ 上传到: /                          │
├────────────────────────────────────┤
│ report.pdf                         │  ← 点一下下载到手机
│ notes.md                           │
└────────────────────────────────────┘
```

- `input[type=file][multiple]`：点“选择文件”弹系统文件选择器，3–4 个可以一次选中。
- 每个文件单独 `POST /upload?path=/`（multipart，字段 `file_to_upload`），落盘到
  `~/Downloads/Share`；实测返回 303，文件当即出现在目录里。
- **同名不覆盖**：实测第二次同名上传返回 `409`，原文件保持不变。
  miniserve 页面没有删除按钮，所以撞名时只能在电脑上 `rm`/改名后再传。
- 电脑 → 手机：文件放进 `~/Downloads/Share`，手机页面上点名字即下载到手机下载目录。

## 具体怎么做（已定）

1. **新增 `modules/network/file-drop.nix`**（自动导入，`network/` 拥有防火墙，服务与端口同处一个模块）：

   - `systemd.services.file-drop`：`wantedBy = [ "multi-user.target" ]`、
     `Restart = "always"`、`User = "wallyhao"`。
   - `ExecStartPre` 建目录，`ExecStart` 为
     `miniserve <dir> -p 7373 -u -P --auth-file <auth> -t "Ember 文件互传"`。
     `-P/--no-symlinks` 防止请求跟随软链跑出目录。
   - `networking.firewall.allowedTCPPorts = [ 7373 ]`，其它端口保持关闭。
   - 基础加固：`ProtectSystem = "strict"`、`ReadWritePaths = [ <dir> ]`、
     `PrivateTmp`、`NoNewPrivileges`、`RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ]`。

2. **共享目录**：`~/Downloads/Share`。`Downloads` 已在 preservation 里，
   不新增持久化项。

3. **凭据**：`~/.local/state/file-drop/auth`，内容一行 `wallyhao:<密码>`，`0600`。
   - 由服务首次启动时自动生成（`ExecStartPre`），无需手工创建；文件被清空或删除后会重新生成。
   - 通过 `--auth-file` 读取，不进 Nix store、不进命令行参数。
   - 该目录需在 `users/wallyhao/persistence.nix` 登记，否则重启后密码丢失、
     服务起不来。这是本次唯一新增的持久化项。
   - 手机浏览器第一次输入后由浏览器记住，之后打开书签直接进。

4. **文档**：`docs/operations.md` 加一节：地址、目录、怎么改密码、看二维码的命令。

### 我做的判断（可以推翻）

- **端口 7373**：避开 8080/8000/5000/3000/5173 这些测试与开发默认端口；
  7373 未在 `/etc/services` 注册，也没有被当前任何进程占用。改端口只是模块里的一个常量。
- **要求密码**：常驻 + 可写，无认证等于把局域网内任意设备变成可写共享；代价只是每台设备第一次输入一次。
- **地址稳定性交给你**：DHCP 会换 IP，建议在路由器上给这台机器做一次地址保留，
  然后书签 `http://<固定IP>:7373`。不引入 avahi（Android 浏览器对 `.local` 解析不可靠）。

## 留给实现者的

- miniserve 参数以 `miniserve --help` 为准（0.35.0 已核对：`-p`、`-u`、`-P`、`--auth-file`、`-t`、`-q`）。
- `ExecStartPre` 用 `pkgs.coreutils` 而非裸 `mkdir`。
- 服务名 `file-drop`、单元描述、日志级别等细节。

## 验证

- `just build` 通过（nixfmt/deadnix/actionlint/CLI 测试 + flake 求值）。
- 用同一组参数在本机临时目录跑一遍：上传、下载、401/200 行为（已预演，参数一致）。
- 服务本体、开机自启与防火墙放行只能在 `nixos-rebuild switch` 之后成立；
  这需要你的明确指示，我不动主机。手机实机验证同样在那之后由你完成。
