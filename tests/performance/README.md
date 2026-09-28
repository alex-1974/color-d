# Production performance audit probes

These focused programs are repository-level performance and numerical canaries
used by `.github/workflows/performance-audit.yml`.

They are intentionally separate from the historical research tree. The files
promoted here are exact source copies of the corresponding validated probes
under `experiments/performance_release_gate/` so moving the CI dependency does
not change the measured workload or code shape.

The historical experiment directory remains the evidence record for how the
probes were designed, what alternatives were measured, and why the current
production paths were accepted. It must remain intact until the external
research migration tracked by issue #107 is independently verified.

Changes to these production probes should be made only when the corresponding
public implementation, performance contract, or supported toolchain changes
and the revised workload is justified.
