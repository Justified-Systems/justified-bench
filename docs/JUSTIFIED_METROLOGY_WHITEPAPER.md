# Justified Bench: Empirical Systems Metrology for AI-Generated Runtimes

**Governance:** JUS-BRAND-v5.2.0 | JUS-TEST-v2.0.0  
**Repository:** [Justified-Systems/justified-bench](https://github.com/Justified-Systems/justified-bench)  
**Live Telemetry Ledger:** [justified-systems.com/benchmarks](https://justified-systems.com/benchmarks)  
**Author:** Justin Sweeney, Systems Architect (Justified Systems)  
**Synthetic Architecture Partner:** Google Gemini  

---

## 1. Executive Summary & Epistemic Thesis

The proliferation of code-generation large language models has introduced an engineering paradox: developers can generate tens of thousands of lines of low-level C++ and CUDA code without possessing the domain expertise to audit the resulting machine for memory leaks, mutex deadlocks, pipe stalls, or cache invalidation.

In unmanaged systems development, code review cannot verify hardware stability. A binary that compiles cleanly can still fail under real-world multi-threading contention, leak VRAM across execution boundaries, or deadlock operating system anonymous pipes.

`justified-bench` is a 10-probe empirical test harness written entirely in the **Python 3 standard library with zero external pip dependencies** (`no pytest`, `no psutil`, `no torch`, `no numpy`). It treats the compiled binary as a black-box state machine, interrogating physical silicon and operating system kernel primitives directly via:
- **Windows:** Win32 `kernel32`, `psapi`, and named mutexes via `ctypes`.
- **Linux:** POSIX `/proc`, `fcntl.flock`, and domain sockets.
- **macOS:** Darwin `sysctl` and Mach kernel abstractions.
- **Silicon Telemetry:** Bare NVML via dynamic `nvidia-smi` queries.

---

## 2. Architecture & Test Taxonomy

The harness bifurcates into two distinct 5-probe test batteries:

### Suite A: Physical Silicon & OS Transport
* **Probe 01 (Cold Boot & Working Set):** Isolates the Windows `CreateProcess()` kernel initialization floor (25–45 ms) from virtual address allocation (`MapViewOfFile`). 
* **Probe 03 (Concurrency Saturation Knee):** Dispatches a 7-step worker ladder (1 to 64 parallel threads) using `ThreadPoolExecutor`. Identifies the precise thread count where thread context switching causes latency jitter. 
* **Probe 04 (VRAM Mutex Contention):** Evaluates cross-process GPU memory isolation using named OS kernel mutexes (`Global\JustifiedVRAMAllocationMutex`). Verifies that colliding processes serialize cleanly.
* **Probe 05 (Sustained Velocity & Thermal Drift):** Measures steady-state decode velocity (`tok/s`) across repeated long-context passes to track -3% to -8% TDP thermal throttling.
* **Probe 08 (Pipe Stream Saturation):** Streams continuous data payloads across standard I/O and Named Pipes up to 32 MB to assert buffer draining without deadlocks.

### Suite B: Cognitive Agency & State Invariants
* **Probe 02 (Wire Syntax & Schema Purity):** Tests directional schema contracts. Enforces strict RFC 8259 bare JSON emission, strictly penalizing markdown-wrapped fences.
* **Probe 06 (Epistemic Parameter Void Trapping):** Injects incomplete payloads. Asserts sub-millisecond pre-tensor halts (`OPT-002 [DATA_INSUFFICIENT_HALT]`) before GPU matrix multiplication.
* **Probe 07 (In-Register Secret Redaction):** Injects 7 high-entropy credential tokens. Asserts that credentials are masked to `[REDACTED_SECRET_NULL]` directly in registers.
* **Probe 09 (Determinism & Multi-Turn Drift):** Asserts 100% bit-exact output reproducibility across 30 greedy forward passes (`temperature 0.0`). 
* **Probe 10 (Arithmetic ALU & Chronological Logic):** Evaluates quantitative business calculations and banking calendar settlement days using fixed random seeds (`SEED_VAL=42`). Targets 0.0 Mean Absolute Error (MAE).

---

## 3. The Defect & Friction Ledger (Engineering Findings)

Building this harness exposed critical low-level edge cases that conventional benchmarks ignore:
1. **Memory Sampling Race Conditions:** Early sampling attempts queried process memory immediately after spawning, inadvertently recording the C Runtime (CRT) initialization footprint (~12 MB) rather than peak model allocation. Resolved by polling `GetProcessMemoryInfo.PeakWorkingSetSize` post-execution.
2. **Win32 Named Pipe Saturation Ceilings:** Under 50+ concurrent client threads, unbuffered pipe transports hit kernel buffer limits (102 KB burst ceiling), requiring non-blocking asynchronous drain routines.
3. **OS Process Creation Drag:** On Windows 11, launching an unmanaged subprocess imposes a 25–45 ms kernel penalty. 
4. **The "Markdown Bug" Mask:** Generalist models frequently wrap structured JSON in markdown fences. `justified-bench` flags regex-extracted JSON as non-wire-pure.
5. **PowerShell WMI Query Overhead:** Querying system hardware via PowerShell WMI (`Win32_ComputerSystem`) introduces a 450 ms cold-start delay. 

---

## 4. Anti-Guarantee Statement & Epistemic Boundary

All metrics emitted by this harness reflect physical constraints under the active host operating system kernel and local semiconductor thermals. We reject blanket marketing claims of universal speed or zero-shot infallibility. Token velocity is bound to memory bus bandwidth, PCIe link generation, and chassis thermal dissipation.

---

## 5. Granular Probe Audit Specifications

Detailed engineering reviews and calibration logs for each individual probe are maintained in the repository:
- [Probe 00: Universal Metrology Master Orchestrator](audits/audit_probe_00_orchestrator.md)
- [Probe 01: Ambient Host RAM Floor & Cold Boot Ingress](audits/audit_probe_01_cold_boot.md)
- [Probe 02: Enterprise Workload Stream & Wire Purity](audits/audit_probe_02_workload_stream.md)
- [Probe 03: Process Concurrency Saturation Knee](audits/audit_probe_03_concurrency.md)
- [Probe 04: Cross-Process VRAM Mutex Contention](audits/audit_probe_04_vram_mutex.md)
- [Probe 05: Sustained Decode Velocity & Thermal Drift](audits/audit_probe_05_sustained_velocity.md)
- [Probe 06: Parameter Void Interception Lifecycle](audits/audit_probe_06_epistemic_void.md)
- [Probe 07: In-Register Sensitive Data Scrubbing](audits/audit_probe_07_swar_scrubbing.md)
- [Probe 08: OS Anonymous Pipe Saturation Scaling](audits/audit_probe_08_pipe_scaling.md)
- [Probe 09: Determinism, Semantic Drift & Stoichiometry](audits/audit_probe_09_semantic_drift.md)
- [Probe 10: Cognitive ALU & Chronological Logic](audits/audit_probe_10_cognitive_reasoning.md)
