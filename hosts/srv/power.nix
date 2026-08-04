{ pkgs, ... }:

# CPU frequency ceiling for srv (Slimbook PROX14, i7-8565U, 15W ULV, 4c/8t).
#
# srv is the sole libvirt/KVM hypervisor for the darkstar cluster's two Talos
# VMs (cp01, wk01), which together pin ~3.8 of the 4 physical cores 24/7. That
# is a steady load, not a bursty one, so with turbo fully uncapped
# (intel_pstate no_turbo=0, max_perf_pct=100) the package chases near-4.6GHz
# sustained clocks, sits at ~78-82C on x86_pkg_temp, and runs the fan
# continuously. Power scales worse than linearly at the top of the V/f curve,
# so the last few hundred MHz cost disproportionate heat for very little
# throughput on a workload that is never latency-critical.
#
# Capping max_perf_pct at 80 trims only the top of the curve: 80% of the
# highest turbo P-state is roughly 3.6-3.7GHz, still well above this chip's
# 1.8GHz base frequency (turbo_pct=66, cpuinfo range 0.4-4.6GHz). Deliberately
# NOT no_turbo=1 -- that would clamp to the 1.8GHz base and is a much bigger
# throughput hit than the fan noise warrants. Tune maxPerfPct down (70, 60) if
# the fan is still audible; it is a single number here.
#
# scaling_governor is already `powersave`, which is correct for intel_pstate
# active mode and is not what this file changes.
#
# Mechanism: a systemd oneshot, because there is no other option.
#   - NixOS has no `max_perf_pct` option. `powerManagement.cpuFreqGovernor`
#     covers the governor and `powerManagement.cpufreq.max` drives `cpupower
#     frequency-set --max` (a per-CPU scaling_max_freq in kHz), but neither
#     touches intel_pstate's global percentage knob.
#   - There is no boot parameter for it either. The intel_pstate driver accepts
#     only `intel_pstate=<disable|active|passive|force|no_hwp|hwp_only|
#     support_acpi_ppc|per_cpu_perf_limits|no_cas>` on the kernel command line
#     (Documentation/admin-guide/pm/intel_pstate.rst); max_perf_pct is a
#     runtime sysfs attribute only, so it must be written after boot.
# The unit shape mirrors nixpkgs' own systemd.services.cpufreq (oneshot +
# RemainAfterExit), and `nixos-rebuild switch` starts it, so the cap applies
# immediately rather than only at the next boot.
let
  maxPerfPct = 80;
  knob = "/sys/devices/system/cpu/intel_pstate/max_perf_pct";
in
{
  systemd.services.intel-pstate-cap = {
    description = "Cap intel_pstate max_perf_pct at ${toString maxPerfPct}%";
    wantedBy = [ "multi-user.target" ];
    after = [ "sysinit.target" ];

    # Skip cleanly rather than fail if the host ever boots without the
    # intel_pstate driver in active mode (e.g. intel_pstate=disable).
    unitConfig.ConditionPathExists = knob;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "intel-pstate-cap-start" ''
        echo ${toString maxPerfPct} > ${knob}
      '';
      # Restore the driver default on stop so a `systemctl stop` (or a rebuild
      # that removes this file) leaves the knob uncapped instead of stuck at 80.
      ExecStop = pkgs.writeShellScript "intel-pstate-cap-stop" ''
        echo 100 > ${knob}
      '';
    };
  };
}
