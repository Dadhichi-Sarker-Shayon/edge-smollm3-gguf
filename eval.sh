#!/bin/bash
# Eval: must pass <3% ppl rise, else redo calib
set -e
./llama.cpp/build/bin/llama-perplexity -m smol-f16.gguf -f wikitext-test.txt -c 2048 -n 128 > ppl-f16.log; cat ppl-f16.log
./llama.cpp/build/bin/llama-perplexity -m smol-Q4_K_M.gguf -f wikitext-test.txt -c 2048 -n 128 > ppl-q4.log; cat ppl-q4.log
./llama.cpp/build/bin/llama-perplexity -m smol-Q8_0.gguf -f wikitext-test.txt -c 2048 -n 128 > ppl-q8.log; cat ppl-q8.log

pip install -q lm-evaluation-harness
lm_eval --model hf --model_args pretrained=./base --tasks arc_challenge,hellaswag --batch_size 4 > eval-fp16.json; cat eval-fp16.json
echo "Fill eval-table.md with F16 vs Q4 vs Q8 now"
