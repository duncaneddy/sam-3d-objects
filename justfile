# Environment bootstrap for sam-3d-objects.
#
# Quick start (end-to-end): just bootstrap
# Individual steps:         just install-cuda / just sync / just patch-hydra

# --- config ----------------------------------------------------------------

# Where the CUDA 12.9 toolkit will be installed. Override on the CLI:
#   just cuda_home=$HOME/cuda-12.9 install-cuda
cuda_home        := env_var_or_default("CUDA_HOME", "/usr/local/cuda-12.9")
cuda_runfile     := "cuda_12.9.0_575.51.03_linux.run"
cuda_url         := "https://developer.download.nvidia.com/compute/cuda/12.9.0/local_installers/" + cuda_runfile
cuda_download_dir := env_var_or_default("TMPDIR", "/tmp")

# --- recipes ---------------------------------------------------------------

# List available recipes.
default:
    @just --list

# Download the CUDA 12.9 toolkit runfile (~5.8 GB, cached, skipped if present).
download-cuda:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{cuda_download_dir}}"
    dest="{{cuda_download_dir}}/{{cuda_runfile}}"
    if [ -f "${dest}" ]; then
        echo "Already downloaded: ${dest}"
    else
        echo "Downloading CUDA 12.9 runfile (~5.8 GB) to ${dest} ..."
        curl -L --fail --progress-bar -o "${dest}.part" "{{cuda_url}}"
        mv "${dest}.part" "${dest}"
    fi

# Install the CUDA 12.9 toolkit (no driver) to {{cuda_home}} — sudo used automatically if needed.
install-cuda: download-cuda
    #!/usr/bin/env bash
    set -euo pipefail
    prefix="{{cuda_home}}"
    runfile="{{cuda_download_dir}}/{{cuda_runfile}}"

    if [ -x "${prefix}/bin/nvcc" ]; then
        echo "CUDA already installed at ${prefix} (found nvcc). Skipping."
        exit 0
    fi

    mkdir -p "$(dirname "${prefix}")" 2>/dev/null || true
    parent="$(dirname "${prefix}")"
    if [ -w "${parent}" ]; then
        sudo_prefix=""
    else
        echo "(${parent} is not writable — using sudo for install)"
        sudo_prefix="sudo"
    fi

    echo "Installing toolkit to ${prefix} ..."
    ${sudo_prefix} sh "${runfile}" \
        --silent \
        --toolkit \
        --toolkitpath="${prefix}" \
        --no-opengl-libs \
        --override

    echo
    echo "CUDA 12.9 toolkit installed at ${prefix}."
    echo
    echo "Add to your shell rc (~/.bashrc or ~/.zshrc) so future shells pick it up:"
    echo
    echo "    export CUDA_HOME=${prefix}"
    echo '    export PATH=$CUDA_HOME/bin:$PATH'
    echo '    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH'
    echo

# Install uv + Python 3.11, create .venv, and install all deps + extras (builds pytorch3d/gsplat/flash_attn, needs CUDA).
sync:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v uv >/dev/null 2>&1; then
        echo "Installing uv ..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Export CUDA paths for build backends (nvcc invocations during sync).
    export CUDA_HOME="{{cuda_home}}"
    export PATH="${CUDA_HOME}/bin:${PATH}"
    export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"

    if [ ! -x "${CUDA_HOME}/bin/nvcc" ]; then
        echo "ERROR: ${CUDA_HOME}/bin/nvcc not found. Run 'just install-cuda' first." >&2
        exit 1
    fi

    uv python install 3.11
    if [ ! -d .venv ]; then
        uv venv --python 3.11 .venv
    else
        echo ".venv already exists — reusing (delete it to force recreation)"
    fi
    uv sync \
        --extra dev --extra p3d --extra inference \
        --preview-features extra-build-dependencies

    echo
    echo "Done. Activate with: source .venv/bin/activate"

# Apply the hydra patch (facebookresearch/hydra#2863) inside the .venv.
patch-hydra:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f .venv/bin/activate ]; then
        # shellcheck disable=SC1091
        source .venv/bin/activate
    fi
    ./patching/hydra

# Idempotent end-to-end setup: CUDA toolkit → venv + deps → hydra patch. Re-run freely.
setup: install-cuda sync patch-hydra

alias bootstrap := setup
