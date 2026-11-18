# 文件互传常驻服务 实施计划

> **For executors:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 开机即运行 `file-drop` 服务，手机浏览器通过 basic auth 访问 `http://<本机IP>:7373/` 浏览、上传、下载 `~/Downloads/Share` 中的文件。

**Architecture:** 单个 NixOS 模块声明 systemd 服务（miniserve 0.35.0）、tmpfiles 目录、防火墙端口；凭据由 `ExecStartPre` 在首次启动时生成到持久化目录，经 `--auth-file` 传入，不进 store、不进 argv。用现有 `tests/vm/common.nix` 加一个 VM 检查作为验收测试。

**Tech Stack:** NixOS 26.11 模块、systemd、nixpkgs 的 `miniserve` 0.35.0、NixOS VM test driver。

**Spec:** `docs/specs/2026-11-18-lan-file-transfer-design.md`

## Global Constraints

- 端口固定 `7373`；服务名固定 `file-drop`。
- 共享目录 `/home/wallyhao/Downloads/Share`；凭据目录 `/home/wallyhao/.local/state/file-drop`，凭据文件 `auth`，内容一行 `wallyhao:<密码>`，权限 `0600`。
- 服务身份 `User = "wallyhao"`、`Group = "users"`。
- miniserve 参数固定为 `-p 7373 -u -P --auth-file <auth> -t 'Ember 文件互传'`（`-u` 开上传，`-P` 禁软链跟随）。
- 密码、密钥不得出现在 `/nix/store`、仓库或 Nix 求值结果里。
- 不得激活主机（`nixos-rebuild switch` 需用户明确指示）；验证止于 `just check`、`just build`、`nix build` 的 VM 检查。

## Review Focus

- **首次开机没有凭据文件**：服务必须自建 0600 凭据并拒绝匿名访问，而不是无认证启动或崩溃循环。→ Task 2 前两个 subtest。
- **手机重复同名上传**：第二个文件必须被拒绝（409）且不覆盖原文件。→ Task 2 `duplicate name` subtest。
- **服务进程被杀死**：必须自动重启，MainPID 变化。→ Task 2 `restarts after a crash` subtest。
- **重启后凭据丢失**：凭据目录必须在 preservation 里，重启后文件仍在。→ Task 2 扩展 `tests/vm/persistence.nix`。
- **凭据文件被截断为 0 字节**：必须重新生成，而不是拿着空文件启动服务。→ Task 2 追加 `empty credential file is regenerated` subtest。

---

### Task 1: `file-drop` 模块与持久化登记

**Files:**
- Create: `modules/network/file-drop.nix`
- Modify: `users/wallyhao/persistence.nix`（在 `.local/state/ember-refresh` 条目之后插入）

**Interfaces:**
- Consumes: `pkgs.miniserve`、`pkgs.coreutils`、`lib.getExe`、`lib.makeBinPath`、`modules/network/default.nix` 的自动导入。
- Produces: systemd 单元 `file-drop.service`；TCP 端口 `7373` 在 `networking.firewall.allowedTCPPorts` 内；目录 `/home/wallyhao/Downloads/Share`。Task 2 的 VM 检查依赖这三者与 `<authDir>/auth` 的格式。

- [ ] **Step 1: 写模块文件 `modules/network/file-drop.nix`**

```nix
{
  lib,
  pkgs,
  ...
}:
let
  port = 7373;
  shareDir = "/home/wallyhao/Downloads/Share";
  authDir = "/home/wallyhao/.local/state/file-drop";
  authFile = "${authDir}/auth";

  # Credentials are read from a runtime file: the password must not reach the
  # Nix store, the unit's command line, or any generated documentation.
  ensureAuth = pkgs.writeShellScript "ember-file-drop-auth" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    if [ ! -s ${authFile} ]; then
      umask 077
      password=$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | cut -c 1-16)
      printf 'wallyhao:%s\n' "$password" > ${authFile}
    fi
  '';
in
{
  networking.firewall.allowedTCPPorts = [ port ];

  systemd.tmpfiles.rules = [
    "d ${shareDir} 0755 wallyhao users -"
    "d ${authDir} 0700 wallyhao users -"
  ];

  systemd.services.file-drop = {
    description = "Ember LAN file drop (miniserve)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "wallyhao";
      Group = "users";
      ExecStartPre = ensureAuth;
      ExecStart = "${lib.getExe pkgs.miniserve} ${shareDir} -p ${toString port} -u -P --auth-file ${authFile} -t 'Ember 文件互传'";
      Restart = "always";
      RestartSec = 2;
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      ReadWritePaths = [
        shareDir
        authDir
      ];
    };
  };
}
```

