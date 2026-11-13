# 软件安装与代理的简短命令

在 Ember 的持久配置仓库中，以 wallyhao 身份执行，不要给 just 加 sudo：

```sh
cd ~/Workspace/ember-nixos-config
just profile install
```

一次安装基础工具、OMP 与 `software/user-packages.nix` 声明的应用。
后续增删应用也只修改该文件并重新运行这一条命令，无需输入 profile 路径。
非自由软件在同一个文件的 allowedUnfree 列表明确允许；应用数据持久化仍按
users/wallyhao/persistence.nix 管理，参见 [软件说明](../software/README.md)。

```sh
just profile list
just profile history
just profile rollback
just profile rollback 3
just profile help
```

旧命令 `just profile-install`、`./scripts/ember profile-install` 兼容保留。
当前 shell 尚未读入 profile PATH 时，安装后打开新终端；无需重新安装软件。

## 代理

```sh
just proxy status
just proxy on
just proxy off
just proxy check
just proxy import ~/Downloads/provider.yaml
just proxy import '/path/with spaces/provider.yaml'
just proxy help
```

代理入口复用系统 hearth-proxy，仍是同一个 Mihomo TUN 服务与持久节点文件；
需要权限的导入、启停会由底层命令请求 sudo。不会导入凭据到仓库，也不会替换路由规则。
订阅/节点格式与代理行为见 [实机准备](real-machine-preparation.md)。

## 本轮验证与边界

- Just 实际参数转发（包括带空格路径）、ShellCheck、Bash/Nix 格式通过。
- 临时目录及模拟 Nix/代理后端检查：错误参数拒绝、安装失败保留旧条目、成功后清理
  旧缓存、其他软件条目保留、重复执行不新增安装、清单恢复原样仍正确升级、
  构建失败不回退旧缓存、初始声明离线缓存路径均通过。
- software#workstation 实际构建仍得到已复制的 bootstrap-workstation store path。
- 未在 Folio 执行真实 profile 安装或改动代理服务；未运行 VM。VM fixture 已补齐
  新缓存入口需要的软件源文件，但没有声称 VM 复验通过。
- 这是仓库命令更新，源码同步到 Ember 后即可使用，不需要为命令入口重建系统。
