# 第一阶段密码阻塞：已解决

状态：**RESOLVED，2026-11-09**。`vm-accounts` 已实际执行通过，完整测试耗时 107.74 秒。本文替代之前的求助说明；原文中“当前补丁下旧密码仍能登录”和“userborn 重启会写回旧密码”的判断不再成立。

## 问题需要分开看

### 最初的密码丢失是真故障

锁定的 userborn 将 `/etc/shadow` 链接到 `/var/lib/nixos/shadow`。原版 Linux-PAM 的 `unix_update_shadow` 在 `/etc` 创建临时文件，再 `rename` 覆盖 `/etc/shadow`，因此替换了链接，改密只留在 tmpfs 中。重启后旧的持久文件重新生效。

执行 Agent 已加入 `patches/pam-unix-password-symlink.patch`。补丁先解析链接，在真实目标目录创建临时文件，再原子替换真实目标；保留原有权限、属主和文件 fsync 流程。`accounts.nix` 通过 `system.replaceDependencies.replacements` 把补丁版 PAM 放入最终系统闭包。**该补丁继续保留，本次没有更换账户后端或放宽密码要求。**

### 补丁后的“旧密码又成功”是测试误判

本次先在原失败版本增加的哈希检查下重现问题：重启并再次启动 userborn 后，NSS 和持久文件里仍然是同一个新哈希，且只有一条 wallyhao 记录。

旧 Expect 脚本输入密码后立即发送 `echo READY_81`，随后把 `READY_81` 当成认证成功。终端回显可以直接产生这个字符串，**不需要认证成功，也不需要执行 Shell 命令**。本次用完全没有认证功能、只回显输入并输出 `Login incorrect` 的假程序做对照，旧探针仍报“密码被接受”，新探针正确判定拒绝。此前引用的 session-open 日志未与该次旧密码尝试准确对应，不能推翻这个对照。

另一个时序问题是 `passwd` 输出成功后，测试过早发送下一条命令，可能被终端模式恢复过程丢弃。现在等待 Shell 提示符恢复后再继续。

## 本次修改

| 文件 | 修改及原因 |
| --- | --- |
| `tests/vm/login.exp` | 统一登录探针。拒绝必须匹配明确的 `Login incorrect`；成功必须先看到 Shell 提示符，再实际执行身份查询，输出 `HEARTH_LOGIN:wallyhao`。完整标记不在输入命令中，回显不能冒充执行结果。每个阶段均处理 timeout / EOF。 |
| `tests/vm/accounts.nix` | 初始、新、旧及任意错误密码共用同一探针。加入缺少提示符、意外 EOF、仅回显命令、正确密码却期望拒绝、错误密码却期望成功等对照，并断言具体失败原因，避免脚本语法错误也被当成对照成功。改密按真实提示推进，等待 passwd 退出后的 Shell 提示符。 |
| `tests/vm/accounts.nix` | 改密后、每次 userborn 重启后、两次系统重启后检查真实持久文件：链接目标正确、新哈希非空且不同于初始哈希、记录恰好一条、NSS 与持久值相同、root 锁定、shadow 属主为 root 且组和其他用户无权限。 |
| `modules/nixos/persistence.nix` | 为两个 initrd 账户目录补齐主系统的早期挂载 unit，并给底层 `persist.mount` 增加 drop-in，关闭会引入依赖环的默认排序，保留 umount 冲突和关机顺序。底层磁盘、文件系统类型与参数仍由将来的 storage module 决定。 |
| `tests/vm/common.nix` | 检查完整串口日志及持久 journal，并在最终关机后再次检查串口日志；不再只检查当前 boot。错误报告只输出环的相关行。 |

## 关机依赖环的额外修复

原整改只把 userborn 的全局 preservation 依赖改成 `RequiresMountsFor`，仍然不足。initrd 的挂载在 switch-root 后被主系统生成带默认依赖的 unit，形成：

```text
userborn → tmpfiles-setup-dev → local-fs-pre → 账户挂载 / persist → userborn
```

原公共检查只读 `journalctl -b`，漏掉前一轮关机和最终关机。新检查实际拦截到了这个问题；只修账户挂载后又拦截到底层 persist 的同类环。因此同时修正这三个挂载的早期语义。最终账户 VM 的启动、两次重启、最终关机均通过新检查。

这里使用的是**目录** bind mount，目录里的 shadow 仍可原子替换；没有 bind-mount 单个 shadow 文件，没有开关机复制密码文件。

## 已通过的账户场景

1. 全新虚拟盘首次启动，wallyhao 的初始四字符密码可在真实 login PTY 登录，sudo 需要密码，root 锁定。
2. wallyhao 正常运行 `passwd` 改成测试新密码；新密码立即有效，旧密码和任意错误密码明确被拒绝。
3. 在不重启系统时重启 userborn：哈希、链接、权限不变，新密码有效、旧密码无效。
4. 第一次系统重启，再重启 userborn：重复检查及新旧密码验证通过，sudo 接受新密码。
5. 第二次系统重启：再次验证新旧密码；再次重启 userborn 后重复验证通过。
6. 最终正常关机，并检查完整串口日志，无 systemd ordering cycle / deleted-job 记录。

产物和其他回归结果见 [phase1-report.md](phase1-report.md)。此次关闭的是密码阻塞及关联的挂载顺序问题，第一阶段整体验收状态见 [phase1-status.md](phase1-status.md)。

## 复验命令

在 `hearth-nixos-config/` 中执行：

```sh
nix-shell ./shell.nix --run 'just check'
nix build --no-link --no-update-lock-file -L \
  path:.#checks.x86_64-linux.vm-accounts \
  path:.#checks.x86_64-linux.vm-persistence \
  path:.#checks.x86_64-linux.vm-offline-boot \
  path:.#checks.x86_64-linux.vm-offline-link \
  path:.#packages.x86_64-linux.system-preview \
  path:.#checks.x86_64-linux.eval-contracts
```

升级 nixpkgs / PAM / userborn / preservation 时必须保留这些行为验收。只有替代实现同样通过时才移除本地 PAM 补丁；锁定上游本身没有被本次修改。

未激活宿主、未修改宿主账户、未绑定/格式化真实磁盘、未写宿主 EFI、未重启宿主。所有账户操作、安装和重启只发生在隔离 VM 的虚拟盘中。
