FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    iverilog \
    verilator \
    make \
    python3 \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /proj
COPY . .

# Default command
CMD ["make", "test"]
