# 第一阶段排障与复验报告

更新日期：2026-11-09。**第一阶段状态：`CODE_AND_VM_COMPLETE / STORAGE_UNBOUND`。**
密码阻塞 A05 已解决，R1–R5 整改和关联的关机挂载依赖环均已复核通过；
真实磁盘仍未绑定，不能据此安装或声明实机效果。

## 原因与改动

- 最初的改密丢失来自原版 PAM 原子替换 `/etc/shadow` 链接；执行 Agent 已加入的本地 PAM 补丁有效，本次保留并通过完整账户 VM 验证。
- 补丁后的“旧密码又生效”来自 Expect 将终端回显误认成认证成功。新增统一登录探针，认证后执行身份查询；拒绝要求明确错误提示，超时和意外 EOF 都失败。负向对照检查具体错误原因。
- `passwd` 成功消息不等于交互终端已经恢复；现在等 Shell 提示符后再发探针命令。
- 两个账户目录及底层 `/persist` 在主系统也必须保持早期挂载顺序。补齐 mount units / drop-in，并把关机日志纳入公共 VM 检查。

详细分析、文件清单及复验命令见 [phase1-blocker-password.md](phase1-blocker-password.md)。

## 本次实际执行

账户、持久化、无网卡、链路存在但无 DHCP 四个 VM 都因测试或系统定义更新而重新执行；不是沿用最初交付的 VM 结果。最终 `nix build` 与 `just check` 均为 **exit 0**。

```sh
nix-shell ./shell.nix --run 'just check'
nix build --no-link --print-out-paths --no-update-lock-file -L \
  path:.#checks.x86_64-linux.vm-accounts \
  path:.#checks.x86_64-linux.vm-persistence \
  path:.#checks.x86_64-linux.vm-offline-boot \
  path:.#checks.x86_64-linux.vm-offline-link \
  path:.#packages.x86_64-linux.system-preview \
  path:.#checks.x86_64-linux.eval-contracts
```

| 输出 | Store path |
| --- | --- |
| `eval-contracts` | `/nix/store/7saw3jq7f8rbdd7bz3blj1mixcfrbkky-hearth-eval-contracts` |
| `system-preview` | `/nix/store/cfrbxbhc1wrbmsnw55l2zqwq3fmq4fbh-nixos-system-hearth-26.11.20261107.dirty` |
| `vm-accounts` | `/nix/store/vwlls0q9x0z842n8wl26riaaj78pha3p-vm-test-run-disko-hearth-vm-accounts` |
| `vm-offline-boot` | `/nix/store/kqbqnlc2lb5xr23mk6bf7pykzdgkjyw3-vm-test-run-disko-hearth-vm-offline-boot` |
| `vm-offline-link` | `/nix/store/8di2qi5ly7jvfpn1qgxbzm08g16d9nxw-vm-test-run-disko-hearth-vm-offline-link` |
| `vm-persistence` | `/nix/store/qb4as8qn3s3yj3h1cfi6f6hcfnk7ca9m-vm-test-run-disko-hearth-vm-persistence` |

账户测试已实际通过，99.94 秒。验证初始密码、正常 passwd、修改立即生效、三次 userborn 重启、两次系统重启、新密码认证、旧密码明确拒绝、真实持久哈希一致、shadow 权限和 root 锁定；最终关机后检查无依赖环。

| 本次检查 | 结果 / 边界 |
| --- | --- |
| `just check` | PASS：Nix 格式、ShellCheck、路径/秘密扫描、扫描负向自测、flake no-build 求值检查；自测里预期出现的假凭据告警不代表仓库泄露。 |
| `system-preview` / `eval-contracts` | PASS；预览包含真实硬件驱动闭包与虚拟存储，不代表实机部署。 |
| `vm-accounts` | PASS，99.94 s，两次重启、三次 userborn 重启。 |
| `vm-persistence` | PASS，51.56 s；实际执行原生 profile / GC 场景，guest-private store，不操作宿主 GC。 |
| `vm-offline-boot` | PASS，39.67 s；目标来宾明确无网卡，KVM，userspace 3.188 s，总计 7.825 s。 |
| `vm-offline-link` | PASS，38.54 s；目标来宾链路存在且无 DHCP，KVM，userspace 2.813 s，总计 7.706 s。 |
| 四个 VM 的完整串口日志 | 无 `Found ordering cycle` / `deleted to break ordering cycle`；公共测试包含最终关机后断言。 |

