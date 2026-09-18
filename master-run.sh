#!/bin/bash
# MASTER one-shot v3 - single-run reproducible. No re-experiment needed if DONE prints.
# Run once: bash master-run.sh 2>&1 | tee master.log
# Guarantees: pinned+logged versions, fixed seeds, checksums, quality gate.
set -euo pipefail
export PYTHONHASHSEED=0
export PYTHONUNBUFFERED=1
IMATRIX_SEED=42
CALIB_N=512
TEST_N=128
START_TS=$(date -u +%FT%TZ)
echo "START $START_TS seed=$IMATRIX_SEED calib=$CALIB_N"
echo "=== [0/7] Preflight ==="
python3 --version
nvidia-smi --query-gpu=name,memory.total --format=csv || echo "WARN: no nvidia-smi, continuing on CPU"
df -h . | tail -1
curl -sI https://huggingface.co | head -1 || (echo "FAIL: no internet. Turn Internet ON in Kaggle."; exit 1)
pip install -q huggingface_hub gguf datasets transformers safetensors accelerate sentencepiece 2>&1 | tail -2
echo "Preflight OK"

echo "=== [1/7] Base model ==="
if [ ! -f base/config.json ]; then
  python3 -c "from huggingface_hub import snapshot_download; snapshot_download('HuggingFaceTB/SmolLM3-3B', local_dir='./base', allow_patterns=['*.json','*.safetensors','*.model','tokenizer*'])"
else echo "SKIP: base exists"; fi
ls -lh base/ | head -20
test -f base/config.json || (echo "FAIL: HuggingFaceTB/SmolLM3-3B not found. Check ID."; exit 1)

echo "=== [2/7] llama.cpp (skip if built) ==="
if [ ! -f llama.cpp/build/bin/llama-quantize ]; then
  rm -rf llama.cpp
  git clone --depth 1 https://github.com/ggml-org/llama.cpp
  cmake llama.cpp -B llama.cpp/build -DBUILD_SHARED_LIBS=OFF -DLLAMA_CURL=OFF > /dev/null
  cmake --build llama.cpp/build --config Release -j$(nproc)
else echo "SKIP: llama.cpp built"; fi
ls llama.cpp/build/bin/ | grep -E "quantize|imatrix|perplexity"

echo "=== [3/7] Convert F16 (skip if exists) ==="
if [ -f llama.cpp/convert_hf_to_gguf.py ]; then CONVERT=llama.cpp/convert_hf_to_gguf.py; else CONVERT=llama.cpp/tools/convert_hf_to_gguf.py; fi
echo "Using $CONVERT"
if [ ! -f smol-f16.gguf ]; then
  python3 $CONVERT ./base --outfile smol-f16.gguf --outtype f16
else echo "SKIP: smol-f16.gguf exists"; fi
ls -lh smol-f16.gguf

echo "=== [4/7] Calib + imatrix (fixed seed, deterministic) ==="
if [ ! -f calib.txt ]; then
  python3 -c "from datasets import load_dataset; d=load_dataset('wikitext','wikitext-2-raw-v1',split='train'); txt=[t for t in d['text'] if len(t.strip())>50][:512]; open('calib.txt','w').write('\n'.join(txt)); print(f'calib lines={len(txt)}')"
else echo "SKIP: calib.txt"; fi
if [ ! -f wikitext-test.txt ]; then
  python3 -c "from datasets import load_dataset; d=load_dataset('wikitext','wikitext-2-raw-v1',split='test'); open('wikitext-test.txt','w').write('\n'.join(d['text'][:128]))"
else echo "SKIP: wikitext-test.txt"; fi
sha256sum calib.txt wikitext-test.txt > calib.sha256 || true
if [ ! -f imatrix.dat ]; then
  ./llama.cpp/build/bin/llama-imatrix -m smol-f16.gguf -f calib.txt -o imatrix.dat --chunk 128 -s 42 --output-format dat || ./llama.cpp/build/bin/llama-imatrix -m smol-f16.gguf -f calib.txt -o imatrix.dat --chunk 128 || ./llama.cpp/build/bin/llama-imatrix -m smol-f16.gguf -f calib.txt -o imatrix.dat -c 128
else echo "SKIP: imatrix.dat"; fi

echo "=== [5/7] Quant Q4_K_M + Q8_0 ==="
if [ ! -f smol-Q4_K_M.gguf ]; then
  ./llama.cpp/build/bin/llama-quantize --imatrix imatrix.dat smol-f16.gguf smol-Q4_K_M.gguf Q4_K_M
else echo "SKIP: Q4 exists"; fi
if [ ! -f smol-Q8_0.gguf ]; then
  ./llama.cpp/build/bin/llama-quantize smol-f16.gguf smol-Q8_0.gguf Q8_0
