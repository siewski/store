FROM golang:1.18
ARG VERSION=${VERSION}
WORKDIR /app
RUN addgroup --system jaruser \
    && adduser --system --shell /bin/false --disabled-login --ingroup jaruser jaruser \
    && apt update && apt install -y dumb-init curl && apt clean
COPY --chown=jaruser:jaruser \
     ./api-${VERSION} ./api
EXPOSE 8080
# приложение будет запускаться под пользователем jaruser
USER jaruser
ENTRYPOINT ["dumb-init", "./api"]
