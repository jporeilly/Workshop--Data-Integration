#!/bin/bash

###############################################################################
# Kafka Docker Composer - Custom Image Builder
#
# This script builds custom Docker images for Confluent Platform components
# with traffic control (tc) utilities installed.
#
# Purpose:
#   Confluent's UBI-based Docker images don't include 'tc' (traffic control)
#   by default. This script creates custom images that include 'tc' for
#   network simulation and testing scenarios.
#
# Images Built:
#   - cp-server (Kafka broker)
#   - cp-schema-registry (Schema Registry)
#   - cp-server-connect (Kafka Connect)
#
# Usage:
#   ./build_docker_images.sh
#
# Prerequisites:
#   - Docker buildx must be installed
#   - .env file must exist in parent directory with required variables
#
###############################################################################

# ========== Determine Script Directory ==========
# Get the absolute path to the script's directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# ========== Load Environment Variables ==========
# Source the .env file containing CONFLUENT_DOCKER_TAG and REPOSITORY
source ${DIR}/../.env

# ========== Detect Machine Architecture ==========
# Get the machine architecture (e.g., x86_64, aarch64/arm64)
# This ensures compatibility with different CPU architectures
machine=`uname -m`

# ========== Build Custom Docker Images ==========
# Build custom images with 'tc' (traffic control) installed

echo
echo "=========================================="
echo "Building Custom Confluent Platform Images"
echo "=========================================="
echo "These images include 'tc' (traffic control) for network simulation"
echo

# Loop through each Confluent Platform component
# Note: cp-ksqldb-server mentioned in comment but not built (can be added if needed)
for image in cp-server cp-schema-registry cp-server-connect ; do
  # ========== Construct Image Name ==========
  # Format: localbuild/<component>-tc:<version>
  IMAGENAME=localbuild/${image}-tc:${CONFLUENT_DOCKER_TAG}

  echo "Building: $IMAGENAME"

  # ========== Build Docker Image ==========
  # Use buildx for multi-platform support
  # --no-cache: Force rebuild without using cached layers
  # Build arguments:
  #   CP_VERSION: Confluent Platform version tag
  #   REPOSITORY: Docker repository (e.g., confluentinc)
  #   IMAGE: Component name (e.g., cp-server)
  #   MACHINE: CPU architecture
  docker buildx build \
    --no-cache \
    --build-arg CP_VERSION=${CONFLUENT_DOCKER_TAG} \
    --build-arg REPOSITORY=${REPOSITORY} \
    --build-arg IMAGE=$image \
    --build-arg MACHINE=${machine} \
    -t $IMAGENAME \
    -f ${DIR}/../Dockerfile \
    .

  # ========== Verify Image Build ==========
  # Check if the image was successfully built
  # If not found, exit with error
  docker image inspect $IMAGENAME >/dev/null 2>&1 || \
     {
       echo "ERROR: Docker image $IMAGENAME not found after build"
       echo "Please check build logs above for errors and rerun"
       exit 1
     }

  echo "✓ Successfully built: $IMAGENAME"
  echo
done

echo "=========================================="
echo "All custom images built successfully!"
echo "=========================================="
