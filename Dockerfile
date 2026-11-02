# check=skip=InvalidDefaultArgInFrom

# The Makefile supplies the required digest-pinned BASE_IMAGE argument.
ARG RUST_VER=1.99.1

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG RUST_DEV
LABEL com.wodby.workspace.contract="${RUST_DEV:+1}"

ARG WODBY_USER_ID=1000
ARG WODBY_GROUP_ID=1000

ENV RUST_DEV="${RUST_DEV}" \
    SSHD_PERMIT_USER_ENV="yes"

# The toolchain stays where the base image installed it (RUSTUP_HOME); Cargo's
# registry cache and installed binaries live in the user's home.
ENV APP_ROOT="/usr/src/app" \
    CONF_DIR="/usr/src/conf" \
    FILES_DIR="/mnt/files" \
    SSHD_HOST_KEYS_DIR="/etc/ssh" \
    ENV="/home/wodby/.shrc" \
    CARGO_HOME="/home/wodby/.cargo" \
    \
    GIT_USER_EMAIL="wodby@example.com" \
    GIT_USER_NAME="wodby"

ENV PATH="${CARGO_HOME}/bin:${PATH}"

ARG TARGETPLATFORM

# Upgrade inherited packages even when their existing versions satisfy dependencies.
RUN set -xe; \
    apk upgrade --no-cache; \
    \
    # Delete existing user/group if uid/gid occupied. \
    existing_group=$(getent group "${WODBY_GROUP_ID}" | cut -d: -f1); \
    if [[ -n "${existing_group}" ]]; then delgroup "${existing_group}"; fi; \
    existing_user=$(getent passwd "${WODBY_USER_ID}" | cut -d: -f1); \
    if [[ -n "${existing_user}" ]]; then deluser "${existing_user}"; fi; \
    \
    addgroup -g "${WODBY_GROUP_ID}" -S wodby; \
    adduser -u "${WODBY_USER_ID}" -D -S -s /bin/bash -G wodby wodby; \
    sed -i '/^wodby/s/!/*/' /etc/shadow; \
    \
    apk add --update --no-cache -t .wodby-rust-run-deps \
        bash \
        ca-certificates \
        curl \
        git \
        gzip \
        jq \
        less \
        make \
        mariadb-client \
        mariadb-connector-c \
        nano \
        openssh \
        openssh-client \
        patch \
        postgresql-client \
        rabbitmq-c \
        rsync \
        su-exec \
        sudo \
        tar \
        tig \
        tmux \
        tzdata \
        unzip \
        wget \
        yaml; \
    \
    # Every image builds applications, so crates that link OpenSSL statically \
    # (the musl target links statically by default) build in all variants. \
    apk add --update --no-cache -t .wodby-rust-build-deps \
        openssl-dev \
        openssl-libs-static \
        pkgconf; \
    \
    if [[ -n "${RUST_DEV}" ]]; then \
        apk add --no-cache ripgrep; \
        apk add --update --no-cache -t .wodby-rust-dev-deps \
            build-base \
            cmake \
            linux-headers \
            mariadb-dev \
            perl \
            postgresql-dev \
            sqlite-dev; \
    fi; \
    \
    # Formatting and lint checks run in CI with the same image. \
    rustup component add clippy rustfmt; \
    \
    # Download helper scripts. \
    dockerplatform=${TARGETPLATFORM:-linux/amd64}; \
    gotpl_url="https://github.com/wodby/gotpl/releases/latest/download/gotpl-${dockerplatform/\//-}.tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz --no-same-owner -C /usr/local/bin; \
    git clone https://github.com/wodby/alpine /tmp/alpine; \
    cd /tmp/alpine; \
    latest=$(git describe --abbrev=0 --tags); \
    git checkout "${latest}"; \
    mv /tmp/alpine/bin/* /usr/local/bin; \
    \
    # Install redis-cli. \
    apk add --update --no-cache redis; \
    mv /usr/bin/redis-cli /tmp/; \
    apk del --purge redis; \
    deluser redis; \
    mv /tmp/redis-cli /usr/bin; \
    \
    install -o wodby -g wodby -d \
        "${APP_ROOT}" \
        "${CONF_DIR}" \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        "${CARGO_HOME}/bin" \
        /home/wodby/.ssh; \
    \
    { \
        echo 'export PS1="\u@$(hostname):\w $ "'; \
        echo "export PATH=${PATH}"; \
    } | tee /home/wodby/.shrc; \
    \
    cp /home/wodby/.shrc /home/wodby/.bashrc; \
    cp /home/wodby/.shrc /home/wodby/.bash_profile; \
    \
    # Configure sudoers. \
    { \
        echo "Defaults secure_path=\"$PATH\""; \
        echo 'Defaults env_keep += "APP_ROOT FILES_DIR CARGO_HOME RUSTUP_HOME"'; \
        \
        if [[ -n "${RUST_DEV}" ]]; then \
            echo 'wodby ALL=(root) NOPASSWD:SETENV:ALL'; \
        else \
            echo -n 'wodby ALL=(root) NOPASSWD:SETENV: '; \
            echo -n '/usr/local/bin/gen_ssh_keys, '; \
            echo -n '/usr/local/bin/init_container, '; \
            echo -n '/usr/sbin/sshd, '; \
            echo '/usr/sbin/crond'; \
        fi; \
    } | tee /etc/sudoers.d/wodby; \
    \
    touch /etc/ssh/sshd_config; \
    chown wodby:wodby /etc/ssh/sshd_config /home/wodby/.*; \
    \
    rm -rf \
        /etc/crontabs/root \
        /tmp/* \
        /var/cache/apk/*

USER wodby

WORKDIR ${APP_ROOT}
EXPOSE 8080

COPY templates /etc/gotpl/
COPY docker-entrypoint.sh /
COPY bin /usr/local/bin/

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["cargo"]

COPY workspace-profile.sh /etc/profile.d/workspace.sh