- [ ] **Step 2: 在 `users/wallyhao/persistence.nix` 登记凭据目录**

紧跟 `.local/state/ember-refresh` 条目后加：

```nix
    {
      # file-drop 的 basic-auth 凭据；tmpfs 根会丢掉它，服务就会匿名启动。
      directory = ".local/state/file-drop";
      mode = "0700";
    }
```

- [ ] **Step 3: 跑静态门禁**

Run: `just check`
Expected: 退出码 0（nixfmt --check、deadnix、actionlint、`tests/cli.sh`、`scripts/ember check` 全过）

- [ ] **Step 4: 求值确认单元与端口**

Run:
```sh
nix eval --raw path:.#nixosConfigurations.ember.config.networking.firewall.allowedTCPPorts
nix eval --raw path:.#nixosConfigurations.ember.config.systemd.services.file-drop.serviceConfig.ExecStart
```
Expected: 第一条输出包含 `7373`；第二条包含 `miniserve`、`-p 7373`、`-u -P`、`--auth-file`。

- [ ] **Step 5: 构建 toplevel（不激活）**

Run: `just build`
Expected: 构建成功，无 failed assertions。

- [ ] **Step 6: 提交**

```bash
git add modules/network/file-drop.nix users/wallyhao/persistence.nix
git commit -m "feat(network): add resident LAN file drop service"
```

---

### Task 2: VM 检查（服务、认证、上传、重启）

**Files:**
- Create: `tests/vm/file-drop.nix`
- Modify: `flake/checks.nix:119`（在 `vm-connectivity` 行后加一行）
- Modify: `justfile`（`vm` 配方的 `checks=(...)` 数组末尾加 `vm-file-drop`）
- Modify: `tests/vm/persistence.nix`（重启前写标记、重启后断言标记仍在）

**Interfaces:**
- Consumes: Task 1 的 `file-drop.service`、端口 7373、`/home/wallyhao/Downloads/Share`、`/home/wallyhao/.local/state/file-drop/auth`；`tests/vm/common.nix` 的 `makeDiskoTest` 包装（参数 `name`、`extraTestScript`、`extraSystemConfig`）。
- Produces: 无（终端检查）。

- [ ] **Step 1: 写 `tests/vm/file-drop.nix`**

```nix
{
  inputs,
  pkgs,
  inventory,
}:
import ./common.nix {
  inherit inputs pkgs inventory;
  name = "ember-vm-file-drop";
  extraSystemConfig = {
    environment.systemPackages = [ pkgs.curl ];
  };
  extraTestScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("file-drop.service")
    machine.wait_for_open_port(7373)

    with subtest("unauthenticated access is refused"):
        code = machine.succeed(
            "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:7373/"
        ).strip()
        t.assertEqual(code, "401")

    with subtest("first start generates a private credential file"):
        creds = machine.succeed(
            "cat /home/wallyhao/.local/state/file-drop/auth"
        ).strip()
        t.assertTrue(creds.startswith("wallyhao:"), creds)
        t.assertTrue(len(creds) > 20, creds)
        t.assertEqual(
            machine.succeed(
                "stat -c '%U %a' /home/wallyhao/.local/state/file-drop/auth"
            ).strip(),
            "wallyhao 600",
        )

    with subtest("upload lands in the shared directory"):
        machine.succeed("printf 'probe\\n' > /tmp/probe.txt")
        machine.succeed(
            f"curl -sf -u {creds} -F 'file=@/tmp/probe.txt;filename=probe.txt' "
            "'http://127.0.0.1:7373/upload?path=/'"
        )
        t.assertEqual(
            machine.succeed("cat /home/wallyhao/Downloads/Share/probe.txt").strip(),
            "probe",
        )
        t.assertEqual(
            machine.succeed("stat -c '%U' /home/wallyhao/Downloads/Share/probe.txt").strip(),
            "wallyhao",
        )

    with subtest("authenticated download returns the same bytes"):
        t.assertEqual(
            machine.succeed(f"curl -sf -u {creds} http://127.0.0.1:7373/probe.txt").strip(),
            "probe",
        )

    with subtest("duplicate name is rejected without overwriting"):
        code = machine.succeed(
            f"curl -s -o /dev/null -w '%{{http_code}}' -u {creds} "
            "-F 'file=@/tmp/probe.txt;filename=probe.txt' "
            "'http://127.0.0.1:7373/upload?path=/'"
        ).strip()
        t.assertEqual(code, "409")

    with subtest("firewall admits the service port"):
        t.assertIn("7373", machine.succeed("nft list ruleset"))

    with subtest("service restarts after a crash"):
        old = machine.succeed("systemctl show -p MainPID --value file-drop.service").strip()
        machine.succeed("systemctl kill -s KILL file-drop.service")
        machine.wait_until_succeeds(
            f'test "$(systemctl show -p MainPID --value file-drop.service)" != "{old}"',
            timeout=60,
        )

    with subtest("empty credential file is regenerated"):
        machine.succeed(": > /home/wallyhao/.local/state/file-drop/auth")
        machine.succeed("systemctl restart file-drop.service")
        machine.wait_for_unit("file-drop.service")
        renewed = machine.succeed(
            "cat /home/wallyhao/.local/state/file-drop/auth"
        ).strip()
        t.assertTrue(renewed.startswith("wallyhao:"), renewed)
        t.assertTrue(len(renewed) > 20, renewed)
  '';
}
```

