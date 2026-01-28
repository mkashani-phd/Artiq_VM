import numpy as np

from system.iquist_ions.system import IQUISTIonsSystem
from system.iquist_ions.services.entangler import EntanglerService


class TestEntanglerService(
                       EntanglerService,
                       IQUISTIonsSystem, EnvExperiment):
    """Test of Entangler Service"""

    def _build(self):
        self._build_add_entangler()

        self.setattr_argument("entangler_sequence_file",  # override entangler service arg with default arg
                              StringValue(default='test_sequence.json'), "Entangler settings")
        self.setattr_argument("entangler_iterations",
                              NumberValue(int(1e3), ndecimals=0, step=100), "Entangler settings")

    def _prepare(self):
        self._prepare_add_entangler()

        self.underflow_counter = 0
        self.total_cycles = 0
        self.t_runtime = 0.0

    @kernel
    def run(self):
        self.core.reset()
        delay(40 * ms)

        # Run simple entangler sequence
        t_run_start = now_mu()

        self.init_entangler()
        for i in range(self.entangler_iterations):
            try:
                delay_mu(100000)
                self.setup_entangler()
                self.run_entangler()
                self.total_cycles += self.entangler_max_cycles
            except RTIOUnderflow:
                self.core.wait_until_mu(now_mu())
                delay_mu(5000000)
                self.total_cycles += self.entangler.get_ncycles()
                self.underflow_counter += 1
                delay_mu(5000000)
                continue

        t_run_end = now_mu()
        self.t_runtime = float(t_run_end - t_run_start) / 1e9

    def analyze(self):
        print(f"Underflow counter: {self.underflow_counter}")
        print(f"Total cycles ran: {float(self.total_cycles) / 1e6} million:")
        print(f"Runtime: {self.t_runtime} s")


