# Ember 第四阶段状态

更新：2026-11-13。

状态：**SOURCE_MIGRATED / BUILD_PASS / CORE_DESKTOP_PASS / FULL_DESKTOP_INTERACTION_PENDING / PRIVATE_DATA_COPY_PENDING / NOT_DEPLOYED**。

## 已验证

- 最终真实系统 toplevel 构建成功：
  `/nix/store/43dcm9956whxg9gb1a5s19xfi4m06kbb-nixos-system-ember-26.11.20261107.dirty`。
- eval-contracts、eval-user-environment、desktop-config 构建通过；锁定 Niri/Foot 配置校验通过。
- CLI 模拟后端、ShellCheck、Bash 语法、Nix 格式、缓存指纹与代理数据规范化检查通过。
- 代理连接 VM 通过：虚拟网络的 TUN/DNS/节点故障回退与恢复、关闭状态跨重启、连接持久化。
- 登录 wrapper 的实际参数为 EMBERLIGHT，不含 Hearth；颜色来自 Stylix。
  图形 VM 已识别 EMBERLIGHT 并完成错误密码拒绝和正确密码登录。
- 离线 profile 安装/幂等、OMP、Foot 真实输入、启动器、Mako 消息接收、剪贴板文字及图片恢复通过。
- 桌面验证发现并修正自定义服务早于 Wayland 环境启动、Mako 缺少启动命令的问题；核心桌面已验证；按用户收敛测试的要求，停止后续重跑。

## 外部步骤与边界

1. Folio 的节点、订阅和 NM 资料需要用户本地 sudo；实际私有资料复制尚未执行。
2. 未安装/激活宿主，未改变 Folio 代理/网络，未分区、格式化、写 EFI 或重启实机。
3. 完整桌面 VM 尚未整体通过；权限弹窗取消、锁屏/解锁与电源确认尚未完成验收。
4. VM 使用仅测试的 Niri software-EGL overlay，不代表实机 GPU、休眠、亮度/音频或真实订阅已验收。
5. 新剪贴板为会话内历史；旧 Noctalia 数据保留，不自动解密或迁移。

最终测试记录见 phase4-report.md，部署顺序见 phase4-deployment.md。

## 后续软件调整

按用户要求，默认 profile 新增 Zen 1.22.2b（Folio 同一上游固定版本），并保留 `.config/zen`。
新软件集合和含该持久化规则的真实系统构建通过，`zen-beta --version` 输出符合预期。
离线缓存/指纹已更新，旧 Ember 软件集合也已加入精确迁移清单；没有重跑 VM。

## 外观调整（待切换验证）

- 光标改为 Bibata-Modern-Ice，36px；Home Manager `pointerCursor`、GTK/X11、
  `XCURSOR_THEME`/`XCURSOR_SIZE` 与 Niri `xcursor-*` 使用同一值。
- Zen 1.22.2b 保留原软件 profile；在持久化 profile
  `eryfevl7.Default Profile` 中通过 `user.js` 启用深色和 userChrome，
  并由 `userChrome.css`/`userContent.css` 套用 Emberlight 基础色。
- 临时 profile 已实际渲染确认 userChrome 生效；宿主尚未切换，当前会话仍使用旧光标。
