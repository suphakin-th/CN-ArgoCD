FROM golang:1.22-alpine AS builder

RUN apk add --no-cache protobuf protobuf-dev && \
    go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2 && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.3.0

WORKDIR /app

COPY go.mod ./
COPY proto/ proto/

RUN protoc \
      --go_out=. --go_opt=paths=source_relative \
      --go-grpc_out=. --go-grpc_opt=paths=source_relative \
      proto/greeterv1/greeter.proto

COPY . .

RUN go env -w GONOSUMDB="*" && \
    go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /go-service .

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /go-service /go-service

EXPOSE 8080 9090

USER nonroot:nonroot
ENTRYPOINT ["/go-service"]
