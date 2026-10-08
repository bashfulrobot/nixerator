# GPU Hardware Reference

Hardware-only GPU snapshot for hosts where GPU acceleration matters.

## Host Matrix

| Host         | GPU Hardware                                         | Driver / Kernel Signal           | Hardware Notes                                                                                                   |
| ------------ | ---------------------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `qbert`      | AMD discrete GPU (RX 6800 XT noted in host comments) | `amdgpu` (`hosts/qbert/gpu.nix`) | Dedicated desktop GPU; host GPU module enables AMD firmware and OpenCL support.                                  |

## Source Notes

- `qbert`: `hosts/qbert/gpu.nix`
