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

## Run 4 (live streaming)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | online | 23.94 | 0.079 | 1515 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-480ms | online | 27.43 | 0.124 | 2394 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-80ms | online | 33.15 | 0.351 | 6746 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile.int8 | online | 26.95 | 0.077 | 1489 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26.int8 | online | 26.80 | 0.086 | 1651 |

## Run 5 (live streaming)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 17.95 | 0.201 | 4014 |
| sherpa-onnx-nemo-ctc-en-conformer-large | offline | 25.28 | 0.231 | 4602 |
| sherpa-onnx-nemo-ctc-en-conformer-small | offline | 27.43 | 0.048 | 942 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 22.64 | 0.118 | 2344 |
| sherpa-onnx-zipformer-large-en-2023-06-26 | offline | 30.28 | 0.079 | 1558 |
| sherpa-onnx-zipformer-small-en-2023-06-26 | offline | 35.78 | 0.045 | 882 |

## Run 6 (live streaming on phone)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 17.52 | 0.710* | 31531 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 21.76 | 0.473 | 9346 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | online | 23.94 | 0.193 | 3719 |
| sherpa-onnx-streaming-zipformer-en-2023-06-26.int8 | online | 26.80 | 0.967 | 18602 |
* There was an outlier where my phone froze that increased one test to an RTF of 66, so the average was 1.713 if the outlier is included

## Run 7 (live streaming)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) | Cache Duration(s) |
|-------|------|----------|---------|------------------|----|
| sherpa-onnx-moonshine-base-en-int8 | offline | 36.30 | 0.326 | 6608 | 15 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 38.17 | 0.191 | 3874 | 20 |

## Run 8 (live streaming - hard audio)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 21.19 | 0.039 | 750 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 16.83 | 0.030 | 564 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | offline | 26.82 | 0.000 | 0 |

## Run 9 (offline)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 12.48 | 0.061 | 1227 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 16.31 | 0.031 | 609 |
| sherpa-onnx-whisper-small.en.int8 | offline | 10.10 | 0.438 | 8539 |

## Run 10 (offline)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-whisper-base.en | offline | 11.17 | 0.144 | 3255 |
| sherpa-onnx-whisper-distil-medium.en | offline | 11.22 | 0.306 | 6819 |
| sherpa-onnx-whisper-medium.en.int8 | offline | 9.03 | 1.320 | 29841 |
| sherpa-onnx-whisper-small.en.int8 | offline | 9.15 | 0.377 | 8528 |
| sherpa-onnx-whisper-turbo | offline | 8.22 | 0.548 | 12203 |

## Run 11 (offline)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-whisper-base.en | offline | 14.15 | 0.160 | 3073 |
| sherpa-onnx-whisper-distil-medium.en | offline | 16.82 | 0.338 | 6366 |
| sherpa-onnx-whisper-small.en.int8 | offline | 12.72 | 0.435 | 8316 |
| sherpa-onnx-whisper-turbo | offline | 11.59 | 0.609 | 11444 |

## Run 12 (offline)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-whisper-base.en | offline | 11.51 | 0.167 | 3257 |
| sherpa-onnx-whisper-distil-medium.en | offline | 13.44 | 0.364 | 6959 |
| sherpa-onnx-whisper-small.en.int8 | offline | 10.1 | 0.446 | 8666 |
| sherpa-onnx-whisper-turbo | offline | 9.84 | 0.627 | 11972 |

## Run 13 (offline)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 21.09 | 0.061 | 1174 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 22.92 | 0.031 | 574 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | offline | 17.92 | 0.031 | 572 |
| sherpa-onnx-whisper-base.en | offline | 18.62 | 0.187 | 3242 |
| sherpa-onnx-whisper-small.en.int8 | offline | 15.59 | 0.447 | 8268 |
| sherpa-onnx-whisper-turbo | offline | 15.54 | 0.620 | 11179 |

## Run 14 (online - super simple chunking)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 42.89 | 0.044 | 2424 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 31.82 | 0.038 | 2089 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | offline | 26.73 | 0.041 | 2235 |
| sherpa-onnx-whisper-base.en | offline | 52.84 | 0.817 | 44934 |
| sherpa-onnx-whisper-small.en.int8 | offline | 46.24 | 1.008 | 54022 |
| sherpa-onnx-whisper-tiny | offline | 52.93 | 0.286 | 15345 |

