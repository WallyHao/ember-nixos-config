# 用户软件

在 Ember 上，由 `wallyhao` 在配置仓库运行：

```sh
just profile install
just profile list
just profile history
just profile rollback
# 回到指定历史代：
just profile rollback 3
```

`just profile install` 会构建并同步 `software/packages.nix` 声明的软件：

- 基础 CLI：gh、git、just、yazi、eza、bat、fd、ripgrep、fzf、zoxide、jq、btop、unzip；
- OMP；
- `user-packages.nix` 中选择的应用。

每个包都是独立的 profile entry；`nix profile list` 直接显示包名，不再使用
`base` 或 `workstation` 聚合 bundle。增加、删除或升级某个包只影响对应 entry。
没有变更时不创建新 generation。以上命令无需 sudo，不重建 NixOS，不修改
Home Manager，不更新 flake.lock。

## 添加应用

只编辑 `software/user-packages.nix` 的软件选择，例如：

```nix
{
  packages = [ "qq" ];
  allowedUnfree = [ "qq" ];
}
```

随后运行 `just profile install`。例子没有默认启用；本次没有安装 QQ。
`allowedUnfree` 只填写你明确允许的非自由软件名称，不开启全局 allowUnfree。

Ember 的 home 是按目录持久化的。QQ 的登录数据还需要在
`users/wallyhao/persistence.nix` 加入 `.config/QQ` 并应用一次系统配置；
安装包本身不会自动增加数据持久化规则。其他应用也应检查其数据目录。

## Profile 行为

实际 profile 位于：

```text
~/.local/state/nix/profiles/profile
```

同步规则：

- 只管理 `originalUrl` 指向本仓库 `software` flake 的 profile entry；
- 手动安装的其他 entry 原样保留；
- 从 `user-packages.nix` 删除应用后，下一次 `just profile install` 只移除对应 entry；
- 构建失败时不触碰 profile；
- 旧 `workstation` bundle 会在新包安装成功后被移除；
- 旧缓存路径记录在 `legacy-workstations.json`，只清理明确匹配的旧 entry。

`nix profile history` 和 `rollback` 仍按 generation 工作；单包粒度体现为独立
entry，可以单独 `nix profile remove` 或 `nix profile upgrade`。

## 构建与缓存

```sh
just software-build
```

该命令逐个构建 `software/packages.nix` 中的全部包并打印 store path。

- `software/bootstrap-packages` 记录首次安装需要复制的逐包 store closure；
- `software/bootstrap-fingerprint` 记录软件声明、lock 和构建定义的校验值；
- 声明与指纹一致时，已有 profile 可以跳过重新构建；
- 正常使用不要手工更新 fingerprint。只有重新准备安装缓存，并确认
  `bootstrap-packages` 与当前构建结果一致时才更新它。

本地 flake 的 origin 跟随当前仓库位置；请在 Ember 的持久仓库路径操作。
兼容旧 `hearth-nixos-config` origin；旧目录名必须保留指向新目录的链接，
原生 profile entry 才能继续解析原 origin。

Home Manager 只将 profile 的 bin/share 加入会话；它不安装 profile。OMP 数据
保存在持久化的 `~/.omp`。
