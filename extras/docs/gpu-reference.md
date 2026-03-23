# GPU Hardware Reference

Hardware-only GPU snapshot for hosts where GPU acceleration matters.

## Host Matrix

| Host         | GPU Hardware                                         | Driver / Kernel Signal           | Hardware Notes                                                                                                   |
| ------------ | ---------------------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `qbert`      | AMD discrete GPU (RX 6800 XT noted in host comments) | `amdgpu` (`hosts/qbert/gpu.nix`) | Dedicated desktop GPU; host GPU module enables AMD firmware and OpenCL support.                                  |
| `donkeykong` | Intel Arc Graphics (Lunar Lake iGPU)                 | `xe` (kernel default)            | Integrated GPU on ThinkPad T14 Gen 6; no explicit `gpu.nix`, driver handled by kernel and nixos-hardware module. |

## Source Notes

- `qbert`: `hosts/qbert/gpu.nix`
- `donkeykong`: nixos-hardware `lenovo-thinkpad-t14-intel-gen6` module; no host-level GPU config file.