### Error Analysis by Model
| Model | Avg WER% | Substitutions | Deletions | Insertions |
|-------|----------|--------------|-----------|------------|
| sherpa-onnx-moonshine-base-en-int8 | 42.89 | 1088 | 243 | 584 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | 31.82 | 808 | 462 | 160 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | 26.73 | 701 | 231 | 282 |
| sherpa-onnx-whisper-base.en | 52.84 | 1052 | 331 | 863 |
| sherpa-onnx-whisper-small.en.int8 | 46.24 | 1088 | 236 | 601 |
| sherpa-onnx-whisper-tiny | 52.93 | 1278 | 268 | 531 |

## Run 15 (online - more advanced chunking)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 58.47 | 0.053 | 2109 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 32.51 | 0.044 | 1763 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | offline | 35.04 | 0.044 | 1761 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | online | 28.05 | 0.075 | 2987 |
| sherpa-onnx-whisper-base.en | offline | 44.28 | 0.235 | 9239 |
| sherpa-onnx-whisper-small.en.int8 | offline | 34.08 | 1.161 | 45727 |
| sherpa-onnx-whisper-tiny.en | offline | 50.92 | 0.236 | 9318 |

### Error Analysis by Model
| Model | Avg WER% | Substitutions | Deletions | Insertions |
|-------|----------|--------------|-----------|------------|
| sherpa-onnx-moonshine-base-en-int8 | 58.47 | 1402 | 155 | 3786 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | 32.51 | 1233 | 234 | 1302 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | 35.04 | 1069 | 164 | 1869 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | 28.05 | 1622 | 581 | 236 |
| sherpa-onnx-whisper-base.en | 44.28 | 1357 | 282 | 2394 |
| sherpa-onnx-whisper-small.en.int8 | 34.08 | 1149 | 203 | 1694 |
| sherpa-onnx-whisper-tiny.en | 50.92 | 1692 | 158 | 2705 |

## Run 16 (online - normalized text)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-moonshine-base-en-int8 | offline | 50.56 | 0.057 | 2290 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 26.65 | 0.052 | 2096 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | offline | 28.53 | 0.058 | 2317 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | online | 18.40 | 0.090 | 3638 |
| sherpa-onnx-whisper-base.en | offline | 46.20 | 0.247 | 9899 |
| sherpa-onnx-whisper-small.en.int8 | offline | 26.99 | 1.399 | 55963 |
| sherpa-onnx-whisper-tiny.en | offline | 44.27 | 0.316 | 12513 |
| sherpa-onnx-whisper-turbo | offline | 29.17 | 1.389 | 55567 |

### Error Analysis by Model
| Model | Avg WER% | Substitutions | Deletions | Insertions |
|-------|----------|--------------|-----------|------------|
| sherpa-onnx-moonshine-base-en-int8 | 50.56 | 651 | 154 | 3965 |
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | 26.65 | 638 | 192 | 1510 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | 28.53 | 495 | 130 | 2003 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | 18.40 | 769 | 571 | 248 |
| sherpa-onnx-whisper-base.en | 46.20 | 670 | 243 | 3674 |
| sherpa-onnx-whisper-small.en.int8 | 26.99 | 332 | 165 | 1943 |
| sherpa-onnx-whisper-tiny.en | 44.27 | 700 | 142 | 3171 |
| sherpa-onnx-whisper-turbo | 29.17 | 312 | 179 | 2235 |

## Run 17 (online - normalized text)
| Model | Type | Avg WER% | Avg RTF | Avg Duration(ms) |
|-------|------|----------|---------|------------------|
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | offline | 19.13 | 0.148 | 6743 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | offline | 15.28 | 0.137 | 6186 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | online | 18.45 | 0.080 | 3445 |

### Error Analysis by Model

| Model | Avg WER% | Substitutions | Deletions | Insertions |
|-------|----------|--------------|-----------|------------|
| sherpa-onnx-nemo-fast-conformer-transducer-en-24500 | 19.13 | 605 | 526 | 364 |
| sherpa-onnx-nemo-parakeet_tdt_transducer_110m-en-36000 | 15.28 | 415 | 357 | 310 |
| sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms | 18.45 | 872 | 637 | 274 |