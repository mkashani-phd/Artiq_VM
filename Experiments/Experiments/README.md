# myrtioext wrapper

This repo contains:
- A *wrapper* `flake.nix` at the project root that builds your ARTIQ-Zynq SD image.
- A Python package `myrtioext` (under `Experiments/myrtioext`) that provides `OrToLed` gateware.

## Layout
```
Experiments/
  myrtioext/
    pyproject.toml
    myrtioext/
      __init__.py
      gateware/
        __init__.py
        or_to_led.py
      coredevice/
        __init__.py
        or_to_led.py
flake.nix
```

## How to use

1) **Import and instantiate in your local `kasli_soc.py`:**
```python
from myrtioext.gateware.or_to_led import OrToLed

# EEM0: i0..i3 inputs, o4..o7 outputs
dio0 = self.platform.request("dio", 0)   # use 1 if your platform is 1-based
pad_in0 = dio0.i0
pad_in1 = dio0.i1
pad_led = dio0.o4

self.submodules.or_to_led = OrToLed(
    pad_in0=pad_in0, pad_in1=pad_in1, pad_led=pad_led,
    clkdom="rio", active_low_led=False
)
self.add_csr("or_to_led")  # optional
```

2) **Edit the JSON path inside `flake.nix`** to your kasli-soc JSON.

3) **Build:**
```bash
nix build .#sd --print-build-logs --impure
```

> If the build cannot import `myrtioext` during synthesis, we can wrap the Python env
> or export `PYTHONPATH` to include the built package site-packages.
