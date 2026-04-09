ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4
ARG ALPINE_VERSION=3.21.3

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# --- Build stage ---
FROM ${BUILDER_IMAGE} AS builder

ENV MIX_ENV=prod

RUN apk add --no-cache git

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY config/config.exs config/prod.exs config/runtime.exs config/
COPY lib lib

RUN mix compile
RUN mix release

# --- Runtime stage ---
FROM ${RUNNER_IMAGE}

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/dokku_radar ./

ENV PORT=9110

EXPOSE 9110

LABEL org.opencontainers.image.source="https://github.com/joeyates/dokku-radar"
LABEL org.opencontainers.image.description="Prometheus exporter for Dokku installations"
LABEL org.opencontainers.image.licenses="MIT"

CMD ["bin/dokku_radar", "start"]
