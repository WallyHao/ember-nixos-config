#!/usr/bin/env bash
# Ember power diagnostic report. Read-only: no tunables, services or files
# outside the report directory are modified.
#
# Usage:
#   sudo ./scripts/power-report.sh           # full run, ~4 minutes
#   sudo ./scripts/power-report.sh --fast    # skip powertop/powerstat, ~1.5 min
#   sudo ./scripts/power-report.sh --baseline <report-dir>
#                                            # also diff against an older report
#   OUT=/path sudo ./scripts/power-report.sh # custom output directory
#
# Output (default /tmp/ember-power-report-<timestamp>/):
#   report.md      all readings, one file
#   powertop.md    powertop report (Markdown, embedded below)
#   powertop.csv   powertop machine-readable fallback
#   gpu.json       intel_gpu_top JSON samples
set -uo pipefail
umask 022

usage() {
  sed -n '2,30p' "$0" | sed -n '/^#/p' | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  echo "run with sudo: sudo $0 ${1:-}" >&2
  exit 1
fi

USER_NAME=${SUDO_USER:-wallyhao}
USER_UID=$(id -u "$USER_NAME" 2>/dev/null || echo 1000)
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
PATH="$USER_HOME/.local/state/nix/profiles/profile/bin:$PATH"
export PATH

FAST=0
BASELINE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --fast)
      FAST=1
      shift
      ;;
    --baseline)
      BASELINE=${2:-}
      [ -n "$BASELINE" ] || {
        echo "--baseline needs a report directory" >&2
        exit 2
      }
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

