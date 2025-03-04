# Steps for trying to port to spanish

## Initial script

```bash
pip install torch torchvision torchaudio kagglehub
pip install nemo-toolkit[all]
git clone https://github.com/NVIDIA/NeMo.git
wget --content-disposition https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/3.60.2/files/ngccli_linux.zip -O ngccli_linux.zip && unzip ngccli_linux.zip
find ngc-cli/ -type f -exec md5sum {} + | LC_ALL=C sort | md5sum -c ngc-cli.md5
sha256sum ngccli_linux.zip
chmod u+x ngc-cli/ngc
echo "export PATH=\"\$PATH:$(pwd)/ngc-cli\"" >> ~/.bash_profile && source ~/.bash_profile
ngc config set
ngc registry model download-version "nvidia/nemo/stt_es_fastconformer_hybrid_large_pc:1.21.0"
```

```python
#!/usr/bin/env python3
# Patch the ConformerEncoder to remove unexpected keyword arguments.

import nemo.collections.asr.modules.conformer_encoder as ce

# Save the original __init__ method.
original_init = ce.ConformerEncoder.__init__

# List of accepted keyword arguments for ConformerEncoder
accepted_keys = {
    "feat_in",
    "n_layers",
    "d_model",
    "feat_out",
    "causal_downsampling",
    "subsampling",
    "subsampling_factor",
    "subsampling_conv_channels",
    "reduction",
    "reduction_position",
    "reduction_factor",
    "ff_expansion_factor",
    "self_attention_model",
    "n_heads",
    "att_context_size",
    "att_context_style",
    "xscaling",
    "untie_biases",
    "pos_emb_max_len",
    "conv_kernel_size",
    "conv_norm_type",
    "conv_context_size",
    "dropout",
    "dropout_pre_encoder",
    "dropout_emb",
    "dropout_att"
}

def patched_init(self, *args, **kwargs):
    # Remove any keys that are not in the accepted_keys set.
    for key in list(kwargs.keys()):
        if key not in accepted_keys:
            kwargs.pop(key)
    return original_init(self, *args, **kwargs)

# Apply the patch.
ce.ConformerEncoder.__init__ = patched_init

# Now import the concrete model class and load the model.
from nemo.collections.asr.models.hybrid_rnnt_ctc_bpe_models import EncDecHybridRNNTCTCBPEModel

# Use your full file path to the .nemo checkpoint
model_path = "/home/grey/stt_es_fastconformer_hybrid_large_pc_v1.21.0/stt_es_fastconformer_hybrid_large_pc.nemo"
model = EncDecHybridRNNTCTCBPEModel.restore_from(model_path)
print(model)
```

```python
python process_asr_text_tokenizer.py \
    --manifest="/path/to/spanish_train_manifest.json" \
    --data_root="/path/to/output/tokenizer_dir" \
    --vocab_size=1024 \
    --tokenizer="spe" \
    --no_lower_case \
    --spe_type="unigram" \
    --spe_character_coverage=1.0 \
    --log
```