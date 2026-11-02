# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := rust
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_1.99.1-alpine := sha256:7e9e2d068a107a2adafd19930011178d14a78326053cd4c3a9f7ad3fd049557d

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
