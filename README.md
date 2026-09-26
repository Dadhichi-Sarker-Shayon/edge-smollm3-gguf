---
base_model: HuggingFaceTB/SmolLM3-3B-Base
tags:
- gguf
- llama.cpp
- ollama
- quantization
- smollm3
- q4_k_m
- q8_0
- text-generation
- 3b
- base-model
- wikitext-2
license: apache-2.0
pipeline_tag: text-generation
---

# SmolLM3-3B-Base Q4_K_M GGUF — verified 4GB edge build

<div align="center">

<a href="https://huggingface.co/ShayonSarker/SmolLM3-3B-Q4_K_M-GGUF"><img alt="Hugging Face" src="https://img.shields.io/badge/Hugging%20Face-FFD21E?style=for-the-badge"></a>
<a href="https://github.com/Dadhichi-Sarker-Shayon/edge-smollm3-gguf"><img alt="GitHub" src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge"></a>

<img alt="Model" src="https://img.shields.io/badge/model-SmolLM3--3B--Base-8A2BE2?style=for-the-badge">
<img alt="Published formats" src="https://img.shields.io/badge/GGUF-Q8_0%20%7C%20Q4_K_M-FFD21E?style=for-the-badge">
<img alt="Parameters" src="https://img.shields.io/badge/params-3B-00A6A6?style=for-the-badge">
<img alt="Quantizer" src="https://img.shields.io/badge/imatrix-calibrated-16A34A?style=for-the-badge">
<img alt="Peak memory" src="https://img.shields.io/badge/Q4%20RAM-~3.4GB-0069B4?style=for-the-badge">
<img alt="License" src="https://img.shields.io/badge/license-Apache--2.0-7C3AED?style=for-the-badge">

</div>

**Downloads:** [Hugging Face — ShayonSarker/SmolLM3-3B-Q4_K_M-GGUF](https://huggingface.co/ShayonSarker/SmolLM3-3B-Q4_K_M-GGUF) · **Source &amp; build recipes:** [GitHub — edge-smollm3-gguf](https://github.com/Dadhichi-Sarker-Shayon/edge-smollm3-gguf) · **Base model:** [HuggingFaceTB/SmolLM3-3B-Base](https://huggingface.co/HuggingFaceTB/SmolLM3-3B-Base)

The GGUF binaries are hosted on Hugging Face; this repository holds the reproducible conversion pipeline, calibration data, and checksums.

Base: `HuggingFaceTB/SmolLM3-3B-Base` (SmolLM3ForCausalLM, Apache-2.0) · Quant: llama.cpp `0.4.1-dev (c77ae69)` · imatrix on 4000-line wikitext-2 (seed 42, 798 chunks, 4 threads)

## Format status

| File | Status | Note |
|---|---|---|
| `smol-Q4_K_M.gguf` | Published | Main release, ~1.8 GB |
| `smol-Q8_0.gguf` | Published | ~3.1 GB |
| F16 | Reference only | 5.8 GB source-side reference used for the PPL baseline; not published |

The F16 row in the eval table below is a measurement reference, not a downloadable file.

## Eval (wikitext, 128 held-out lines, 2048 ctx)

| model | PPL | size |
|---|---|---|
| F16 | 6.3582 | 5.8 GB |
| Q8_0 | 6.3667 (+0.14%) | 3.1 GB |
| Q4_K_M | 6.5020 (**+2.26%**) | 1.8 GB |

Gate was `<5%` — passed. Task evals (ARC/HellaSwag) not run: perplexity only, stated honestly. Files: `smol-Q4_K_M.gguf`, `smol-Q8_0.gguf`, `imatrix.dat`, `calib.txt`, `REPRO.json`, `SHA256.txt` (see manifest). Full build log + repro scripts: `edge-smollm3-gguf` on GitHub.

## Verified outputs

Verbatim `smol-Q4_K_M.gguf` completions, `--temp 0 -no-cnv`, 24 new tokens, prompt form `Question: ...\nAnswer:`. The model answers, then continues with further `Question:`/`Answer:` pairs of its own invention; those are trimmed.

| Question | Model answer |
|---|---|
| What is the capital of Japan? | `Tokyo is the capital of Japan.` |
| What is the capital of Italy? | `Rome is the capital of Italy.` |
| What is the capital of Egypt? | `Cairo is the capital of Egypt. It is the largest city in Egypt and the Arab world.` |
| What is the largest ocean on Earth? | `The Pacific Ocean is the largest ocean on Earth. It covers about 30 percent of the Earth's surface` |
| Which planet is closest to the Sun? | `Mercury is the closest planet to the Sun. It is the smallest planet in the Solar System, with a diameter of` |
| How many days are in a leap year? | `366 days` |
| How many continents are there? | `There are seven continents: Asia, Africa, North America, South America, Antarctica, Europe, and Australia.` |
| What is the chemical symbol for gold? | `Au. The symbol for gold is Au, which comes from the Latin word for gold, aurum.` |

Eight of eight are correct. This is the lowest-perplexity model in this release set (6.36 F16 on wikitext vs 11.50 for Qwen3-4B), though wikitext perplexity is not a reasoning score and says nothing about multilingual or instruction behaviour.

## Use

llama.cpp:
```
./llama-cli -m smol-Q4_K_M.gguf -p "Explain overfitting in 3 lines" -c 4096
```

Ollama (see `Modelfile`):
```
ollama create smollm3-3b-base-q4 -f Modelfile
ollama run smollm3-3b-base-q4 "Explain overfitting in 3 lines"
```

4GB GTX 1650: Q4_K_M peaks ~3.4GB, fully offline.

## Limitations

- Base (non-instruct) model: raw completion, no chat tuning. Prompt accordingly.
- English wikitext calibration: quality on other languages/domains may vary.
- Perplexity-only validation; verify on your task before production use.
