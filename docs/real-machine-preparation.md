> 历史准备记录：当前实现以 [第四阶段迁移说明](phase4-migration.md) 为准。
> 本文原先“只接受 proxies、无订阅支持”的限制已由第四阶段运行时数据适配取代；
> 不代表真实 Folio 节点/订阅已复制到内置盘。

# 实机准备：输入法、网络、自动代理与 OMP

本轮是在原两阶段基础上的用户授权扩展；不代表旧第二阶段所有待验项目已经完成。
所有使用命令均面向将来安装完成的 Ember，不在当前移动硬盘宿主激活。
内置盘现已绑定，声明式布局见 [storage-binding.md](storage-binding.md)；真实分区和安装尚未执行。

## 输入法

- Fcitx5 + Rime + 锁定 nixpkgs 的雾凇拼音；默认美式键盘，`Ctrl+Space` 切换中文输入。
- Fcitx5 随图形会话启动、退出；Foot/GTK 使用 Wayland 输入协议，Qt 使用 Fcitx 模块。
- 系统提供初始分组和快捷键；HM 管理 `~/.local/share/fcitx5/rime/default.custom.yaml`，只启用 `rime_ice`。
- `~/.config/fcitx5` 和 `~/.local/share/fcitx5` 持久保存，包括学习词库。不要清空这些目录来“修复”部署。
- 首次进入桌面会编译词库；稍等后在 Foot 输入 `nihao`、空格，应得到“你好”。
- 首次词库编译有明显的临时内存峰值；图形功能测试因此分配了 2 GiB VM 内存。这不代表实机常驻占用已测量。
- 排障：`systemctl --user status hearth-fcitx5`、`journalctl --user -u hearth-fcitx5`、`fcitx5-remote`。

## 网络连接

沿用 NetworkManager + systemd-resolved，提供 `nmcli` 和 `nmtui`。没有内置 Wi-Fi 密码。

进入 Ember 后运行 `nmtui`，选择“Activate a connection”，连接 Wi-Fi。
也可使用交互密码提示，避免将密码写进命令历史：

```sh
nmcli device status
nmcli device wifi list
nmcli --ask device wifi connect '你的 SSID'
nmcli connection show --active
resolvectl status
```

连接配置保存在持久化的 `/etc/NetworkManager/system-connections`，目录权限 0700。
正常保存的连接可由 NetworkManager 自动重连；实际无线网卡驱动、认证、休眠后重连仍须本机验收。
系统不等待网络在线才进入登录界面。

## 自动代理

单一后端 Mihomo，系统服务名 `hearth-proxy.service`。配置在 `/etc/hearth/mihomo.yaml` 可查看，
其中没有节点或订阅凭据；节点来自 `/var/lib/hearth-proxy/providers.yaml`，root 私有、持久化。
**没有节点文件时服务跳过启动，维持正常直连。**

实现的策略：

- TUN 自动路由与 DNS 劫持；应用通常不必设置代理环境变量。
- 局域网、本地域名和国内域名/IP 直连，其余交给 `AUTO`。
- `NODES` 在节点间测速选择；`AUTO` 优先节点组，健康检查发现节点不可用后尝试 `DIRECT`。
  健康检查周期 60 秒，切换不是即时或无损保证，也不能让本来无法直连的站点变得可达。
- GeoIP/GeoSite 使用锁定 nixpkgs 的离线数据，不在启动时下载数据库。
- 本地 HTTP/SOCKS 混合端口 `127.0.0.1:7890`，不向局域网开放；控制接口是 root 私有 Unix socket。
- 系统 DNS 底座继续由 resolved 管理；停用代理不改写 `/etc/resolv.conf`。
- 不自动下载未知订阅、不安装第三方脚本、不修改浏览器设置。

先从服务商获取一个本地 YAML 文件。可以是含 `proxies:` 的完整 Clash/Mihomo 配置，
导入时只提取节点列表，不采用其中的规则、DNS、监听器或脚本。只有 `proxy-providers:`、
Base64 链接列表或订阅地址的文件不能直接导入，需要先获得节点 YAML；不要把私密文件放入仓库。

以下只在进入 Ember 后执行：

```sh
just proxy import "$HOME/Downloads/provider.yaml"
just proxy status
just proxy check
just proxy off
just proxy on
```

导入、启停通过 sudo 验证身份。导入会验证结构和完整 Mihomo 配置，失败保留旧节点。
`off` 会停止 TUN 并持久记住关闭状态，重启后也保持关闭；`on` 或成功导入重新开启。
更新节点时重新导入即可，不需要重建系统；导入后建议删除 Downloads 中的凭据副本。
需要与其他 VPN 共存时先 `just proxy off`，本轮没有实现两套 TUN 路由策略的自动协调。

排障：

```sh
sudo journalctl -u hearth-proxy -b
ip rule
ip route
resolvectl status
```

## oh-my-pi

OMP 指 [can1357/oh-my-pi](https://github.com/can1357/oh-my-pi)，不是提示符主题。
现有 Zsh + Powerlevel10k 保留。使用固定版本 18.18.6 的官方 Linux x64 独立发行文件，
SHA-256 固定在 `software/omp.nix`；Nix 修补 ELF 依赖后封装为 `omp`，不会运行 curl 安装脚本。

OMP 在独立软件 profile 中提供，不由 HM 激活脚本偷偷安装。
如果已安装基础 `base`，只添加 OMP：

```sh
nix profile install --no-update-lock-file \
  --profile "$HOME/.local/state/nix/profiles/profile" \
  'path:./software#omp'
omp --version
omp
```

全新 profile 可一次安装基础工具加 OMP 的 `path:./software#workstation`。
本次安装已缓存该集合；首次离线安装优先用 `just profile install`，旧 generation 没有 just 时用 `./scripts/ember profile-install`，见 [首次安装入口](profile-bootstrap.md)。
在 `ember-nixos-config` 项目根目录运行安装命令；仓库不在当前目录时替换成对应绝对路径。
软件升级只更新软件 profile，输入法和代理系统模块的变更仍随系统构建部署。

`~/.omp` 以 0700 权限持久化，包含可写的设置、认证、会话和扩展；HM 不覆盖这些运行时文件。
首次运行后由你选择模型并登录；没有预填 provider、API key、模型或计费账户。
无凭据的 CLI 启动检查不等于模型调用成功。

## 实机首次验收

1. 用 `nmtui` 连接网络，确认 DNS、断线重连和重启后已保存连接可用。
2. Foot 中用 `Ctrl+Space` 输入“你好”，检查候选框、标点和再次切回英文。
3. 导入自己的代理节点，检查国内直连、需要代理的目标、DNS、开关与重启行为。
4. 安装 OMP profile，启动 `omp`，完成认证并在临时项目中执行一次真实模型请求。
5. 再检查休眠/唤醒、外接屏、实际功耗和内存；VM 结果不能替代这些实机结果。
