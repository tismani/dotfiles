{ pkgs, lib, ... }:

let
  # Open WebUI talks to llama-swap on loopback; llama-swap itself is
  # unauthenticated, so every OpenAI-style key below is a placeholder that the
  # clients merely require to be non-empty.
  llamaSwap = "http://127.0.0.1:9292/v1";
  noKey = "none";

  gemma = "Gemma-4-26B-A4B-it-MTP-GGUF";

  # Chat-capable llama-swap routes. Keep in sync with llamaSwapConfig.models
  # in ./llm.nix. Image, speech, embedding and video routes are deliberately
  # absent: selecting one in the chat picker would send /v1/chat/completions,
  # which those Gufo servers reject. They are wired below through Open WebUI's
  # dedicated image, audio and RAG settings instead (video: ./openwebui/).
  chatModels = [
    gemma
    "Qwen3.6-35B-A3B-MTP-GGUF"
    "Qwen3.8-27B-GGUF"
    "Qwen3.8-27B-TURBO-Fable-Cold-Fusion-MTP-GGUF"
    "gufo/Qwen3.8-27B-DFlash2"
    "gufo/Qwen3.8-Flash-Next-MTP"
    "gufo/DeepSeek-V4-Flash-DSpark"
    "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF"
  ];

  imageModel = "gufo/Qwen-Image-2.1";
  # Only 1024x1024 text-to-image has been validated resident beside Gemma
  # (docs/halo-dual-model-memory.md).
  imageSize = "1024x1024";

  secretsDir = "/var/lib/open-webui-secrets";
  searxPort = 8888;