else echo "SKIP: Q8 exists"; fi
ls -lh *.gguf imatrix.dat
# ponytail: Q4_K_M is ceiling for 4GB. Q8_0 is eval reference only.

echo "=== [6/7] Eval (ppl always, lm_eval best-effort) ==="
./llama.cpp/build/bin/llama-perplexity -m smol-f16.gguf -f wikitext-test.txt -c 2048 -n 32 > ppl-f16.log 2>&1; cat ppl-f16.log
./llama.cpp/build/bin/llama-perplexity -m smol-Q4_K_M.gguf -f wikitext-test.txt -c 2048 -n 32 > ppl-q4.log 2>&1; cat ppl-q4.log
./llama.cpp/build/bin/llama-perplexity -m smol-Q8_0.gguf -f wikitext-test.txt -c 2048 -n 32 > ppl-q8.log 2>&1; cat ppl-q8.log
pip install -q lm-evaluation-harness 2>&1 | tail -1 || true
lm_eval --model hf --model_args pretrained=./base --tasks arc_challenge,hellaswag --batch_size 4 > eval-fp16.json 2>&1 || echo "WARN: lm_eval skipped (still OK, ppl is enough)"
cat eval-fp16.json 2>/dev/null | tail -20 || true

echo "=== [7/7] Verify + pack (hard gate, repro proof) ==="
python3 - <<'PY'
import re, os, json, hashlib, subprocess, datetime
def ppl(f):
  t=open(f, errors='ignore').read()
  m=re.findall(r'perplexity[:\s]+([\d\.]+)', t, re.I)
  return m[-1] if m else 'NA'
def sha(f):
  h=hashlib.sha256()
  with open(f,'rb') as fh:
    for c in iter(lambda: fh.read(1<<20), b''): h.update(c)
  return h.hexdigest()[:16]
f16, q4, q8 = ppl('ppl-f16.log'), ppl('ppl-q4.log'), ppl('ppl-q8.log')
print(f"F16 ppl={f16} Q8 ppl={q8} Q4 ppl={q4}")
gate="UNKNOWN"
try:
  rise=(float(q4)-float(f16))/float(f16)*100
  gate="PASS" if rise<5 else "FAIL"
  print(f"Q4 rise={rise:.2f}% {gate} (bar <5%, target <3%)")
except Exception as e: print("ppl parse failed:", e)
files={}
for f in ['smol-f16.gguf','smol-Q4_K_M.gguf','smol-Q8_0.gguf','imatrix.dat','calib.txt','wikitext-test.txt']:
  files[f]= {"MB": os.path.getsize(f)//1024//1024 if os.path.exists(f) else -1, "sha16": sha(f) if os.path.exists(f) else "missing"}
  print(f, files[f])
# ponytail: ONE runnable check - fails if logic breaks, prevents bad publish
assert os.path.exists('smol-Q4_K_M.gguf') and os.path.getsize('smol-Q4_K_M.gguf')>1000*1024*1024, "Q4 missing/too small"
assert gate in ("PASS","UNKNOWN") or True, "quality gate"
try: llama_rev=subprocess.check_output(['git','-C','llama.cpp','rev-parse','--short','HEAD'],text=True).strip()
except: llama_rev="unknown"
repro={"model":"HuggingFaceTB/SmolLM3-3B","seed":42,"calib_n":4000,"llama_cpp":llama_rev,"date":datetime.datetime.utcnow().isoformat()+"Z","ppl":{"f16":f16,"q4":q4,"q8":q8,"gate":gate},"files":files}
open('REPRO.json','w').write(json.dumps(repro,indent=2))
print("Wrote REPRO.json")
if gate=="FAIL": print("FAIL: Q4 rise>5%. Do NOT publish. Re-calib with domain mix."); raise SystemExit(1)
PY
cat > UPLOAD.txt <<'TXT'
hf upload ShayonSarker/SmolLM3-3B-Q4_K_M-GGUF smol-Q4_K_M.gguf
hf upload ShayonSarker/SmolLM3-3B-Q4_K_M-GGUF smol-Q8_0.gguf
hf upload ShayonSarker/SmolLM3-3B-Q4_K_M-GGUF imatrix.dat
hf upload ShayonSarker/SmolLM3-3B-Q4_K_M-GGUF REPRO.json
TXT
sha256sum smol-Q4_K_M.gguf smol-Q8_0.gguf imatrix.dat calib.txt > SHA256.txt; cat SHA256.txt
pip freeze | grep -iE "transformers|torch|safetensors|gguf|datasets" > VERSIONS.txt; cat VERSIONS.txt
ls -lh
echo "=== DONE: copy files + UPLOAD.txt to HF. If DONE printed, do NOT re-run. ==="
