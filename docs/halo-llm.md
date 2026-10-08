# Halo LLM gateway

llama-swap is Halo's OpenAI-compatible API at `http://halo:9292/v1`. It loads
the configured backends on demand and is reachable over the LAN and Tailscale.
Lemonade remains directly reachable on port 13305 for NPU/TTS maintenance.
MiniMax H3 is the one exception to the `/v1` prefix: llama-swap v249 reaches
its video API through `/upstream/minimax-h3/v1`.

LiteLLM does **not** run on Halo. A Docker container on a separate machine reads
the repository's [`litellm-config.yaml`](../litellm-config.yaml), listens on
port 4000 there, and forwards model requests over the LAN to llama-swap at
`http://10.1.3.246:9292/v1`. OMP also connects directly to llama-swap rather
than through LiteLLM.

## Registered models

| Model ID | Backend / API | Context | Input → output | Speculation |
| --- | --- | ---: | --- | --- |
| `Qwen3.6-35B-A3B-MTP-GGUF` | llama.cpp chat | 1,010,000 | text/image → text | embedded MTP, 2 tokens |
| `Qwen3.8-27B-GGUF` | llama.cpp chat | 1,000,000 | text/image → text | embedded MTP, 3 tokens |
| `Qwen3.8-27B-TURBO-Fable-Cold-Fusion-MTP-GGUF` | llama.cpp chat | 262,144 | text/image → text | embedded MTP, 2 tokens |
| `gufo/Qwen3.8-27B-DFlash2` | Gufo chat | 262,144 | text/image → text | adaptive DFlash2 |
| `gufo/Qwen3.8-Flash-Next-MTP` | Gufo chat | 131,072 | text/image → text | adaptive MTP |
| `gufo/DeepSeek-V4-Flash-DSpark` | Gufo chat | 262,144 | text → text | DSpark |
| `gufo/Qwen3-ASR-1.7B` | Gufo transcription | 1,024/chunk | audio → text | — |
| `gufo/Qwen3-TTS-12Hz-1.7B-Base` | Gufo speech | 4,096 | text/reference audio → audio | — |
| `gufo/Qwen3-TTS-12Hz-1.7B-CustomVoice` | Gufo speech | 4,096 | text → audio | — |
| `gufo/Qwen3-TTS-12Hz-1.7B-VoiceDesign` | Gufo speech | 4,096 | text → audio | — |
| `gufo/Qwen-Image-2.1` | Gufo images | 16,384 encoder tokens | text/image → image | — |
| `FLUX.2-dev` | stable-diffusion.cpp (Vulkan) images | 512 encoder tokens | text → image | — |
| `minimax-h3` (`gufo/MiniMax-H3` in LiteLLM) | Gufo video | 4,096 prompt tokens | text → video | — |
| `NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF` | llama.cpp chat | 1,048,576 | text → text | embedded MTP, 3 tokens |
| `Gemma-4-26B-A4B-it-MTP-GGUF` | llama.cpp chat | 262,144 | text/image → text | external MTP, 3 tokens |
| `Qwen3-Embedding-4B-GGUF` | llama.cpp embeddings | 4 × 8,192 | text → 2,560-d vector | — |

The llama.cpp Qwen models use static factor-4 YaRN from a 262,144-token
original context. The configured contexts are publisher ceilings, not claims
about retrieval quality at the end of those windows. Gufo uses Qwen3.8's native
262,144-token context, one preallocated request session, and the same default
sampler as llama.cpp: temperature 0.8, top-k 40, top-p 0.95, and min-p 0.05.
The Qwen3.8 DFlash2 comparison route explicitly defaults thinking off; a client
can enable it with `reasoning_effort` on an individual request. Flash-Next is
left at Gufo's model-template default: thinking on, `xhigh` effort, and prior
reasoning preserved. DeepSeek is likewise left at its template default.

