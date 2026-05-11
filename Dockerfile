# syntax=docker/dockerfile:1.7

ARG BUN_VERSION=1.3.13
ARG GBRAIN_REPO_URL=https://github.com/garrytan/gbrain.git
ARG GBRAIN_REF=master
ARG INSTALL_RUNTIME_GIT=0

FROM oven/bun:${BUN_VERSION} AS source
ARG GBRAIN_REPO_URL
ARG GBRAIN_REF
WORKDIR /src

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${GBRAIN_REF}" "${GBRAIN_REPO_URL}" /src \
  || (rm -rf /src/.git && git clone "${GBRAIN_REPO_URL}" /src && cd /src && git checkout "${GBRAIN_REF}")
RUN rm -rf /src/.git

FROM oven/bun:${BUN_VERSION} AS build-admin
WORKDIR /build

COPY --from=source /src ./
RUN bun install --frozen-lockfile
RUN cd admin && bun install --frozen-lockfile && bun run build

FROM oven/bun:${BUN_VERSION} AS deps
WORKDIR /app

COPY --from=source /src/package.json /src/bun.lock /src/bunfig.toml ./
RUN bun install --frozen-lockfile --production

FROM oven/bun:${BUN_VERSION} AS runtime
ARG INSTALL_RUNTIME_GIT
WORKDIR /app

RUN if [ "$INSTALL_RUNTIME_GIT" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends ca-certificates git \
      && rm -rf /var/lib/apt/lists/*; \
    fi

ENV NODE_ENV=production \
    GBRAIN_HOME=/data

COPY --from=deps --chown=bun:bun /app/node_modules ./node_modules
COPY --from=source --chown=bun:bun /src ./
COPY --from=build-admin --chown=bun:bun /build/admin/dist ./admin/dist

RUN install -d -o bun -g bun /data /workspace /data/.gbrain

WORKDIR /app
USER bun

VOLUME ["/data"]
EXPOSE 3131

ENTRYPOINT ["bun", "run", "/app/src/cli.ts"]
CMD ["--help"]
