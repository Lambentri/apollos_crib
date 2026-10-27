# The same Elixir and OTP the dependency-updates workflow resolves with.
# room_scribes declares `elixir: "~> 1.18"`, which Mix won't compile on
# the 1.15 this used to name. hexpm's Alpine build rather than the
# official elixir:1.20.4-otp-28-alpine, which has no amd64 image; its
# Alpine is the one alpine:latest below points at.
FROM docker.io/hexpm/elixir:1.20.4-erlang-28.5.0.8-alpine-3.24.3
MAINTAINER Gabe <gmp@gmp.io>
ARG app_name=apollos_crib
ARG phoenix_subdir=.
ARG build_env=prod
ENV MIX_ENV=${build_env} TERM=xterm
WORKDIR /opt/app
RUN apk update \
    && apk --no-cache --update add git make gcc g++ erlang-dev openssl-dev npm openssh gnu-libiconv \
    && mix local.rebar --force \
    && mix local.hex --force
COPY . .
RUN mix do deps.get, compile
RUN npm install -g npm@6.14.4
RUN cd ${phoenix_subdir}/apps/room_sanctum/assets \
    && npm ci \
    && cd ../ \
    && mix download_data \
    && mix phx.digest \
    && mix assets.deploy \
    && cd ../../ \
RUN mix download_data
RUN mix release ${app_name} \
    && mv _build/${build_env}/rel/${app_name} /opt/release \
    && mv /opt/release/bin/${app_name} /opt/release/bin/start_server
FROM alpine:latest
ARG project_id
RUN apk update \
    && apk --no-cache --update add bash ca-certificates openssl-dev libgcc libstdc++ librsvg imagemagick libcrypto3
EXPOSE 4002
EXPOSE 4001
WORKDIR /opt/app
COPY --from=0 /opt/release .
COPY rel/entrypoint.sh /opt/app/entrypoint.sh
RUN chmod +x /opt/app/entrypoint.sh
CMD ["/opt/app/entrypoint.sh"]
