# Halo dual-model memory evaluation

Measurement date: 2026-09-22. This was a read-only runtime evaluation; no Nix
configuration was activated and no checked-in configuration was changed.

## Observed platform

- 134,309,466,112 bytes system RAM (124.2 GiB); baseline available RAM was
  about 95.9 GB.
- Strix Halo `gfx1151`, 512 MiB physical VRAM, and 117,760 MiB configured GTT
  (the kernel reports 123,480,309,760 bytes).
- Baseline GTT use was about 31.8 GB. Swap was 9.4 GB and unused.
- The host ended with only the managed Gemma llama-server resident; no test
  processes remained. No kernel OOM, ROCm fault, or allocation error occurred.

## Single-model results

Each model received a short completion after loading with one 262,144-token
slot, Q8 K/V caches, full ROCm offload, Flash Attention, and its configured
projector/draft settings. GTT is the llama-server process's steady-state
allocation, rounded to GiB. It includes weights, projector/draft buffers, KV
allocation, and llama.cpp overhead; it is therefore more useful than adding
GGUF file sizes alone.

| Model | Primary GGUF | Projector / external draft | Measured process GTT |
|---|---:|---:|---:|
| Qwen3.6 | 22.85 GB | 0.90 GB projector; embedded MTP | ~27.1 GiB |
| Qwen3.8 | 17.56 GB | 0.93 GB projector; embedded MTP | ~29.4 GiB |
| Nemotron | 25.51 GB | embedded MTP; no projector | ~26.4 GiB |
| Gemma 4 | 16.95 GB | 1.19 GB projector + 0.46 GB external MTP | ~23.6 GiB |

The deployed Nemotron route still uses a 1,048,576-token context. It was also
loaded separately at 262,144 tokens for this comparison; that test loaded and
served successfully. The other three routes already used 262,144.

The measured values do not expose a trustworthy independent KV number: llama.cpp
allocates shared and model-specific buffers, and its process GTT counter
includes allocator granularity and runtime graphs. The residual after subtracting
the visible GGUF components is the combined KV/projector/draft/runtime cost,
not KV alone. Treating that residual as pure KV would understate peak memory.

## Pair comparison

The table uses the measured 262K process allocations for the four GGUF models.
The peak estimate is their sum plus approximately 8 GiB for the host's observed
GTT baseline. The conservative budget is 87 GiB: 112 GiB configured GTT less a
25 GiB reserve for NixOS/GNOME, Lemonade, llama-swap, Podman, and allocator
headroom. “Margin” is budget minus peak estimate.

| Pair | Weights only | Estimated peak GTT | Conservative margin | Assessment |
|---|---:|---:|---:|---|
| Qwen3.6 + Qwen3.8 | 40.41 GB | ~64.4 GiB | ~22.6 GiB | safest tested pair |
| Qwen3.6 + Nemotron | 48.36 GB | ~61.5 GiB | ~25.5 GiB | safe by estimate |
| Qwen3.6 + Gemma 4 | 39.80 GB | ~58.7 GiB | ~28.3 GiB | safest by estimate |
| Qwen3.8 + Nemotron | 43.07 GB | ~63.8 GiB | ~23.2 GiB | safe by estimate |
| Qwen3.8 + Gemma 4 | 34.51 GB | ~61.0 GiB | ~26.0 GiB | safe by estimate |
| Nemotron + Gemma 4 | 42.45 GB | ~58.0 GiB | ~29.0 GiB | safest by estimate |
| Qwen3.6 + Halogen | 22.85 GB + 68.0 GiB locked | not safe at defaults | not safe at defaults | do not claim |
| Qwen3.8 + Halogen | 17.56 GB + 68.0 GiB locked | not safe at defaults | not safe at defaults | do not claim |
| Nemotron + Halogen | 25.51 GB + 68.0 GiB locked | not safe at defaults | not safe at defaults | do not claim |
| Gemma 4 + Halogen | 16.95 GB + 68.0 GiB locked | ~50.3 GiB GTT reduced | ~2.6 GiB contiguous RAM | experimental only |

Halogen is separate from the GGUF measurements. Its Podman image is 3.55 GB
and the model directory is 123 GB. The exact production command failed alongside
Gemma: it pinned 68.0 GiB of weights, requested a 524,288-position pool, and
hit HIP/device OOM after 22.4 GiB of allocations. It also caused about 111 MiB
of swap use. Therefore the default Halogen route cannot be treated as a
concurrent pair.

For diagnosis, the same container was run with
`HALOGEN_KV_POOL_POSITIONS=262144` and `HALOGEN_MAX_TOK=16384`. It loaded
successfully, reported 68.0 GiB weights + 7.2 GiB KV + 12.5 GiB working memory
(87.7 GiB total), and returned `OK` beside Gemma. GTT was 50.3 GiB combined,
but only 2.6 GiB of contiguous host memory remained and Halogen warned that
long prompts could page or stall. This reduced setting is useful for further
experiments, not a safe production recommendation.

## Concurrent validation

Two temporary direct llama-server processes were started together with Qwen3.6
and Qwen3.8, each at 262K and with the production Q8/MTP/projector arguments.
Both became healthy, both returned a completion, and their logs showed clean
MTP acceptance. The three-server observation (the managed Gemma plus the two
temporary servers) used about 80.1 GiB total GTT; the two temporary processes
accounted for approximately 27.1 and 29.4 GiB. The temporary processes were
stopped afterward.

## Recommendation and follow-up

The conservative choice is to permit one two-model GGUF group at a time, with
Qwen3.6 + Qwen3.8 the best usefulness/safety compromise and Gemma + Nemotron
the lowest estimated footprint. Do not advertise Halogen concurrency until its
container is measured in the same way.

If concurrency is desired, the next configuration change should split
`large-gguf` into explicit non-exclusive groups and set every GGUF
`capabilities.context` to `262144`. That change should be made only after
deciding which measured pair is supported; it should not imply that all ten
pairs, or any pair including Halogen, are supported. Rebuild both hosts as
appropriate, but do not activate from this evaluation.