本次执行的 derivation（可使用 `nix log <drv>` 读取构建日志）：


| 检查 | Derivation |
| --- | --- |
| `eval-contracts` | `/nix/store/iwfm907chlf61pgrfkga4x3m547hw0yl-hearth-eval-contracts.drv` |
| `system-preview` | `/nix/store/9jj94lbzr8aa8fv5l8fhapyy0axi54lk-nixos-system-hearth-26.11.20261107.dirty.drv` |
| `vm-accounts` | `/nix/store/sraykfj4ch6vhj5c83b9gw7c59mcjp28-vm-test-run-disko-hearth-vm-accounts.drv` |
| `vm-offline-boot` | `/nix/store/1vdp8p9cfpjkvgmzj3pbqkirgag87c43-vm-test-run-disko-hearth-vm-offline-boot.drv` |
| `vm-offline-link` | `/nix/store/yilgafl4529c5cr6jlnr4qppw24fvihr-vm-test-run-disko-hearth-vm-offline-link.drv` |
| `vm-persistence` | `/nix/store/b07jsigrfp0jx1k2l73bn29bsmgpakw9-vm-test-run-disko-hearth-vm-persistence.drv` |

## 验收整改逐项结论

| 项 | 结论 | 证据 |
| --- | --- | --- |
| R1 密码持久化 | PASS | PAM 链接目标补丁保留；账户 VM 正常改密、两次系统重启、三次 userborn 重启后新密码有效、旧密码明确拒绝；持久文件只有一条记录，属主/权限和 root 锁定检查通过 |
| R2 关机依赖环 | PASS | 账户目录与底层 `persist.mount` 的早期语义修正；公共测试覆盖完整串口日志、持久 journal 和最终关机，未发现 ordering cycle |
| R3 登录/改密测试可信度 | PASS | 统一 `tests/vm/login.exp`，认证成功必须执行身份查询并输出 `HEARTH_LOGIN:wallyhao`；拒绝必须匹配明确错误；timeout、EOF、输入回显、错误接受/拒绝均有负向对照 |
| R4 原生 profile/GC | PASS | `vm-persistence` 使用 `nix profile install`、`remove`、`wipe-history` 与 guest-private store GC；无手工链接、无额外 roots、不触碰宿主 store |
| R5 CI/密钥与路径扫描 | PASS | `just check` 运行 gitleaks、覆盖 `modules/` 的路径扫描、扫描失败区分和假凭据/禁止路径负向自测 |
| 断网场景 | PASS | `vm-offline-boot`（明确无 NIC）与 `vm-offline-link`（链路存在、无 DHCP）均通过；KVM，userspace 3.188 s / 2.813 s，关键链无 wait-online/upgrade |

## 证据边界及后续工作

- 第一阶段代码、锁文件、完整预览构建、检查与隔离 VM 测试已完成；整体
  状态按计划为 `CODE_AND_VM_COMPLETE / STORAGE_UNBOUND`。
- 尚未执行真实内置盘安装，也不声明已安装。storage-spec 仍为
  `null/null/false`，未导出 `nixosConfigurations.hearth`。
- 远端 GitHub CI 未触发；不声明远端工作流通过。
- 远端 GitHub CI 未触发；不声明远端工作流通过。
- 真实目标仍未导出 `nixosConfigurations.hearth`。磁盘绑定保持 null/null/false，预览仅使用虚拟 storage fixture。
- 内置盘安装、真实冷启动、功耗、初始内存、GPU runtime PM、休眠与固件行为均未测量；见 [performance.md](performance.md) 和 [storage-binding.md](storage-binding.md)。
- 没有新增 flake inputs 或更新 lock，没有部署、激活宿主或操作真实盘。账户与服务重启操作只发生在 VM 内。

## 锁定来源与维护

nixpkgs `f4a03c008967841f2a0b3cb7c436fc6fc31671f6`；flake-parts
`ea2630b7470978622c7689a1ff75d2b389175399`；disko
`cedd626e11b635470fa6f9fdb8ad79b0075dd7f9`；preservation
`00be7f7dd1a11ae0605386f2272288de7cf33abe`。
`system.stateVersion` 仍为字面量 `26.11`。

本地 PAM 补丁属于需要随输入升级维护的兼容性修复，不能因测试误判已修好就删除它。
具体源码依据和 option 选择见 [phase1-decisions.md](phase1-decisions.md)。
