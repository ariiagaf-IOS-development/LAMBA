FROM golang:1.22-alpine AS build

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /bin/lamba-api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /bin/lamba-api /lamba-api

EXPOSE 8080
USER nonroot:nonroot

ENTRYPOINT ["/lamba-api"]
