# Full Roadmap - SmolLM3-3B Verified GGUF for 4GB (14 days, Kaggle Free + GTX 1650)

## Day 1 - Prep (1 hour, local + web)
1. Create empty GitHub repo: `edge-smollm3-gguf`
2. Create empty HF repo: `YOURNAME/SmolLM3-3B-Q4_K_M-GGUF` (private first)
3. Open Kaggle: new notebook, GPU T4, Internet ON
4. Copy `quant.sh` and `eval.sh` from this folder into Kaggle
Result: repos links ready, no code yet.

## Day 2-3 - Quant on Kaggle (3-4 hours GPU)
Run `quant.sh`:
- downloads HuggingFaceTB/SmolLM3-3B
- convert to F16 GGUF
- builds calib.txt (wikitext 2000 lines)
- builds imatrix.dat
- outputs smol-Q4_K_M.gguf (~2GB) + smol-Q8_0.gguf (~3.2GB)
Save to Kaggle Output. Download Q4 to local: `G:\My Drive\ollama models\general\`
Pass: both files exist, `ls -lh` shows sizes.

## Day 4-5 - Eval on Kaggle (2-3 hours)
Run `eval.sh`:
- llama-perplexity F16 vs Q4 vs Q8 on same 128 chunks
- lm_eval arc_challenge + hellaswag on base (subset to fit free tier)
Fill eval-table.md. Pass bar: Q4 ppl rise <3%, arc drop <2pts. If worse, redo calib with +code mix. Be honest in card.

## Day 6-7 - Local proof on GTX 1650 4GB (2 hours)
PowerShell:
```
.\llama-bench.exe -m "G:\My Drive\ollama models\general\smol-Q4_K_M.gguf" -p 512 -n 128 > bench-1650.log
nvidia-smi -l 1  # note peak MB in second window
ollama create smollm3-3b-q4 -f "G:\My Drive\open source mine\edge-smollm3-gguf\Modelfile"
ollama run smollm3-3b-q4 "Explain overfitting in 3 lines"
```
Result: bench-1650.log + screenshot, Ollama runs offline.

## Day 8-9 - Publish (3 hours)
HF: push ggufs + imatrix.dat + calib.txt + README (use README-template.md) + eval-table.md. Tags: gguf, llama.cpp, ollama, 4gb.
GitHub: push quant.sh, eval.sh, Modelfile, bench-1650.log, eval-table.md. No binaries.
Space: Gradio demo loading Q4, 2 examples, badge with tok/s + RAM.
Flip HF to public.

## Day 10-12 - Repeat for vision (6-8 hours)
Same pipeline for SmolVLM-500M (from your 4GB list). Only change: base model + test with 1 image + text prompt. This is your differentiator - few verified vision GGUFs.

## Day 13-14 - Upstream + Resume (2 hours)
1. File 1 issue to llama.cpp / transformers with logs (template bug, ppl delta, tokenizer mismatch). Include commit hash + cmds.
2. Resume bullets:
- Published verified GGUF for SmolLM3-3B + SmolVLM-500M, [tok/s] on 1650 4GB, [N]k pulls
- [N] merged issue/PR link
3. Pin GitHub repo + add HF profile link to resume.
4. Post: HF + LinkedIn + X with bench table, not just "I quantized".

## Rules to stay resume-grade
- One imatrix build, not blind quant. Save calib + imatrix.
- Always F16 vs Q4 numbers. No numbers = spam.
- License check: SmolLM3 = Apache 2.0 OK. Keep license file.
- Kaggle limit: ~30h/week T4. This plan uses ~12h. If quota hits, switch to Colab free for eval only.

Start now: Kaggle cell 1 -> run quant.sh
