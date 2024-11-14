# Use Ubuntu as base image
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    automake \
    autotools-dev \
    cmake \
    fuse \
    g++ \
    git \
    libcurl4-openssl-dev \
    libfuse-dev \
    libssl-dev \
    libxml2-dev \
    libpulse-dev \
    make \
    pkg-config \
    uuid-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and install AWS SDK CPP
WORKDIR /tmp
RUN git clone --recurse-submodules https://github.com/aws/aws-sdk-cpp \
    && mkdir sdk_build \
    && cd sdk_build \
    && cmake ../aws-sdk-cpp \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_ONLY="core;identity-management" \
        -DAUTORUN_UNIT_TESTS=OFF \
    && make \
    && make install \
    && cd .. \
    && rm -rf aws-sdk-cpp sdk_build

# Build s3fs-fuse-awscred-lib
WORKDIR /tmp
RUN git clone https://github.com/ggtakec/s3fs-fuse-awscred-lib.git \
    && cd s3fs-fuse-awscred-lib \
    && cmake -S . -B build \
    && cmake --build build \
    && cp build/libs3fsawscred.so /usr/local/lib/ \
    && cd .. \
    && rm -rf s3fs-fuse-awscred-lib

# Clone and build s3fs-fuse
WORKDIR /tmp
RUN git clone https://github.com/s3fs-fuse/s3fs-fuse.git \
    && cd s3fs-fuse \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -rf s3fs-fuse

# Create mount point directory
RUN mkdir -p /mnt/s3

# Create directory for credentials
RUN mkdir -p /root/.aws

# Add entrypoint script with support for awscred-lib
RUN echo '#!/bin/bash\n\
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then\n\
    echo "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" > /etc/passwd-s3fs\n\
    chmod 600 /etc/passwd-s3fs\n\
fi\n\
\n\
# Set default values for credlib options\n\
CREDLIB_OPTS=${CREDLIB_OPTS:-"LogLevel=Info"}\n\
\n\
if [ -n "$S3_BUCKET" ] && [ -n "$MOUNT_POINT" ]; then\n\
    s3fs "$S3_BUCKET" "$MOUNT_POINT" \
        -o passwd_file=/etc/passwd-s3fs \
        -o dbglevel=info \
        -o curldbg \
        -o credlib=/usr/local/lib/libs3fsawscred.so \
        -o credlib_opts="$CREDLIB_OPTS"\n\
fi\n\
\n\
exec "$@"' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Update library cache
RUN ldconfig

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["tail", "-f", "/dev/null"]
