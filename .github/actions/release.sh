#!/usr/bin/env bash

# Version aliases identify published releases; only primary tags publish images.
if [[ "${GITHUB_REF:-}" =~ ^refs/tags/.+-r[0-9]+$ ]]; then
    exit 0
fi

set -ex

if [[ "${GITHUB_REF}" == refs/heads/master || "${GITHUB_REF}" == refs/tags/* ]]; then
  minor_ver="${RUST_VER%.*}"
  minor_tag="${minor_ver}"
  major_tag="${minor_ver%.*}"

  if [[ -n "${RUST_DEV}" ]]; then
    minor_tag="${minor_tag}-dev"
    if [[ -n "${LATEST_MAJOR}" ]]; then
      major_tag="${major_tag}-dev"
    fi
  fi

  tags=("${minor_tag}")
  if [[ -n "${LATEST_MAJOR}" ]]; then
     tags+=("${major_tag}")
  fi

  if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    image_revision="${GITHUB_REF##*/}"
    tags=("${minor_tag}-${image_revision}")
    if [[ -n "${LATEST_MAJOR}" ]]; then
      tags+=("${major_tag}-${image_revision}")
    fi
  else
    if [[ -n "${LATEST}" ]]; then
      if [[ -z "${RUST_DEV}" ]]; then
        tags+=("latest")
      else
        tags+=("dev")
      fi
    fi
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create IMAGETOOLS_TAG=${tag}
  done
fi
