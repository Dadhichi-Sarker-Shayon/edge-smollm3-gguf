#!/bin/bash
# Kaggle T4 - SmolLM3-3B verified GGUF v2 (fixed deps + paths)
set -ex
pip install -q huggingface_hub gguf datasets transformers safetensors accelerate sentencepiece
rm -rf llama.cpp
git clone https://github.com/ggml-org/llama.cpp
cmake llama.cpp -B llama.cpp/build -DBUILD_SHARED_LIBS=OFF -DLLAMA_CURL=OFF > /dev/null
cmake --build llama.cpp/build --config Release -j
ls llama.cpp/build/bin/ | grep -E "quantize|imatrix|perplexity"

huggingface-cli download HuggingFaceTB/SmolLM3-3B --local-dir ./base --exclude "*.bin"
ls -lh ./base

# convert script moved in newer llama.cpp: try root then tools/
if [ -f llama.cpp/convert_hf_to_gguf.py ]; then CONVERT=llama.cpp/convert_hf_to_gguf.py; else CONVERT=llama.cpp/tools/convert_hf_to_gguf.py; fi
echo "Using $CONVERT"
python $CONVERT ./base --outfile smol-f16.gguf --outtype f16
ls -lh smol-f16.gguf

python -c "from datasets import load_dataset; d=load_dataset('wikitext','wikitext-2-raw-v1',split='train'); open('calib.txt','w').write('\n'.join(d['text'][:2000]))"
python -c "from datasets import load_dataset; d=load_dataset('wikitext','wikitext-2-raw-v1',split='test'); open('wikitext-test.txt','w').write('\n'.join(d['text'][:128]))"

./llama.cpp/build/bin/llama-imatrix -m smol-f16.gguf -f calib.txt -o imatrix.dat --chunk 512
./llama.cpp/build/bin/llama-quantize --imatrix imatrix.dat smol-f16.gguf smol-Q4_K_M.gguf Q4_K_M
./llama.cpp/build/bin/llama-quantize smol-f16.gguf smol-Q8_0.gguf Q8_0
ls -lh *.gguf imatrix.dat
# ponytail: Q4_K_M is ceiling for 4GB. Q8_0 is eval reference only.
