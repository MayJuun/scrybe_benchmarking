# scrybe_benchmarking

## Testing

Setting up an automatic pipeline for evaluating and comparing different models of ASR

- If you have some input files, put them in a folder in the ```input``` directory
- Within that folder, you'll need your audio files and the transcript files that we're going to compare to
- Transcript files must be either .srt files, .txt files, or .json files
  - .srt: standard format
  - .txt: free text transcription
  - .json: must be according to the [Json Schema](models/schema.json)

### Run 1
# ASR Benchmark Report
Generated: 2025-02-14 06:59:12.804824

## Summary

| Model | Files | Avg WER | Min WER | Max WER | Word Accuracy | Avg Decode (s) | RTF |
|-------|-------|---------|---------|---------|---------------|----------------|-----|
| sherpa-onnx-moonshine-base-en-int8 | 365 | 19.89% | 0.00% | 100.00% | 80.11% | 2.33 | 0.08 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile | 365 | 36.80% | 0.00% | 100.00% | 63.20% | 2.56 | 0.09 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8 | 365 | 36.81% | 0.00% | 100.00% | 63.19% | 1.69 | 0.06 |
| sherpa-onnx-whisper-small.en | 365 | 20.01% | 3.13% | 100.00% | 79.99% | 15.09 | 0.50 |
| sherpa-onnx-whisper-small.en.int8 | 365 | 19.71% | 3.13% | 100.00% | 80.29% | 12.67 | 0.42 |
| sherpa-onnx-whisper-tiny.en | 365 | 23.17% | 4.82% | 300.00% | 76.83% | 3.06 | 0.10 |
| sherpa-onnx-whisper-tiny.en.int8 | 365 | 22.98% | 4.82% | 300.00% | 77.02% | 2.73 | 0.09 |
| sherpa-onnx-zipformer-small-en-2023-06-26 | 365 | 34.88% | 14.68% | 100.00% | 65.12% | 0.68 | 0.02 |
| sherpa-onnx-zipformer-small-en-2023-06-26.int8 | 365 | 34.78% | 14.29% | 100.00% | 65.22% | 0.54 | 0.02 |
