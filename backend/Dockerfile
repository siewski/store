FROM golang:1.18-buster AS build
WORKDIR /app
COPY . .
RUN mkdir -p bin && go build -o bin ./...

FROM gcr.io/distroless/base-debian10
WORKDIR /
COPY --from=build /app/bin/api /api
EXPOSE 8081
USER nonroot:nonroot
ENTRYPOINT ["/api"]
