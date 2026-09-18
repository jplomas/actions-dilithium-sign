FROM golang:1.22-bookworm AS builder

# Pinned to a release commit. An unpinned clone tracks main HEAD, so rebuilding
# this image would silently change the signer: qrlft has since made --algorithm
# mandatory, which breaks this action's own entrypoint, and is moving Dilithium
# to a vendored copy now that go-qrllib has dropped it. Neither belongs in a
# deprecated action that exists to keep behaving exactly as it did.
#
# This is the same commit theQRL/actions-mldsa-sign pins, so both actions build
# one known signer rather than two.
ARG QRLFT_COMMIT=edc20365292418f65865c831f3d1364e62e34801 # v4.0.0
RUN git clone https://github.com/theQRL/qrlft.git /qrlft \
 && git -C /qrlft checkout "${QRLFT_COMMIT}"
WORKDIR /qrlft
RUN go mod download
RUN CGO_ENABLED=0 go build -o qrlft .

FROM debian:bookworm-slim
COPY --from=builder /qrlft/qrlft /qrlft/qrlft
COPY entrypoint.sh /qrlft/entrypoint.sh
RUN chmod +x /qrlft/entrypoint.sh

ENTRYPOINT ["/qrlft/entrypoint.sh"]