- [ ] **Step 2: 注册检查**

`flake/checks.nix` 在 `vm-connectivity = ...` 之后加：

```nix
        vm-file-drop = import ../tests/vm/file-drop.nix vmArgs;
```

`justfile` 的 `checks=(...)` 末尾加 `vm-file-drop`。

- [ ] **Step 3: 扩展 `tests/vm/persistence.nix` 的重启断言**

在 `netstat`（即 `prepare ephemeral...` subtest）里补一行标记：

```python
        machine.succeed("echo file-drop-marker > /home/wallyhao/.local/state/file-drop/marker")
        machine.succeed("chmod 600 /home/wallyhao/.local/state/file-drop/marker")
```

在现有重启后的 preserved-paths 断言处补：

```python
        t.assertEqual(
            machine.succeed("cat /home/wallyhao/.local/state/file-drop/marker").strip(),
            "file-drop-marker",
        )
```

- [ ] **Step 4: 先确认检查能跑起来（服务已在 Task 1 存在，此步应通过）**

Run: `nix build --no-link --no-update-lock-file 'path:.#checks.x86_64-linux.vm-file-drop'`
Expected: 构建并运行通过；所有 subtest 通过，无 assertion 失败。

- [ ] **Step 5: 跑持久化检查**

Run: `nix build --no-link --no-update-lock-file 'path:.#checks.x86_64-linux.vm-persistence'`
Expected: 通过，包含新的 `file-drop-marker` 断言。

- [ ] **Step 6: 提交**

```bash
git add tests/vm/file-drop.nix tests/vm/persistence.nix flake/checks.nix justfile
git commit -m "test(network): verify file-drop service, auth and persistence"
```

---

### Task 3: 文档

**Files:**
- Modify: `docs/operations.md`（新增一节，放在 `## Network and proxy` 与 `## Graphical session` 之间）
- Modify: `docs/specs/2026-11-18-lan-file-transfer-design.md`（在“凭据”条目补一句：由服务首次启动自动生成）

**Interfaces:**
- Consumes: Task 1 的端口、目录、凭据路径；Task 2 的验证结论。
- Produces: 无。

- [ ] **Step 1: 写 `docs/operations.md` 新节**

内容须覆盖：地址 `http://<本机IP>:7373/`；共享目录 `~/Downloads/Share`；第一次访问的用户名 `wallyhao`、密码从
`~/.local/state/file-drop/auth` 读取（`cat`）；重设密码 = 删掉该文件后
`sudo systemctl restart file-drop`；启动日志里的二维码
`journalctl -u file-drop -b | grep -A40 'miniserve v'`；手机上传同名文件会返回冲突、页面没有删除按钮，删除要在电脑上做；建议在路由器给本机做 DHCP 地址保留；只放行 7373，其它端口仍关闭；7373 被占用时服务会反复重启并报绑定失败，不会自动换端口。

- [ ] **Step 2: 保持设计文档与实现一致**

把“凭据”条目的“内容一行 `wallyhao:<密码>`”改为包含“服务首次启动时自动生成，无需手工创建”。

- [ ] **Step 3: 全文门禁**

Run: `just check`
Expected: 退出码 0。

- [ ] **Step 4: 提交**

```bash
git add docs/operations.md docs/specs/2026-11-18-lan-file-transfer-design.md
git commit -m "docs: describe the file-drop service"
```
