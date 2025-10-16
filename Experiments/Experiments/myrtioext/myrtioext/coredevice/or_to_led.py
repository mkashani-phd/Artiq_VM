from artiq.coredevice.generic import GenericDevice
from artiq.language.core import kernel

class OrToLed(GenericDevice):
    """
    Minimal helper to control the 'enable' CSR bit from kernel code.
    Your device_db entry should point to this class.
    """
    def __init__(self, dmgr, name, core, csr_name="or_to_led", **kwargs):
        super().__init__(dmgr, name, core, **kwargs)
        # Device manager exposes the CSR bank as "<csr_name>_enable"
        # However, depending on ARTIQ version, CSR access helpers differ.
        # We’ll use the generic CSR endpoint available via dmgr.
        self._enable = dmgr.get(f"{csr_name}_enable")

    @kernel
    def set_enable(self, en: bool):
        self._enable.write(1 if en else 0)
