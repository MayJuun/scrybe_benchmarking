# scrybe_benchmarking

I'm sure there are faster ways to do this, but this allowed me to test locally on my PC and use Flutter in the process. Happy for any PRs or suggestions anyone has.

## Setup

- Ensure you have an ```assets/``` directory in the main project directory
- inside ```assets/``` include ```curated/```, ```derived/```, ```models/```, and ```raw/```
- in ```models/```, just put a directory for each model you want to test
.<br>
├── sherpa-onnx-moonshine-base-en-int8<br>
│   ├── cached_decode.int8.onnx<br>
│   ├── encode.int8.onnx<br>
│   ├── preprocess.onnx<br>
│   ├── tokens.txt<br>
│   └── uncached_decode.int8.onnx<br>
├── sherpa-onnx-nemo-ctc-en-conformer-large<br>
│   ├── model.int8.onnx<br>
│   ├── model.onnx<br>
│   └── tokens.txt<br>
- Inside raw, put Directories grouping wav/srt files together
.<br>
├── Vital_Signs<br>
│   ├── 1.1.srt<br>
│   ├── 1.1.wav<br>
│   ├── 1.2a.srt<br>
│   ├── 1.2a.wav<br>
├── Mechanical_Ventilation<br>
│   ├── Vent_v1.srt<br>
│   ├── Vent_v1.wav<br>
│   ├── Vent_v10.srt<br>
│   ├── Vent_v10.wav<br>

## Conversion
- You must have the folders setup as described above or else this won't work
- When you click the ```Convert Raw Files``` button, it will go through each directory in ```raw/``` and create a mirror directory in ```curated/```
- Currently only works on wav and srt files, but shouldn't be that hard to add mp3 support, and possible json basd on [this schema](misc/schema.json)
- It will the go through each matching wav/srt file
- It will split them into 20-30 second chunks based on a rough mechanism that can be [seen here](lib/services/asr_preprocessor.dart)
- It will save them in a directory with the same name as the file that its chunking
.<br>
├── Vital_Signs<br>
│   ├── 1.1<br>
│   │   ├── 001.srt<br>
│   │   ├── 001.wav<br>
│   │   ├── 002.srt<br>
│   │   ├── 002.wav<br>
│   ├── 1.2a<br>
│   │   ├── 001.srt<br>
│   │   ├── 001.wav<br>
├── Mechanical_Ventilation<br>
│   ├── Vent_v1<br>
│   │   ├── 001.srt<br>
│   │   ├── 001.wav<br>
│   ├── Vent_v10.srt<br>
│   │   ├── 001.srt<br>
│   │   ├── 001.wav<br>
│   │   ├── 002.srt<br>
│   │   ├── 002.wav<br>

## Benchmarking
- After you've made sure you have all of the models you need in the ```assets/models/`` directory, add them to [models.dart](lib/models.dart)
- I've included a number of different kinds in there to show how they are setup (please let me know if any are incorrect)
- Then just push ```Run Benchmark```
- It will display your progress as it runs through models and files
- It eventually produces resultsl in ```assets/derived/reports/report.txt``` that look like the ones below
- As I said, it's not the fastest, but for a quick and dirty basic comparison, its been working ok for me


### Run 1
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

## Run 2
- So I'm running on a AMD® Ryzen 7 pro, 64 GB RAM, Budgie Linux
- curated assets ~300MB of .wav files
- Took close to 6 hours (maybe I'll implement parallel processing)


| Model | Files | Avg WER | Min WER | Max WER | Word Accuracy | Avg Decode (s) | RTF |
|-------|-------|---------|---------|---------|---------------|----------------|-----|
| sherpa-onnx-moonshine-base-en-int8 | 380 | 9.39% | 0.00% | 100.00% | 90.61% | 2.24 | 0.08 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | 380 | 14.28% | 0.00% | 100.00% | 85.72% | 0.97 | 0.04 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile | 380 | 28.77% | 9.09% | 100.00% | 71.23% | 2.38 | 0.09 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8 | 380 | 28.79% | 9.09% | 100.00% | 71.21% | 1.53 | 0.06 |
| sherpa-onnx-whisper-small.en | 380 | 9.27% | 0.00% | 100.00% | 90.73% | 14.45 | 0.53 |
| sherpa-onnx-whisper-small.en.int8 | 380 | 9.32% | 0.00% | 100.00% | 90.68% | 12.70 | 0.46 |
| sherpa-onnx-whisper-tiny.en | 380 | 12.25% | 0.00% | 300.00% | 87.75% | 2.89 | 0.11 |
| sherpa-onnx-whisper-tiny.en.int8 | 380 | 12.55% | 0.00% | 300.00% | 87.45% | 2.71 | 0.10 |
| sherpa-onnx-zipformer-small-en-2023-06-26 | 380 | 26.84% | 7.69% | 100.00% | 73.16% | 0.68 | 0.02 |
| sherpa-onnx-zipformer-small-en-2023-06-26.int8 | 380 | 26.94% | 7.69% | 100.00% | 73.06% | 0.55 | 0.02 |
| sherpa-onnx-nemo-ctc-en-conformer-large | 380 | 22.35% | 4.23% | 100.00% | 77.65% | 2.07 | 0.08 |
| sherpa-onnx-nemo-ctc-en-conformer-small | 380 | 24.87% | 6.19% | 100.00% | 75.13% | 0.61 | 0.02 |
| sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18 | 380 | 34.87% | 15.38% | 100.00% | 65.13% | 1.39 | 0.05 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26 | 380 | 28.72% | 9.09% | 100.00% | 71.28% | 2.61 | 0.10 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26.int8 | 380 | 28.72% | 9.09% | 100.00% | 71.28% | 1.78 | 0.07 |
| sherpa-onnx-zipformer-large-en-2023-06-26 | 380 | 25.60% | 7.04% | 100.00% | 74.40% | 1.28 | 0.05 |
| sherpa-onnx-zipformer-large-en-2023-06-26.int8 | 380 | 25.65% | 7.04% | 100.00% | 74.35% | 0.81 | 0.03 |


## Run 3
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 33.5909 | 0.592 | 11810 |
| sherpa-onnx-nemo-ctc-en-conformer-large | offline | 43.9242 | 0.687 | 13716 |
| sherpa-onnx-nemo-ctc-en-conformer-small | offline | 39.4848 | 0.100 | 1982 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 38.6364 | 0.308 | 6074 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | online | 47.5909 | 0.068 | 1305 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-480ms | online | 46.7424 | 0.116 | 2234 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-80ms | online | 45.7121 | 0.352 | 6767 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8 | online | 49.2424 | 0.062 | 1198 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26.int8 | online | 49.2121 | 0.070 | 1343 |
| sherpa-onnx-zipformer-large-en-2023-06-26 | offline | 39.2424 | 0.206 | 4057 |
| sherpa-onnx-zipformer-small-en-2023-06-26 | offline | 38.5455 | 0.109 | 2158 |

## Run 4
## Overall Results
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | online | 23.94 | 0.079 | 1515 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-480ms | online | 27.43 | 0.124 | 2394 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-80ms | online | 33.15 | 0.351 | 6746 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8 | online | 26.95 | 0.077 | 1489 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26.int8 | online | 26.80 | 0.086 | 1651 |

