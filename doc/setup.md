# Setup

## Prerequisites

* A linux 64-bits architecture.
* A NVIDIA GPU with at least 32 Gb of VRAM; the code runs across multiple GPU architectures, including Blackwell.

## 1. Setup Python Environment

`uv` is now the default way to create the environment. The additional NVIDIA/PyTorch indices are configured in `pyproject.toml`, so no extra exports are needed. Use Python 3.11 (the project targets 3.11 only). **CUDA toolkit 12.9 is required for building gsplat/pytorch3d/flash-attn.**

### Quick start (recommended)

The repo ships with a [`justfile`](../justfile) that handles CUDA download, toolkit install, uv/Python 3.11 setup, `uv sync`, and the hydra patch end-to-end:

```bash
# install just if needed: https://just.systems/man/en/installation.html
just setup                # idempotent: CUDA 12.9 toolkit + venv + deps + hydra patch. Safe to re-run.
# or run the individual steps:
just install-cuda         # download + install CUDA 12.9 toolkit (defaults to /usr/local/cuda-12.9)
just sync                 # uv venv + `uv sync --extra inference`
just patch-hydra          # apply https://github.com/facebookresearch/hydra/pull/2863
```

Override the toolkit install path with e.g. `just cuda_home=$HOME/cuda-12.9 install-cuda` if you don't have sudo.

Once CUDA is installed, add these to your shell rc so future shells pick up the toolkit:

```bash
export CUDA_HOME=/usr/local/cuda-12.9
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

### Manual workflow

If you prefer to drive `uv` yourself (CUDA 12.9 must already be on the box and the env vars above exported):

```bash
# install uv if you don't have it yet
pip install uv

# create and activate a local virtualenv
uv python install 3.11
uv venv .venv
source .venv/bin/activate

# install the base set of dependencies
uv sync --preview-features extra-build-dependencies

# optional extras (needed for the demo notebooks)
uv sync --extra inference --preview-features extra-build-dependencies  # gsplat, pytorch3d, flash-attn, gradio, seaborn

# patch things that aren't yet in official pip packages
./patching/hydra # https://github.com/facebookresearch/hydra/pull/2863
```

> If you still prefer a Conda-based workflow for GPU toolchains, you can reuse `environments/default.yml` to provision system libraries, then activate your environment and run `uv sync` inside it to install Python dependencies.

## 2. Getting Checkpoints

### From HuggingFace

⚠️ Before using SAM 3D Objects, please request access to the checkpoints on the SAM 3D Objects
Hugging Face [repo](https://huggingface.co/facebook/sam-3d-objects). Once accepted, you
need to be authenticated to download the checkpoints. You can do this by running
the following [steps](https://huggingface.co/docs/huggingface_hub/en/quick-start#authentication)
(e.g. `hf auth login` after generating an access token).

⚠️ SAM 3D Objects is available via HuggingFace globally, **except** in comprehensively sanctioned jurisdictions.
Sanctioned jurisdiction will result in requests being **rejected**.

```bash
pip install 'huggingface-hub[cli]<1.0'

TAG=hf
hf download \
  --repo-type model \
  --local-dir checkpoints/${TAG}-download \
  --max-workers 1 \
  facebook/sam-3d-objects
mv checkpoints/${TAG}-download/checkpoints checkpoints/${TAG}
rm -rf checkpoints/${TAG}-download
```
