# scrybe_benchmarking

I'm sure there are faster ways to do this, but this allowed me to test locally on my PC and use Flutter in the process. Happy for any PRs or suggestions anyone has.

## Preferences to date
- Best Streaming: sherpa-onnx-nemo-streaming-fast-conformer-transducer-en-1040ms
- Best Offline Live (tie): 
    - sherpa-onnx-moonshine-base-en-int8
    - sherpa-onnx-nemo-fast-conformer-transducer-en-24500
- Best Offline Batch
    - minimal: sherpa-onnx-whisper-base.en
    - best for mobile: sherpa-onnx-whisper-small.en.int8
    - (1 GB): sherpa-onnx-whisper-turbo

## Setup

### General

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

### Conversion
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

### Android

- Specifically because I always forget these things
- Add the following to AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
``` 

- In app/build.gradle I had to specifically set my ndk: ```ndkVersion = "28.0.13004108"``` (but obviously whatever is on your system)
- I also had to add this
```groovy
    externalNativeBuild {
        cmake {
            version "3.21.5"
        }
    }
```
- Lastly, I had to add this line to my ```local.properties``` file for Android ```ndk.dir=/your/local/dir/to/Android/Sdk/ndk/28.0.13004108```

## Transcription
- After you've made sure you have all of the models you need in the ```assets/models/`` directory, add them to [models.dart](lib/models.dart)
- I've included a number of different kinds in there to show how they are setup (please let me know if any are incorrect)
- Then just push ```Run Benchmark```
- It will display your progress as it runs through models and files
- It eventually produces resultsl in ```assets/derived/reports/report.txt``` that look like the ones below
- As I said, it's not the fastest, but for a quick and dirty basic comparison, its been working ok for me