See the [pinned Gufo model guides](https://github.com/gufo-org/gufo/tree/982bffea86fd5568759a420c4808c5b2123161c8/docs/models),
[pinned Gufo server contract](https://github.com/gufo-org/gufo/blob/982bffea86fd5568759a420c4808c5b2123161c8/docs/SERVER.md),
[Qwen3.6 model card](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF),
[Qwen3.8 model card](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF),
[Qwen3.8 TURBO model card](https://huggingface.co/DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF),
[Nemotron model card](https://huggingface.co/unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF),
and [Gemma 4 model card](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF).

## Residency

llama-swap's matrix router gives every Gufo route except Qwen Image its own
singleton residency set. Qwen Image may remain resident only with Gemma 4;
loading any other Gufo route evicts both. Likewise, requesting any llama.cpp
backend other than Gemma while Qwen Image is resident stops Qwen Image first.

The Gemma 4 + Qwen Image pair was validated with `1024x1024` text-to-image
generation. It peaked at 55.16 GiB total GTT, left at least 63.65 GiB of host
memory available, did not grow swap, and left Gemma responsive. This is not a
memory-safety claim for larger images or image editing; validate those workloads
separately before expanding the supported boundary. See
[`halo-dual-model-memory.md`](halo-dual-model-memory.md) for the measurements.

The `Qwen3-Embedding-4B-GGUF` embedder, which backs Open WebUI's RAG, is
ANDed into every set except DeepSeek and MiniMax H3. It may therefore stay
resident (about 4.3 GiB of Q8 weights plus a small KV cache) beside any chat,
image, or speech workload, and it is evicted only when one of those two large
routes loads. It is never preloaded. The Gemma + Qwen Image measurement above
was taken before the embedder existed.

`FLUX.2-dev` (served by stable-diffusion.cpp's `sd-server`) has its own set,
`f2 & e`: its Q8 transformer and Q8 Mistral text encoder are about 57 GiB
before compute buffers, too large to sit beside Gemma within the pair budget,
so requesting it evicts every chat model. Measured on
Vulkan at `1024x1024`: weights load on the first request (about 8 s), GTT
peaked at about 51 GiB, and sampling ran at about 32.7 s per step. 50 steps
took 1,645 s, so the server defaults to 28 steps (about 15 minutes per image),
which stays under the 1,800 s LiteLLM timeout. Lower resolutions are
proportionally faster. It uses sd.cpp's
Vulkan build: the ROCm build crashes on the first request when most of GTT is
free (see the comment in `hosts/halo/llm.nix`).

The five llama.cpp models may run alone or in any of these ten pairs:

- Qwen3.6 + Qwen3.8
- Qwen3.6 + Nemotron
- Qwen3.6 + Gemma
- Qwen3.8 + Nemotron
- Qwen3.8 + Gemma
- Nemotron + Gemma
- Qwen3.8 TURBO + Qwen3.6
- Qwen3.8 TURBO + Qwen3.8
- Qwen3.8 TURBO + Nemotron
- Qwen3.8 TURBO + Gemma

Qwen3.8 TURBO measured 29.6 GiB of GTT alone (Q4_K_M, 262,144 context,
projector and MTP loaded), about the same as stock Qwen3.8's ~29.4 GiB. Its
largest pair, with Nemotron, is therefore ~64 GiB estimated peak against the
87 GiB budget in `halo-dual-model-memory.md`. The pairs themselves are
estimates and have not been measured.

Requesting a third llama.cpp model evicts one member of the current pair. The
matrix uses equal default eviction costs, so ties follow pair definition order
rather than a model-specific preference. The 30-minute health-check timeout
allows for direct-I/O loading and large KV allocations.

## Model ownership and runtime prerequisites

Lemonade remains enabled on `0.0.0.0:13305` for model maintenance. Before
llama-swap starts, its systemd unit waits for `lemond` and runs `lemonade
unload`, ensuring Lemonade does not retain a model in system/GPU memory. Do not
run `lemonade load` while a llama-swap backend is resident. After an interactive
Lemonade test, return ownership with:

```sh
lemonade unload
sudo systemctl restart llama-swap
```

Gufo's flake input deliberately keeps its own pinned nixpkgs/ROCm toolchain.
Halo must provide the existing gfx1151 AMDGPU/ROCm setup, `/dev/kfd` and
`/dev/dri` access, and membership in the `video` and `render` groups. The
llama-swap unit already supplies those supplementary groups and the unlimited
memlock setting. After activation, `gufo diagnose` checks the effective driver,
device, group, and runtime state.

All model paths in `hosts/halo/llm.nix` are runtime paths into mani's Hugging
Face cache. Weights are not copied into the Nix store. Cache updates can create
new snapshot directories; if a pinned snapshot is removed, update the runtime
path deliberately rather than relying on a moving symlink.

## Download every Gufo runtime model

Run these as `mani` on Halo. They use Hugging Face's normal cache layout,
which is exactly what `hosts/halo/llm.nix` references; do not use `--local-dir`.
The commits are immutable. Gufo's TTS guide does not pin commits, so the three
TTS commands pin the repository heads selected when this configuration was
written.

These downloads are large. DeepSeek's target alone is 80.76 GiB, Qwen Image is
about 33.1 GB, and MiniMax H3 is also substantial. MiniMax H3 is gated: accept
its license on Hugging Face and run `hf auth login` before its command. Qwen
Image uses the separate, non-commercial Qwen Research License.

### Qwen3.8 27B TURBO (DavidAU fine-tune)

```sh
hf download DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF \
  Qwen3.8-27B-TurboFCFusion-735-882-Here-Uncen-NEO-CODER-MAX-MTP-Q4_K_M.gguf mmproj-F16.gguf \
  --revision ceb55042229d17dcf45df52ad84698339e63d4c5
```

### Qwen3.8 27B target, vision projector, and DFlash2 sidecar

```sh
hf download unsloth/Qwen3.8-27B-GGUF \
  --revision 4ca720788d1e01f1bff70c033e0d0028fd02e502 \
  --include Qwen3.8-27B-UD-Q4_K_XL.gguf mmproj-BF16.gguf

hf download z-lab/Qwen3.8-27B-DFlash2-GGUF \
  Qwen3.8-27B-DFlash2-Q4_K_M.gguf \
  --revision 2d9571f8ce46e151f61c6499c99dee6079e1d610
```

The existing `mmproj-F16.gguf` is still used by llama.cpp and remains
untouched.

### Qwen3.8 Flash-Next target shards, vision projector, and MTP sidecar

```sh
hf download unsloth/Qwen3.8-Flash-Next-GGUF \
  --revision 38bb39ee97821de2c9009abb7e93950eec396e66 \
  --include 'UD-Q4_K_XL/*'

hf download unsloth/Qwen3.8-Flash-Next-GGUF \
  MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf \
  mmproj-BF16.gguf \
  --revision 38bb39ee97821de2c9009abb7e93950eec396e66
```

Gufo is given shard 1; it discovers the remaining three target shards. The
BF16 projector and shared-Q8 MTP predictor are required by this configured
vision/speculative route. Keep the shard download separate: current `hf`
versions ignore `--include` whenever explicit filenames are also supplied.

### DeepSeek V4 Flash target and DSpark sidecar

The target and DSpark files are two snapshots of the same Hugging Face
repository, which is why they use separate commands and revisions:

```sh
hf download antirez/deepseek-v4-gguf \
  DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf \
  --revision 1cd7b564460821938add0475a60b942c409295e0

hf download antirez/deepseek-v4-gguf \
  DeepSeek-V4-Flash-DSpark-support-0731.gguf \
  --revision e7f04037032990db0346398d249baf9fb9df1ccc
```

### Qwen3 ASR and all supported Qwen3 TTS variants

Gufo supports ASR 1.7B and the 12 Hz TTS 1.7B Base, CustomVoice, and
VoiceDesign checkpoints. It does not support the 0.6B, 25 Hz, or audio-GGUF
variants.

```sh
hf download Qwen/Qwen3-ASR-1.7B \
  --revision 7278e1e70fe206f11671096ffdd38061171dd6e5

hf download Qwen/Qwen3-TTS-12Hz-1.7B-Base \
  --revision fd4b254389122332181a7c3db7f27e918eec64e3

hf download Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice \
  --revision 0c0e3051f131929182e2c023b9537f8b1c68adfe

hf download Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign \
  --revision 5ecdb67327fd37bb2e042aab12ff7391903235d3
```

The Base route accepts reference audio and transcript per request. To register
persistent named voices instead, add matching `--voice`, `--voice-text`, and
optionally `--voice-lang` arguments to that route; those operator-owned voice
files are not model sidecars.

### Qwen Image 2.1

```sh
hf download Qwen/Qwen-Image-2.1 \
  --revision b3179ad355be050328e483a9dfdd9e60cd62adfa
```

### FLUX.2 [dev]

The official `black-forest-labs/FLUX.2-dev` repo is gated and ships bf16
weights too large for halo. These are the GGUFs and VAE that sd.cpp's FLUX.2
docs point to; the VAE copy in Comfy-Org's repo is ungated. FLUX.2 [dev] is
under the non-commercial FLUX [dev] license.

```sh
hf download city96/FLUX.2-dev-gguf flux2-dev-Q8_0.gguf \
  --revision ade5d688ddab0d9cf4a5b01bf4321e01c115020d

hf download unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF \
  Mistral-Small-3.2-24B-Instruct-2506-Q8_0.gguf \
  --revision b750ec2299225e492f1bd27cab88a0a595fa848f

hf download Comfy-Org/flux2-dev split_files/vae/flux2-vae.safetensors \
  --revision ed33133cd56476eac818c0943b6f9419b3e4a3a1
```

### MiniMax H3 FL2VA

```sh
hf download MiniMaxAI/MiniMax-H3 \
  --revision 42ed227ee7df40d41602854ae760620d6eb651fe \
  --include LICENSE README.md model_index.json 'FL2VA/**'
```

Gufo validates H3's pinned inventory before allocating the device. Its video
jobs live under `/var/lib/llama-swap/gufo-h3-jobs` and expire one hour after
completion.

### Verify cached snapshots

This checks that each expected immutable snapshot exists and that the GGUF
sidecars are present. `hf download` itself validates downloaded blob hashes.

```sh
cache="$HOME/.cache/huggingface/hub"

test -f "$cache/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_XL.gguf"
test -f "$cache/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/mmproj-BF16.gguf"
test -f "$cache/models--z-lab--Qwen3.8-27B-DFlash2-GGUF/snapshots/2d9571f8ce46e151f61c6499c99dee6079e1d610/Qwen3.8-27B-DFlash2-Q4_K_M.gguf"
test -f "$cache/models--unsloth--Qwen3.8-Flash-Next-GGUF/snapshots/38bb39ee97821de2c9009abb7e93950eec396e66/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00004-of-00004.gguf"
test -f "$cache/models--unsloth--Qwen3.8-Flash-Next-GGUF/snapshots/38bb39ee97821de2c9009abb7e93950eec396e66/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf"
test -f "$cache/models--antirez--deepseek-v4-gguf/snapshots/1cd7b564460821938add0475a60b942c409295e0/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf"
test -f "$cache/models--antirez--deepseek-v4-gguf/snapshots/e7f04037032990db0346398d249baf9fb9df1ccc/DeepSeek-V4-Flash-DSpark-support-0731.gguf"
test -f "$cache/models--Qwen--Qwen3-ASR-1.7B/snapshots/7278e1e70fe206f11671096ffdd38061171dd6e5/config.json"
test -f "$cache/models--Qwen--Qwen3-TTS-12Hz-1.7B-Base/snapshots/fd4b254389122332181a7c3db7f27e918eec64e3/config.json"
test -f "$cache/models--Qwen--Qwen3-TTS-12Hz-1.7B-CustomVoice/snapshots/0c0e3051f131929182e2c023b9537f8b1c68adfe/config.json"
test -f "$cache/models--Qwen--Qwen3-TTS-12Hz-1.7B-VoiceDesign/snapshots/5ecdb67327fd37bb2e042aab12ff7391903235d3/config.json"
test -f "$cache/models--Qwen--Qwen-Image-2.1/snapshots/b3179ad355be050328e483a9dfdd9e60cd62adfa/model_index.json"
test -f "$cache/models--MiniMaxAI--MiniMax-H3/snapshots/42ed227ee7df40d41602854ae760620d6eb651fe/model_index.json"
test -f "$cache/models--city96--FLUX.2-dev-gguf/snapshots/ade5d688ddab0d9cf4a5b01bf4321e01c115020d/flux2-dev-Q8_0.gguf"
test -f "$cache/models--unsloth--Mistral-Small-3.2-24B-Instruct-2506-GGUF/snapshots/b750ec2299225e492f1bd27cab88a0a595fa848f/Mistral-Small-3.2-24B-Instruct-2506-Q8_0.gguf"
test -f "$cache/models--Comfy-Org--flux2-dev/snapshots/ed33133cd56476eac818c0943b6f9419b3e4a3a1/split_files/vae/flux2-vae.safetensors"
test -f "$cache/models--DavidAU--Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF/snapshots/ceb55042229d17dcf45df52ad84698339e63d4c5/Qwen3.8-27B-TurboFCFusion-735-882-Here-Uncen-NEO-CODER-MAX-MTP-Q4_K_M.gguf"
echo 'All snapshots are present.'
```

The Gemma projector and external MTP draft are cached at revision
`c099eb48e663fd284577b04978a94ffccb261841`. If its primary is missing, download
it before rebuilding:

```sh
hf download unsloth/gemma-4-26B-A4B-it-GGUF \
  gemma-4-26B-A4B-it-UD-Q4_K_M.gguf \
  --revision c099eb48e663fd284577b04978a94ffccb261841
```

## Deploy Halo

First verify the configuration without activation:

```sh
nix build .#nixosConfigurations.halo.config.system.build.toplevel
```

After the runtime assets are present, activate only when a Halo deployment is
intended:

```sh
sudo nixos-rebuild switch --flake ~/dotfiles#halo
systemctl status lemond llama-swap --no-pager
lemonade status --json
gufo diagnose
```

Lemonade's status must show no loaded model after llama-swap starts.

## Verify the generated configuration

Inspect the effective unit and generated YAML rather than only the source Nix:

```sh
systemctl cat llama-swap
config=$(systemctl show llama-swap -p ExecStart --value \
  | sed -n 's/.*--config \([^ ;]*\).*/\1/p')
sudo cat "$config"
```

For every Gufo route, confirm the generated command contains the Nix-store
Gufo executable, llama-swap's `${PORT}` substitution, and the pinned snapshot
path. Check the DFlash2, MTP, and DSpark sidecar flags on their respective text
routes; the BF16 projectors on both vision LLMs; the modality-specific
`asr`/`tts`/`image`/`video` subcommand; and H3's writable job root. Confirm all
Gufo models use `/ready`. Confirm Qwen Image's matrix set is `ui & g` and every
other Gufo route still has a distinct singleton set.

Confirm the catalog includes all routes:

```sh
curl --fail --silent http://127.0.0.1:9292/v1/models \
  | jq -r '.data[].id' | sort
```

Expected output:

```text
FLUX.2-dev
Gemma-4-26B-A4B-it-MTP-GGUF
NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF
Qwen3-Embedding-4B-GGUF
Qwen3.6-35B-A3B-MTP-GGUF
Qwen3.8-27B-GGUF
Qwen3.8-27B-TURBO-Fable-Cold-Fusion-MTP-GGUF
gufo/DeepSeek-V4-Flash-DSpark
gufo/Qwen-Image-2.1
gufo/Qwen3-ASR-1.7B
gufo/Qwen3-TTS-12Hz-1.7B-Base
gufo/Qwen3-TTS-12Hz-1.7B-CustomVoice
gufo/Qwen3-TTS-12Hz-1.7B-VoiceDesign
gufo/Qwen3.8-27B-DFlash2
gufo/Qwen3.8-Flash-Next-MTP
minimax-h3
```

Exercise Gufo text and streaming requests directly through llama-swap:

```sh
curl --fail --silent http://127.0.0.1:9292/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"gufo/Qwen3.8-27B-DFlash2","messages":[{"role":"user","content":"Reply with OK."}],"max_tokens":8}' \
  | jq -r '.choices[0].message.content'

curl --fail --no-buffer http://127.0.0.1:9292/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"gufo/Qwen3.8-27B-DFlash2","messages":[{"role":"user","content":"Count from one to five."}],"max_tokens":32,"stream":true}'
```

For tools, send a declared function with `tool_choice: required`; for vision,
send an OpenAI content array containing a base64 `image_url` and a text part.
Test a non-off `reasoning_effort` separately to confirm the request overrides
the server's thinking-off default.

Exercise the other API families through llama-swap. Replace sample file names
and TTS voice controls with values valid for the checkpoint:

```sh
# ASR
curl --fail --silent http://127.0.0.1:9292/v1/audio/transcriptions \
  -F file=@speech.wav -F model=gufo/Qwen3-ASR-1.7B

# TTS Base with a per-request clone reference
curl --fail --silent http://127.0.0.1:9292/v1/audio/speech \
  -H 'Content-Type: application/json' \
  -d '{"model":"gufo/Qwen3-TTS-12Hz-1.7B-Base","voice":"voice-clone","input":"Hello from Gufo.","reference_audio":"<base64 WAV>","reference_text":"Reference transcript."}' \
  --output speech.wav

# Image generation
curl --fail --silent http://127.0.0.1:9292/v1/images/generations \
  -H 'Content-Type: application/json' \
  -d '{"model":"gufo/Qwen-Image-2.1","prompt":"A red ceramic teapot on a wooden table","size":"1024x1024","seed":42}' \
  > image.json

# FLUX.2 [dev] image generation (stable-diffusion.cpp)
curl --fail --silent http://127.0.0.1:9292/v1/images/generations \
  -H 'Content-Type: application/json' \
  -d '{"model":"FLUX.2-dev","prompt":"A red ceramic teapot on a wooden table","size":"1024x1024"}' \
  > flux2.json

# H3: llama-swap v249 requires its generic upstream path for video.
curl --fail --silent http://127.0.0.1:9292/upstream/minimax-h3/v1/videos \
  -H 'Content-Type: application/json' \
  -d '{"model":"minimax-h3","prompt":"A red fox walking through snow","size":"512x512","seconds":5,"gufo":{"seed":42}}'
```

The H3 creation response contains a job ID. Poll and download it through the
same `/upstream/minimax-h3/v1/videos/<id>` and
`/upstream/minimax-h3/v1/videos/<id>/content` prefix.

Follow logs while testing and confirm model readiness, 262,144 context, the
BF16 projector, DFlash2 proposals/acceptance, and adaptive draft behavior:

```sh
journalctl -fu llama-swap
journalctl -u llama-swap -b \
  | rg -i 'gufo|dflash|draft|accept|context|mmproj|memory|error|fail'
```

Switch among several Gufo routes and `Qwen3.8-27B-GGUF`. After each request,
inspect the process list and verify only the selected residency set remains:

```sh
pgrep -af 'gufo|llama-server'
```

An allocation failure is a deployment failure. Do not silently lower the
declared context; investigate memory availability or change the advertised
contract explicitly.

## Redeploy the remote LiteLLM container

[`litellm-config.yaml`](../litellm-config.yaml) defines chat, transcription,
speech, image, and video aliases for every Gufo route. They forward to Halo at
`http://10.1.3.246:9292/v1`; the text routes permit `reasoning_effort` but do
not forward unsupported `reasoning_format`. MiniMax is exposed externally as
`gufo/MiniMax-H3` and uses llama-swap's
`/upstream/minimax-h3/v1` base because llama-swap v249 has no first-class video
route.

After deploying Halo, git-pull this repository on the LiteLLM host and redeploy
that host's existing container so it reloads the YAML. Do not open port 4000 on
Halo; the port belongs to the remote container. Then query that container's
catalog and send a completion using its existing `LITELLM_MASTER_KEY`:

```sh
curl --fail --silent http://<litellm-host>:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  | jq -r '.data[].id' | sort

curl --fail --silent http://<litellm-host>:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gufo/Qwen3.8-27B-DFlash2","messages":[{"role":"user","content":"Reply with OK."}],"max_tokens":8}' \
  | jq -r '.choices[0].message.content'
```

### Open WebUI

Open WebUI runs on Halo itself and talks to llama-swap directly, not through
LiteLLM. Its chat, image, video, embedding, speech, and web-search wiring is
described in [`openwebui.md`](openwebui.md).

Both Halo upstream ports are unauthenticated. Restrict them at the network
layer if the connected network is not trusted. LiteLLM requires its configured
master key, but traffic is plain HTTP; use a trusted LAN or encrypted overlay.