OUT=${OUT:-/tmp/ember-power-report-$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUT"
BODY="$OUT/body.md"
SUMMARY="$OUT/summary.md"
REPORT="$OUT/report.md"
: >"$BODY"
: >"$SUMMARY"

START=$(date +%s)
BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
export BAT

say() { printf '[power-report] %s\n' "$*" >&2; }
p() { printf '%s\n' "$*" >>"$BODY"; }
h() {
  printf '\n## %s\n\n' "$*" >>"$BODY"
  say "$*"
}
sub() { printf '\n### %s\n\n' "$*" >>"$BODY"; }
note() { printf '%s\n\n' "$*" >>"$BODY"; }

# run "title" command...
run() {
  local title=$1
  shift
  printf '\n**`%s`**\n\n```\n' "$*" >>"$BODY"
  timeout 240 "$@" >>"$BODY" 2>&1
  local st=$?
  [ "$st" -ne 0 ] && printf '[exit %d]\n' "$st" >>"$BODY"
  printf '```\n' >>"$BODY"
}

# run_sh "title" 'shell body'
run_sh() {
  local title=$1 body=$2
  printf '\n**%s**\n\n```\n' "$title" >>"$BODY"
  timeout 300 bash -c "$body" >>"$BODY" 2>&1
  local st=$?
  [ "$st" -ne 0 ] && printf '[exit %d]\n' "$st" >>"$BODY"
  printf '```\n' >>"$BODY"
}

gpu_state() {
  local d
  for d in 0000:01:00.0 0000:01:00.1 0000:00:01.0; do
    local s=/sys/bus/pci/devices/$d
    [ -d "$s" ] || continue
    printf -- '- %s power_state=%s runtime_status=%s control=%s d3cold_allowed=%s\n' \
      "$d" \
      "$(cat "$s/power_state" 2>/dev/null)" \
      "$(cat "$s/power/runtime_status" 2>/dev/null)" \
      "$(cat "$s/power/control" 2>/dev/null)" \
      "$(cat "$s/d3cold_allowed" 2>/dev/null)" >>"$BODY"
  done
}

# ---------------------------------------------------------------- system
h "System"
p "- date: $(date -Is)"
p "- host: $(hostname)"
p "- kernel: $(uname -r)"
p "- system: $(readlink -f /run/current-system)"
p "- uptime: $(awk '{d=int($1); printf "%dd %dh %dm", d/86400, (d%86400)/3600, (d%3600)/60}' /proc/uptime)"
p "- mode: $([ "$FAST" -eq 1 ] && echo fast || echo full)"
run "kernel cmdline" cat /proc/cmdline

# ------------------------------------------------------------ power supply
h "Power supply"
run_sh "all power supplies" 'for d in /sys/class/power_supply/*; do n=${d##*/}; printf "%s type=%s online=%s status=%s capacity=%s\n" "$n" "$(cat "$d/type" 2>/dev/null)" "$(cat "$d/online" 2>/dev/null)" "$(cat "$d/status" 2>/dev/null)" "$(cat "$d/capacity" 2>/dev/null)"; done'

if [ -n "$BAT" ]; then
  sub "Battery attributes"
  for f in status capacity energy_now energy_full energy_full_design power_now cycle_count; do
    if [ -r "$BAT/$f" ]; then
      p "- $f: $(cat "$BAT/$f")"
    fi
  done

  sub "Battery power_now + energy drain (30 s window)"
  ENERGY_W=""
  if [ -r "$BAT/power_now" ]; then
    : >"$OUT/battery.raw"
    e0=$(cat "$BAT/energy_now" 2>/dev/null || true)
    for _ in $(seq 1 15); do
      cat "$BAT/power_now" >>"$OUT/battery.raw" 2>/dev/null || true
      sleep 2
    done
    e1=$(cat "$BAT/energy_now" 2>/dev/null || true)
    awk '{s+=$1; if(NR==1||$1<min)min=$1; if($1>max)max=$1} END{if(NR)printf "- power_now: samples=%d min=%.2f W avg=%.2f W max=%.2f W\n", NR, min/1e6, s/NR/1e6, max/1e6}' "$OUT/battery.raw" >>"$BODY"
    if [ -n "$e0" ] && [ -n "$e1" ]; then
      ENERGY_W=$(awk -v a="$e0" -v b="$e1" 'BEGIN{printf "%.2f", (a-b)*3600/30/1e6}')
      p "- energy drain: $e0 -> $e1 uWh over 30 s = ${ENERGY_W} W"
    fi
  else
    note "power_now not available"
  fi
fi

# --------------------------------------------------------------------- TLP
h "TLP"
run "TLP status" tlp-stat -s
run "TLP processor" tlp-stat -p
run_sh "TLP selected settings" 'tlp-stat -c 2>/dev/null | grep -E "CPU_|PLATFORM_PROFILE|RUNTIME_PM|WIFI_PWR|SOUND_POWER|USB_AUTOSUSPEND|NMI_WATCHDOG|DISK_APM|PCIE_ASPM"'
run "TLP USB" tlp-stat -u
[ -n "$BAT" ] && run "TLP battery" tlp-stat -b

# --------------------------------------------------------------------- CPU
h "CPU"
run "cpuidle driver" cat /sys/devices/system/cpu/cpuidle/current_driver
run_sh "governor / EPP / driver" 'for f in /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference /sys/firmware/acpi/platform_profile; do [ -r "$f" ] && printf "%s=%s\n" "$f" "$(cat "$f")"; done'
run_sh "cpuidle states (cpu0, cpu8, cpu16)" 'for c in 0 8 16; do d=/sys/devices/system/cpu/cpu$c/cpuidle; [ -d "$d" ] || continue; echo "cpu$c:"; for s in "$d"/state*; do printf "  %s latency=%s usage=%s time=%s\n" "$(cat "$s/name")" "$(cat "$s/latency")" "$(cat "$s/usage")" "$(cat "$s/time")"; done; done'
run_sh "low power idle residency" 'for f in /sys/devices/system/cpu/cpuidle/low_power_idle_*; do printf "%s=%s\n" "${f##*/}" "$(cat "$f")"; done'

sub "RAPL domain power (10 s window)"
if compgen -G "/sys/class/powercap/intel-rapl:*/" >/dev/null; then
  declare -A rapl_e0=()
  mapfile -t rapl_dom < <(ls -d /sys/class/powercap/intel-rapl:*/)
  for d in "${rapl_dom[@]}"; do
    rapl_e0[$d]=$(cat "$d/energy_uj" 2>/dev/null || echo 0)
  done
  sleep 10
  for d in "${rapl_dom[@]}"; do
    awk -v n="$(cat "$d/name" 2>/dev/null)" \
      -v a="${rapl_e0[$d]}" \
      -v b="$(cat "$d/energy_uj" 2>/dev/null || echo 0)" \
      'BEGIN{printf "- %s: %.2f W\n", n, (b-a)/10/1e6}' >>"$BODY"
  done
else
  note "no intel-rapl domains exposed"
fi

if [ "$FAST" -eq 0 ] && command -v turbostat >/dev/null; then
  sub "turbostat (30 s: 6 samples, 5 s apart)"
  timeout 90 turbostat -i 5 -n 6 >>"$BODY" 2>&1 || p "[turbostat failed]"
fi

# --------------------------------------------------------------------- GPU
h "GPU"

sub "PCI runtime state before any GPU probe"
gpu_state

run_sh "DRM devices" 'for c in /sys/class/drm/card[0-9]* /sys/class/drm/renderD*; do [ -e "$c/device" ] || continue; printf "%s driver=%s\n" "${c##*/}" "$(readlink -f "$c/device/driver" | xargs -r basename)"; done'
run_sh "nvidia runtime D3" 'for f in /proc/driver/nvidia/gpus/*/power; do [ -r "$f" ] && cat "$f"; done'
run "nvidia_drm refcnt" cat /sys/module/nvidia_drm/refcnt
run_sh "nvidia_drm parameters" 'for f in /sys/module/nvidia_drm/parameters/*; do [ -r "$f" ] && printf "%s=%s\n" "${f##*/}" "$(cat "$f")"; done; true'

sub "Processes holding dGPU fds"
run_sh "dGPU fd holders" 'for p in /proc/[0-9]*; do n=$(ls -l "$p/fd" 2>/dev/null | grep -cE "nvidia|renderD129|/dri/card0"); [ "$n" -gt 0 ] && printf "%s %s fds=%s\n" "${p#/proc/}" "$(cat "$p/comm" 2>/dev/null)" "$n"; done; true'

sub "nvidia-smi (NOTE: this wakes the dGPU)"
run "nvidia-smi" nvidia-smi --query-gpu=name,pstate,power.draw,utilization.gpu,memory.used --format=csv

sub "PCI runtime state 15 s after nvidia-smi"
sleep 15
gpu_state

if command -v intel_gpu_top >/dev/null; then
  sub "intel_gpu_top (10 s JSON, i915)"
  timeout 40 intel_gpu_top -J -s 1000 -n 10 -d pci:0000:00:02.0 \
    -o "$OUT/gpu.json" >"$OUT/gpu.log" 2>&1
  if [ -s "$OUT/gpu.json" ]; then
    p '```'
    head -c 5000 "$OUT/gpu.json" >>"$BODY"
    p '```'
  else
    note "intel_gpu_top produced no samples; see $OUT/gpu.log. turbostat GFX%rc6 covers the same question."
    p '```'
    head -n 8 "$OUT/gpu.log" >>"$BODY" 2>/dev/null || true
    p '```'
  fi
fi

# ----------------------------------------------------------------- display
h "Display"
run_sh "backlight" 'for b in /sys/class/backlight/*; do printf "%s brightness=%s/%s\n" "$b" "$(cat "$b/actual_brightness" 2>/dev/null)" "$(cat "$b/max_brightness" 2>/dev/null)"; done'
run_sh "connectors" 'for c in /sys/class/drm/card*-eDP-*; do [ -e "$c/status" ] && printf "%s status=%s enabled=%s\n" "$c" "$(cat "$c/status")" "$(cat "$c/enabled")"; done'

NIRI_BIN=$(command -v niri 2>/dev/null || true)
if [ -z "$NIRI_BIN" ]; then
  NIRI_BIN=$(ls -d /etc/profiles/per-user/"$USER_NAME"/bin/niri 2>/dev/null | head -1)
fi
NIRI_SOCK=$(ls /run/user/"$USER_UID"/niri.*.sock 2>/dev/null | head -1)
NIRI_OUT=""
if [ -n "$NIRI_BIN" ] && [ -n "$NIRI_SOCK" ]; then
  NIRI_OUT=$(runuser -u "$USER_NAME" -- env \
    XDG_RUNTIME_DIR="/run/user/$USER_UID" NIRI_SOCKET="$NIRI_SOCK" \
    "$NIRI_BIN" msg outputs 2>&1)
  sub "niri outputs"
  p '```'
  printf '%s\n' "$NIRI_OUT" >>"$BODY"
  p '```'
fi

# ------------------------------------------------------------------ wireless
h "Wireless"
WIFI_PS="(n/a)"
IWBIN=$(command -v iw 2>/dev/null || ls -d /nix/store/*-iw-*/bin/iw 2>/dev/null | head -1)
if [ -n "$IWBIN" ]; then
  for d in /sys/class/net/wl*; do
    [ -e "$d" ] || continue
    ifc=${d##*/}
    ps_out=$("$IWBIN" dev "$ifc" get power_save 2>&1 | tr -d '\n')
    p "- $ifc: $ps_out"
    WIFI_PS="$ps_out"
  done
else
  p "- iw binary not found"
fi
run_sh "Wi-Fi PCI runtime state" 'for d in /sys/class/net/wl*; do [ -e "$d/device" ] || continue; printf "%s runtime=%s control=%s\n" "${d##*/}" "$(cat "$d/device/power/runtime_status" 2>/dev/null)" "$(cat "$d/device/power/control" 2>/dev/null)"; done'

# ---------------------------------------------------------------- powertop
if [ "$FAST" -eq 0 ] && command -v powertop >/dev/null; then
  h "powertop (60 s)"
  timeout 150 powertop --time=60 --markdown="$OUT/powertop.md" >"$OUT/powertop.log" 2>&1
  PT_SUM=$?
  if [ "$PT_SUM" -ne 0 ] || [ ! -s "$OUT/powertop.md" ]; then
    timeout 150 powertop --time=60 --csv="$OUT/powertop.csv" >>"$OUT/powertop.log" 2>&1
    PT_SUM=$?
  fi
  p "- exit: $PT_SUM"
  p "- files: $OUT/powertop.md $OUT/powertop.csv $OUT/powertop.log"
  if [ -s "$OUT/powertop.md" ]; then
    sub "powertop report (first 220 lines)"
    head -n 220 "$OUT/powertop.md" >>"$BODY"
  elif [ -s "$OUT/powertop.csv" ]; then
    sub "powertop matched lines (CSV)"
    p '```'
    grep -iE 'nvidia|snd_hda|iwlwifi|niri|Package|DRAM|GFX|PCI|Audio|USB|backlight' \
      "$OUT/powertop.csv" | head -60 >>"$BODY" || true
    p '```'
  fi
fi

# ---------------------------------------------------------------- powerstat
if [ "$FAST" -eq 0 ] && command -v powerstat >/dev/null && [ -n "$BAT" ]; then
  h "powerstat (CPU/RAPL watts, 12 samples x 5 s)"
  p '```'
  timeout 240 powerstat -d 5 -z -D -c -f -t 5 12 >>"$BODY" 2>&1 || p "[powerstat failed]"
  p '```'
fi

# -------------------------------------------------------------------- load
h "Load snapshot"
run_sh "top (second sample)" "top -b -n 2 -d 2 | awk '/^top -/{n++} n==2' | head -30"
run_sh "pressure" 'for f in /proc/pressure/*; do printf "%s: " "$f"; cat "$f"; done'

# ----------------------------------------------------------------- summary
BL=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
{
  echo "## Key readings"
  echo
  if [ -n "$BAT" ]; then
    echo "- battery: $(cat "$BAT/status" 2>/dev/null) $(cat "$BAT/capacity" 2>/dev/null)% power_now=$(cat "$BAT/power_now" 2>/dev/null) uW"
  fi
  if [ -d /sys/bus/pci/devices/0000:01:00.0 ]; then
    echo "- dGPU 01:00.0: runtime=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null) power_state=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null)"
    echo "- dGPU 01:00.1: runtime=$(cat /sys/bus/pci/devices/0000:01:00.1/power/runtime_status 2>/dev/null)"
  fi
  echo "- nvidia_drm refcnt: $(cat /sys/module/nvidia_drm/refcnt 2>/dev/null)"
  echo "- Wi-Fi power save: $WIFI_PS"
  if [ -n "$BL" ]; then
    echo "- backlight: $(cat "$BL/actual_brightness" 2>/dev/null)/$(cat "$BL/max_brightness" 2>/dev/null)"
  fi
  if [ -n "$NIRI_OUT" ]; then
    printf '%s\n' "$NIRI_OUT" | grep -m1 'Current mode' | sed 's/^/ - /'
  fi
  if [ -n "${ENERGY_W:-}" ]; then
    echo "- battery energy-derived draw: $ENERGY_W W"
  fi
  echo "- report dir: $OUT"
} >"$SUMMARY"

# ------------------------------------------------------------- comparison
if [ -n "$BASELINE" ] && [ -f "$BASELINE/report.md" ]; then
  h "Comparison vs $(basename "$BASELINE")"
  b_avg=$(grep -m1 -oE 'avg=[0-9.]+ W' "$BASELINE/report.md" | grep -oE '[0-9.]+')
  n_avg=$(grep -m1 -oE 'avg=[0-9.]+ W' "$BODY" | grep -oE '[0-9.]+')
  p "| metric | baseline | now | delta |"
  p "|---|---|---|---|"
  if [ -n "$b_avg" ] && [ -n "$n_avg" ]; then
    awk -v a="$b_avg" -v b="$n_avg" 'BEGIN{printf "| battery power_now avg | %.2f W | %.2f W | %+.2f W |\n", a, b, b-a}' >>"$BODY"
  fi
  for key in 'dGPU 01:00.0' 'dGPU 01:00.1' 'Wi-Fi power save' 'backlight' 'Current mode'; do
    bv=$(grep -m1 "$key" "$BASELINE/report.md" | sed 's/^ *- *//')
    nv=$(grep -m1 "$key" "$SUMMARY" | sed 's/^ *- *//')
    p "| $key | ${bv:-n/a} | ${nv:-n/a} | |"
  done
  if [ -n "${ENERGY_W:-}" ]; then
    p ""
    p "- energy-derived draw now: ${ENERGY_W} W (baseline report predates this metric)"
  fi
fi

{
  echo "# Ember power report"
  echo
  echo "- generated: $(date -Is)"
  echo "- host: $(hostname) / $(uname -r)"
  echo "- system: $(readlink -f /run/current-system)"
  echo
  cat "$SUMMARY"
  cat "$BODY"
} >"$REPORT"

rm -f "$BODY" "$SUMMARY"
chmod -R a+rX "$OUT"

echo "Elapsed: $(( $(date +%s) - START ))s"
echo "Report: $REPORT"
[ -s "$OUT/powertop.md" ] && echo "powertop: $OUT/powertop.md"
[ -s "$OUT/powertop.csv" ] && echo "powertop csv: $OUT/powertop.csv"
[ -s "$OUT/gpu.json" ] && echo "intel_gpu_top: $OUT/gpu.json"
