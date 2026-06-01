FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /go-service ./main.go

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /go-service /go-service

EXPOSE 8080 9090

USER nonroot:nonroot
ENTRYPOINT ["/go-service"]
