from migen import *
from migen.genlib.cdc import MultiReg
from migen.genlib.csr import AutoCSR, CSRStorage

class OrToLed(Module, AutoCSR):
    """
    Synchronize two DIO inputs to the RTIO ("rio") domain, OR them, drive an LED/TTL out.
    Exposes a 1-bit CSR 'enable' to gate the behavior at runtime.

    pad_in0: input pad record with .i
    pad_in1: input pad record with .i
    pad_led: output pad record with .o and (optionally) .oe
    """
    def __init__(self, pad_in0, pad_in1, pad_led, clkdom="rio", active_low_led=False):
        self.enable = CSRStorage(reset=1)  # bit 0 enables hardware drive

        # 1) Synchronize async inputs into RTIO clock domain
        in0_sync = Signal()
        in1_sync = Signal()
        self.specials += [
            MultiReg(pad_in0.i, in0_sync, clkdom),
            MultiReg(pad_in1.i, in1_sync, clkdom),
        ]

        # 2) Optional one-cycle register (cheap deglitch)
        in0_d = Signal()
        in1_d = Signal()
        getattr(self.sync, clkdom) += [
            in0_d.eq(in0_sync),
            in1_d.eq(in1_sync),
        ]

        # 3) OR level
        or_level = Signal()
        self.comb += or_level.eq(in0_d | in1_d)

        # 4) Gate with CSR and drive LED/TTL pad
        driven = Signal()
        self.comb += driven.eq(Mux(self.enable.storage, or_level, 0))

        if active_low_led:
            self.comb += pad_led.o.eq(~driven)
        else:
            self.comb += pad_led.o.eq(driven)

        if hasattr(pad_led, "oe"):
            self.comb += pad_led.oe.eq(1)
