FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN go build -o app

FROM alpine:3.20
COPY --from=build /app/app /usr/local/bin/app
EXPOSE 8080
CMD ["app"]
