# Use Ubuntu as base image
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    automake \
    autotools-dev \
    fuse \
    g++ \
    git \
    libcurl4-openssl-dev \
    libfuse-dev \
    libssl-dev \
    libxml2-dev \
    make \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Clone and build s3fs-fuse
WORKDIR /tmp
RUN git clone https://github.com/s3fs-fuse/s3fs-fuse.git \
    && cd s3fs-fuse \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install

# Create mount point directory
RUN mkdir -p /mnt/s3

# Create directory for credentials
RUN mkdir -p /root/.aws

# Add entrypoint script
RUN echo '#!/bin/bash\n\
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then\n\
    echo "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" > /etc/passwd-s3fs\n\
    chmod 600 /etc/passwd-s3fs\n\
fi\n\
\n\
if [ -n "$S3_BUCKET" ] && [ -n "$MOUNT_POINT" ]; then\n\
    s3fs "$S3_BUCKET" "$MOUNT_POINT" -o passwd_file=/etc/passwd-s3fs -o dbglevel=info -o curldbg\n\
fi\n\
\n\
exec "$@"' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["tail", "-f", "/dev/null"]
