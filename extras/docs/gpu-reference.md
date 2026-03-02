# GPU Hardware Reference

Hardware-only GPU snapshot for hosts where GPU acceleration matters.

## Host Matrix

| Host | GPU Hardware | Driver / Kernel Signal | Hardware Notes |
|------|--------------|------------------------|----------------|
| `qbert` | AMD discrete GPU (RX 6800 XT noted in host comments) | `amdgpu` (`hosts/qbert/gpu.nix`) | Dedicated desktop GPU; host GPU module enables AMD firmware and OpenCL support. |
| `donkeykong` | Intel Arc Graphics 130V/140V (Lunar Lake iGPU, PCI ID `8086:64a0`) | `xe` (from `voxtype-discovery-donkeykong-20260218-170913.txt`) | Integrated GPU on ThinkPad T14 Gen 6; Discovery output confirms `/dev/dri/card0` and `renderD128`. |

## Source Notes

- `qbert`: `hosts/qbert/gpu.nix`
- `donkeykong`: `voxtype-discovery-donkeykong-20260218-170913.txt`
