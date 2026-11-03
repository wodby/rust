ARG RUST_IMAGE=wodby/rust:1-dev

FROM $RUST_IMAGE

COPY --chown=wodby:wodby app .

RUN cargo build --release && cp target/release/test-app /home/wodby/.cargo/bin/test-app

CMD ["test-app"]
