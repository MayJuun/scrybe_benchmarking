# scrybe_benchmarking

## Testing

Setting up an automatic pipeline for evaluating and comparing different models of ASR

- If you have some input files, put them in a folder in the ```input``` directory
- Within that folder, you'll need your audio files and the transcript files that we're going to compare to
- Transcript files must be either .srt files, .txt files, or .json files
  - .srt: standard format
  - .txt: free text transcription
  - .json: must be according to the [Json Schema](models/schema.json)
