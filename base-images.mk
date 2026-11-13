# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := rust
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_1.100.0-alpine := sha256:de1e0058543a81ed7b046629167db587c67a94bdf37cce14eb27f0ec83baaffb

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
