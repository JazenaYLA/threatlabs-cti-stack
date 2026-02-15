FROM ubuntu:24.04

# Build dependencies
RUN apt-get update && apt-get -y install build-essential curl git python3 ffmpeg libavcodec-extra \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app

WORKDIR /app

# Install poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:${PATH}"

# Copy local source
COPY . /app/lacus

WORKDIR /app/lacus

# Install dependencies (including playwright system deps)
RUN poetry install && poetry run playwright install-deps

# Install playwright browsers
RUN poetry run playwright install

# Set homedir
RUN echo LACUS_HOME="`pwd`" >> .env

# Initialize config (create from samples)
RUN poetry run python3 tools/validate_config_files.py --check && \
    poetry run python3 tools/validate_config_files.py --update

# Install supervisor
RUN apt-get update && apt-get install -y supervisor \
    && rm -rf /var/lib/apt/lists/*

COPY ./supervisord/supervisord.conf /supervisord/supervisord.conf

# Clean up
RUN apt-get remove -y build-essential git && \
    apt-get autoremove -y && \
    apt-get clean

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]