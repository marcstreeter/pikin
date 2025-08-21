# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY src/ ./src/

# Build the binary
RUN cd src && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Runtime stage
FROM public.ecr.aws/lambda/provided:al2023-x86_64

# Copy the binary from the builder stage and rename to bootstrap
COPY --from=builder /app/src/main ${LAMBDA_RUNTIME_DIR}/bootstrap

# Set the CMD to your handler
CMD [ "bootstrap" ]