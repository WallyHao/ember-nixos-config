# 从当前 Folio 更新内置盘上的 Ember

适用当前检查到的环境：宿主 hostname 为 folio，内置 nvme0n1 未挂载，已有
HEARTH_EFI/HEARTH_SYSTEM 文件系统。以下不重新分区或格式化，也不对 Folio switch。
系统构建与核心桌面检查已通过；完整权限弹窗、锁屏/解锁和电源交互留待实机确认。
每段命令执行成功后再继续，任何一步报错先停止。不要自动重启。
仅当挂载成功时才能安装；安装命令包含挂载检查，防止目标未挂载时写入宿主的普通 /mnt 目录。
只有出现 `installation finished!` 且软件缓存复制成功后才能执行卸载段。

## 1. 挂载与私有资料复制

```sh
cd /home/folio/Workspace/NixOS-CN-telegram/ember-nixos-config
sudo /nix/store/5iv64vcjr9jdibsf715bf79x6bgwpnym-disko-mount/bin/disko-mount
findmnt /mnt/boot
findmnt /mnt/nix
findmnt /mnt/persist
just migrate-folio-data
```

确认三个挂载点的来源仍为内置盘。
资料工具再次检查标签，仅复制节点、订阅与已保存网络连接数据；sudo 密码只在本地输入。
若报告 `connections_needing_agent_secret` 大于0，部分 Wi-Fi 密码需进入系统后重新输入。
原代理 disabled 标记保留；需要主动启用时在 Ember 中 `just proxy on`。

## 2. 目标源码目录

先查看目标目录，下面改名段只用于“旧名称是真实目录、新名称不存在”的首次迁移：

```sh
ls -ld /mnt/persist/home/wallyhao/Workspace/*nixos-config
```

符合上述条件时，保留旧源码备份并建立旧名称兼容链接：

```sh
cp -a /mnt/persist/home/wallyhao/Workspace/hearth-nixos-config /mnt/persist/home/wallyhao/Workspace/hearth-nixos-config.before-ember
mv -T /mnt/persist/home/wallyhao/Workspace/hearth-nixos-config /mnt/persist/home/wallyhao/Workspace/ember-nixos-config
ln -s ember-nixos-config /mnt/persist/home/wallyhao/Workspace/hearth-nixos-config
```

若已经是新目录加旧链接，跳过上述三条。若两个名称都是实际目录，先比较与保留变更，
不要覆盖或删除其中任意一个。复制最新配置到确认好的 canonical 目录：

```sh
cp -a /home/folio/Workspace/NixOS-CN-telegram/ember-nixos-config/. /mnt/persist/home/wallyhao/Workspace/ember-nixos-config/
```

旧名称链接保证已有 profile 的旧 originalUrl 仍能找到更新后的软件定义。
这里更新配置源码，不删除目标的其他个人数据。

## 3. 安装已构建系统和软件缓存

最终系统路径来自实际成功构建，不是 system-preview；本地也已创建 `result-ember` GC root 指向它：

```sh
mountpoint -q /mnt && mountpoint -q /mnt/boot && mountpoint -q /mnt/nix && mountpoint -q /mnt/persist &&
  sudo nixos-install --root /mnt --system /nix/store/9s57sd9hqw505xghyvq6hdq8gf21j5bq-nixos-system-ember-26.11.20261107.dirty --no-root-passwd --no-channel-copy
mapfile -t software_paths < <(just software-build)
sudo nix copy --no-check-sigs --to 'local?root=/mnt' "${software_paths[@]}"
```

`--no-check-sigs` 仅用于复制本机已构建的软件集合，不修改全局信任设置。
完成后保留旧系统 generation，正常卸载：

```sh
cd ~
sudo umount -R /mnt
```

随后由你安排重启并从内置盘启动。系统 hostname 为 ember，登录标题为 EMBERLIGHT，
用户名仍为 wallyhao，已有密码不变。

## 4. 进入 Ember 后

```sh
cd ~/Workspace/ember-nixos-config
just profile install
just proxy status
```

需要代理时 `just proxy on`。profile 默认包含 Zen；从启动器搜索 Zen，或运行 `zen-beta`。
profile 安装后打开新的 Foot 窗口使用 OMP 等工具。
观察实际字体、输入法、Wi-Fi、订阅、亮度/音频、锁屏与唤醒；这些硬件及私人来源
无法由虚拟测试代替。需要回退时选择保留的上一代系统，不格式化或清理私有状态。