in
{
  # Generate the session-signing and SearXNG secrets once on Halo, outside Git
  # and the world-readable Nix store. Regenerating WEBUI_SECRET_KEY would log
  # everyone out and can invalidate encrypted values in webui.db, so existing
  # values are kept.
  systemd.services.open-webui-secrets = {
    description = "Create persistent Open WebUI and SearXNG secrets";
    before = [ "open-webui.service" "searx-init.service" ];
    requiredBy = [ "open-webui.service" "searx-init.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "open-webui-secrets";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
    script = ''
      writeSecret() {
        file="${secretsDir}/$1"
        if [ ! -s "$file" ]; then
          value="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          ${pkgs.coreutils}/bin/printf '%s=%s\n' "$2" "$value" > "$file.tmp"
          ${pkgs.coreutils}/bin/mv "$file.tmp" "$file"
        fi
        ${pkgs.coreutils}/bin/chmod 0600 "$file"
      }
      writeSecret open-webui.env WEBUI_SECRET_KEY
      writeSecret searx.env SEARX_SECRET_KEY
    '';
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    openFirewall = true;
    environmentFile = "${secretsDir}/open-webui.env";
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";

      # Nix is authoritative: without this, the first start copies these
      # values into webui.db and later edits here are silently ignored. The
      # trade-off is that Admin Settings changes revert on restart.
      ENABLE_PERSISTENT_CONFIG = "False";

      WEBUI_NAME = "Halo";
      WEBUI_URL = "http://10.1.3.246:8080";

      # The port is open to the LAN and Tailscale. Only the very first account
      # may self-register (and becomes admin); later users are created by the
      # admin, and anyone who still gets in waits for approval.
      ENABLE_SIGNUP = "False";
      ENABLE_INITIAL_ADMIN_SIGNUP = "True";
      DEFAULT_USER_ROLE = "pending";

      # Connection: llama-swap only. model_ids pins the picker to chat models
      # and skips the /v1/models round trip, which also lists non-chat routes.
      ENABLE_OLLAMA_API = "False";
      ENABLE_OPENAI_API = "True";
      OPENAI_API_BASE_URL = llamaSwap;
      OPENAI_API_KEY = noKey;
      OPENAI_API_CONFIGS = builtins.toJSON {
        "0" = {
          enable = true;
          connection_type = "local";
          model_ids = chatModels;
        };
      };

      # Gemma is the only chat model llama-swap keeps resident beside Qwen
      # Image (matrix set gufo-image-gemma), so it is both the default chat
      # model and the task model. Using another task model would evict the
      # image server every time a title or image prompt is generated.
      DEFAULT_MODELS = gemma;
      TASK_MODEL_EXTERNAL = gemma;
      ENABLE_TITLE_GENERATION = "True";
      ENABLE_TAGS_GENERATION = "True";
      ENABLE_FOLLOW_UP_GENERATION = "True";
      ENABLE_AUTOCOMPLETE_GENERATION = "False"; # One task request per keystroke pause.

      # Capabilities default to on when unset; listed so the native builtin
      # tools (generate_image, edit_image, search_web) are explicitly allowed.
      DEFAULT_MODEL_METADATA = builtins.toJSON {
        capabilities = {
          file_upload = true;
          web_search = true;
          image_generation = true;
          citations = true;
          usage = true;
          status_updates = true;
          builtin_tools = true;
        };
      };

      # Image generation: Qwen Image through llama-swap's /v1/images routes.
      # Gemma (the task model) rewrites the user's request into the prompt.
      ENABLE_IMAGE_GENERATION = "True";
      IMAGE_GENERATION_ENGINE = "openai";
      IMAGES_OPENAI_API_BASE_URL = llamaSwap;
      IMAGES_OPENAI_API_KEY = noKey;
      IMAGE_GENERATION_MODEL = imageModel;
      IMAGE_SIZE = imageSize;
      ENABLE_IMAGE_PROMPT_GENERATION = "True";
      # Gufo returns b64_json; only gpt-image models are assumed to return URLs.
      IMAGE_URL_RESPONSE_MODELS_REGEX_PATTERN = "^gpt-image";

      # Image editing uses Gufo's /v1/images/edits on the same server. Unlike
      # generation, editing has not been memory-validated beside Gemma.
      ENABLE_IMAGE_EDIT = "True";
      IMAGE_EDIT_ENGINE = "openai";
      IMAGES_EDIT_OPENAI_API_BASE_URL = llamaSwap;
      IMAGES_EDIT_OPENAI_API_KEY = noKey;
      IMAGE_EDIT_MODEL = imageModel;
      IMAGE_EDIT_SIZE = imageSize;

      # RAG: Qwen3 embeddings from llama-swap, BM25 + vector hybrid search,
      # then a small local CPU cross-encoder (downloaded into hf_home on first
      # use) reranks the candidates.
      RAG_EMBEDDING_ENGINE = "openai";
      RAG_OPENAI_API_BASE_URL = llamaSwap;
      RAG_OPENAI_API_KEY = noKey;
      RAG_EMBEDDING_MODEL = "Qwen3-Embedding-4B-GGUF";
      RAG_EMBEDDING_OPENAI_BATCH_SIZE = "16";
      # Qwen3-Embedding is instruction-aware on the query side only. Its card
      # separates instruction and query with a newline, which a systemd
      # Environment= value cannot carry; a space works nearly as well.
      RAG_EMBEDDING_QUERY_PREFIX = "Instruct: Given a user question, retrieve passages that answer it Query: ";
      ENABLE_RAG_HYBRID_SEARCH = "True";
      RAG_RERANKING_ENGINE = "";
      RAG_RERANKING_MODEL = "BAAI/bge-reranker-v2-m3";
      CHUNK_SIZE = "1500";
      CHUNK_OVERLAP = "150";
      RAG_TOP_K = "8";
      RAG_TOP_K_RERANKER = "4";

      # Speech through the Gufo routes. Browsers only allow microphone capture
      # in a secure context (HTTPS or localhost), so plain-HTTP LAN access can
      # play TTS but not record STT.
      AUDIO_STT_ENGINE = "openai";
      AUDIO_STT_OPENAI_API_BASE_URL = llamaSwap;
      AUDIO_STT_OPENAI_API_KEY = noKey;
      AUDIO_STT_MODEL = "gufo/Qwen3-ASR-1.7B";
      AUDIO_TTS_ENGINE = "openai";
      AUDIO_TTS_OPENAI_API_BASE_URL = llamaSwap;
      AUDIO_TTS_OPENAI_API_KEY = noKey;
      AUDIO_TTS_MODEL = "gufo/Qwen3-TTS-12Hz-1.7B-CustomVoice";
      # A built-in CustomVoice speaker (talker_config.spk_id in its config.json).
      AUDIO_TTS_VOICE = "ryan";

      # Web search through the loopback SearXNG below.
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://127.0.0.1:${toString searxPort}/search?q=<query>";
      WEB_SEARCH_RESULT_COUNT = "5";
    };
  };

  systemd.services.open-webui = {
    wants = [ "llama-swap.service" "searx.service" ];
    after = [ "open-webui-secrets.service" "llama-swap.service" "searx.service" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # SearXNG: loopback-only metasearch backing Open WebUI web search.
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    environmentFile = "${secretsDir}/searx.env";
    settings = {
      server = {
        port = searxPort;
        bind_address = "127.0.0.1";
        secret_key = "$SEARX_SECRET_KEY";
        limiter = false; # Open WebUI's automated queries would be rate-limited.
      };
      # Open WebUI consumes results as JSON, which SearXNG disables by default.
      search.formats = [ "html" "json" ];
    };
  };

  systemd.services.searx-init.after = [ "open-webui-secrets.service" ];
}
