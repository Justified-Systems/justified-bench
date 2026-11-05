# Justified Bench (10-Probe Metrology Suite)

An empirical, zero-dependency hardware metrology harness and state invariant auditor for local LLM inference engines (including `justified_engine`, `llama.cpp`, and `Ollama`).

Operates entirely in pure Python 3 standard library with **zero external pip dependencies** (banning `pytest`, `psutil`, `torch`, and `numpy`). Hardware interrogation interfaces directly with OS kernel primitives (`kernel32/psapi`, `nvidia-smi`, `/proc`, and `sysctl`).

## Architecture & Test Taxonomy

### Suite A: Physical Silicon & Transport Probes
* **Probe 01 (`probe_01_cold_boot_ram.py`):** Cold dispatch latency floor, working set RAM/VRAM baseline, and prefill scaling (25, 250, 1000 tokens).
* **Probe 03 (`probe_03_concurrency.py`):** Process concurrency saturation knee mapping across a 1-to-64 worker thread ladder.
* **Probe 04 (`probe_04_vram_mutex.py`):** Cross-process GPU allocation interlocks via named kernel mutexes (`Global\JustifiedVRAMAllocationMutex`).
* **Probe 05 (`probe_05_sublogit_bypass.py`):** Sustained autoregressive decode velocity (tok/s) and thermal throttling drift.
* **Probe 08 (`probe_08_pipe_scaling.py`):** Anonymous standard I/O and Named Pipe buffer resilience across a 4 KB to 32 MB data ladder.

### Suite B: Cognitive Agency & State Invariants
* **Probe 02 (`probe_02_workload_stream.py`):** Directional contracts and RFC 8259 bare JSON schema compliance (rejecting markdown preamble).
* **Probe 06 (`probe_06_epistemic_void.py`):** Epistemic parameter void trapping (`[DATA_INSUFFICIENT_HALT]` in < 1.0 ms) under missing parameters.
* **Probe 07 (`probe_07_swar_scrubbing.py`):** In-register sensitive credential and DLP token redaction (`[REDACTED_SECRET_NULL]`).
* **Probe 09 (`probe_09_semantic_drift_hallucination.py`):** 30-pass greedy determinism ($T=0.0$) and 30-turn contextual invariant retention.
* **Probe 10 (`probe_10_cognitive_reasoning.py`):** Multi-step arithmetic ALU execution and calendar offset verification (0.0 MAE target).

## Quickstart

Run the master metrology orchestrator against your local execution binary and model weights:

```bash
# Windows (Discrete NVIDIA CUDA):
python run_master_metrology.py --engine justified_engine.exe --model weights\qwen2.5-7b-instruct.gguf --export metrology_run.json

# Linux (POSIX CPU / CUDA):
python run_master_metrology.py --engine ./justified_engine --model ./weights/qwen2.5-7b-instruct.gguf --export metrology_run.json

# macOS (Apple Silicon Metal):
python run_master_metrology.py --engine ./justified_engine --model ./weights/qwen2.5-7b-instruct.gguf --export metrology_run.json

License

MIT License. Built and maintained by Justified Systems (https://justified-systems.com).
