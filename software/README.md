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

`just profile install` 安装或更新整个声明的软件集合：基础 CLI、OMP 和
`user-packages.nix` 中选择的应用。没有变更时不重复安装；从清单删除应用后再次运行，
新的集合也会移除它（单独通过其他 profile 条目安装的同名软件仍独立保留）。
以上命令无需 sudo，不重建 NixOS，不修改 Home Manager，不更新 flake.lock。
旧入口 `just profile-install` / `./scripts/ember profile-install` 仍有效。

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

## 集合与缓存

- `base` 是基础 CLI：gh、git、just、yazi、eza、bat、fd、ripgrep、fzf、zoxide、jq、btop、unzip。
- `omp` 是 oh-my-pi；`workstation` 聚合 base、omp 及 user-packages.nix。
- `bootstrap-workstation` 记录首次安装时已复制的 store closure；
  `bootstrap-fingerprint` 记录与之对应的软件声明、软件 lock 和构建定义的校验值。
  声明与校验值完全一致时，首次安装可以离线使用该缓存。
- 声明变化后先构建新集合，再以原生 Nix profile 安装/升级；构建或新安装失败时
  不删除旧缓存条目。迁移成功后清理原缓存条目，不动其他手动安装条目。
- 本地 flake 的 origin 跟随当前仓库位置；请在 Ember 的持久仓库路径操作。
  兼容旧 `hearth-nixos-config` origin；旧目录名必须保留指向新目录的链接，原生升级才能继续读取原 origin。
- 正常使用不要手工更新 bootstrap-fingerprint。只有重新准备安装缓存，并确认
  bootstrap-workstation 与实际构建结果一致时才更新它。

实际 profile 位于 `~/.local/state/nix/profiles/profile`。继续使用原生 Nix
profile generation/history/rollback，不手写 generation 链接或额外 GC roots。
Home Manager 只将其 bin/share 加入会话，OMP 数据保存在持久化的 `~/.omp`。

Ember 更名兼容：旧 bundle 的精确 store path 记录在 legacy-workstations.json；仅清理匹配的旧缓存条目，不动其他手动安装软件。
