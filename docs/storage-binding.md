# Hearth 内置 NVMe 存储设计与绑定

更新：2026-11-10。**INSTALLED / FIRST_BOOT_PENDING**。用户已明确确认整块内置盘清空、无数据保留，并授权编写整盘 NixOS 声明式布局。
设计验收之后，用户已授权并在本地 sudo 完成分区与安装，见 [installation-status.md](installation-status.md)。首次从内置盘启动仍待验证。

## 已确认的目标

- 内置盘：UMIS RPJYJ512MLR1QWY，512 GB 标称容量，系统显示约 476.9 GiB。
- 稳定路径：`/dev/disk/by-id/nvme-eui.5cdfb804515050ab`。
- 绑定前只读检查该路径解析到 `/dev/nvme0n1`，当时为空盘；当前已按本设计安装，实际挂载见 installation-status.md。
- 当前正在运行的 USB 系统在 `/dev/sda`；本配置不指向它。
- 整盘只安装 Hearth，不保留旧系统、旧 ESP 或数据分区。

`storage-spec.nix` 是唯一物理盘身份入口，layoutModule 指向 `storage.nix`，layoutConfirmed=true 表示已按本次用户授权选择布局，
不表示实盘已经分区或安装。绑定后导出 `nixosConfigurations.hearth`；原 system-preview 和 VM 仍只使用虚拟设备。

## 推荐布局

| 层级 | 大小 | 文件系统/用途 | 挂载点 |
| --- | --- | --- | --- |
| GPT 分区 1 / ESP | 2 GiB | FAT32，HEARTH_EFI，UEFI/systemd-boot | /boot |
| GPT 分区 2 / system | 剩余约 474.9 GiB | 单个 Btrfs，HEARTH_SYSTEM | 由下列子卷挂载 |
| @nix 子卷 | 与 @persist 共享全部空闲空间 | Nix store、数据库、构建目录、系统 generations | /nix |
| @persist 子卷 | 与 @nix 共享全部空闲空间 | 系统状态、用户数据、账户密码、Wi-Fi、Keyring、OMP、词库 | /persist |
| 内存中的根目录 | 最多 2 GiB，按实际使用分配 | tmpfs，每次启动重新创建 | / |
| zram | 保留现有 RAM 25% 的逻辑上限 | 压缩交换，不占固定磁盘分区 | 不适用 |

只有两个物理分区。子卷不是固定容量分区，没有为 /nix 和个人文件硬切比例；整个 Btrfs 空闲池可被两者使用，
实际可用容量还受文件系统元数据和已保存文件影响。tmpfs 上限不是开机预占 2 GiB 内存。

## 为什么这样选择

1. **ESP 2 GiB**：给保留的五代内核/initrd 与后续升级留余量，占整盘约 0.4%；不需要为节省少量空间承担启动文件空间紧张的问题。
2. **一个 Btrfs 容量池**：Nix store 和 Workspace/Downloads 的增长比例难以预估，共享空间可避免某个固定分区先满、另一个仍很空。
   @nix/@persist 保留清楚的管理边界，日后可分别考虑备份与快照；本轮不启用无消费者的自动快照任务或配额。
3. **保留 tmpfs 根与 preservation**：沿用已验证的账户和用户状态设计，避免引入 Btrfs 根回滚脚本和额外启动操作。
   /nix、/persist 都标记 neededForBoot，现有早期密码目录与 mount 顺序修复继续生效。
4. **低额外开销**：两个子卷采用相同 noatime、compress=zstd:1、nodiscard；保留现有每周 fstrim，且不在启动关键路径补跑。
   不同时启用持续 discard 与定时 TRIM。保留 CoW 和校验，不启用自动碎片整理或强行关闭数据校验。
5. **不设磁盘 swap**：保留现有 zram，当前没有休眠到磁盘需求，不分割一块长期闲置的大 swap。若以后需要 hibernation，要另行设计 swap 与 resume。
6. **稳定设备身份**：按 NVMe EUI 绑定，不依赖磁盘被枚举为 nvme0n1 还是其他编号；不硬写安装前尚不存在的文件系统 UUID。
7. **本轮采用未加密 Btrfs**：保持当前存储与启动约定，没有擅自选择磁盘解锁密码或 TPM 自动解锁方案；若需要全盘加密，应在真实格式化前另行确定。

依据：锁定 disko 修订的 lib/types/{gpt,btrfs,filesystem}.nix 与 NixOS fileSystems 配置；
[Btrfs 官方挂载选项](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html) 说明多数选项作用于整个文件系统，因此两个子卷保持一致；
[disko 子卷示例](https://github.com/nix-community/disko/blob/cedd626e11b635470fa6f9fdb8ad79b0075dd7f9/example/btrfs-subvolumes.nix) 展示声明方式。
容量选择是针对这台机器和现有架构的设计判断，不是性能基准结论。

## 必须理解的用户数据边界

/home 本身没有独立持久分区。用户目录由原 preservation 白名单保存：Workspace、Documents、Downloads、Pictures/Screenshots，
以及明确列出的 Zsh、Nvim undo、Nix profile、Noctalia、Keyring、Fcitx 和 ~/.omp 等状态。
**任意新建的 ~/某目录并不会自动持久化。** 新用途应加入 users/wallyhao/persistence.nix，不能把未列目录当成永久存储。
Nix 的构建临时目录已经设在 /nix/var/nix/builds，避免大型构建占满 tmpfs 根。

系统 generations 支持回退系统配置，但不是个人文件备份。@persist 可以日后单独做快照/外置备份；本轮没有声称已提供自动数据备份。
同池意味着一方也可能用满全池，应关注 Btrfs 可用空间；不通过硬配额预先猜两者容量。

## 代码入口和验证

- hosts/laptop/storage-spec.nix：物理盘身份与绑定。
- hosts/laptop/storage.nix：真实目标入口。
- hosts/laptop/storage-layout.nix：共享 GPT、ESP、Btrfs 子卷与 tmpfs 定义。
- tests/fixtures/storage.nix：相同定义改用虚拟 /dev/vda 与较小 512 MiB ESP，绝不读取或透传物理盘。
- checks.storage-layout：对真实目标的 disko 脚本执行 bash -n，仅解析、不执行。
- 原七个 VM 使用共享子卷布局做真实虚拟盘格式化、安装、启动、密码、持久化和桌面验收。

可安全构建真实目标，不进行激活：

```sh
nix build --no-link --no-update-lock-file \
  path:.#nixosConfigurations.hearth.config.system.build.toplevel
nix build --no-link --no-update-lock-file path:.#checks.x86_64-linux.storage-layout
```

设计验证记录在 storage-validation.md，实际安装状态见 installation-status.md。当前系统已安装，不应重复执行格式化程序。
