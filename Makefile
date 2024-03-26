VERSION := "$(shell git describe --tags)-$(shell git rev-parse --short HEAD)"
BUILDTIME := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
GOLDFLAGS += -X github.com/stefan-chivu/go-helm-operator/go-helm-operator.Version=$(VERSION)
GOLDFLAGS += -X github.com/stefan-chivu/go-helm-operator/go-helm-operator.Buildtime=$(BUILDTIME)

GOFLAGS = -ldflags "$(GOLDFLAGS)"

.PHONY: build release

build: clean
	go build -o go-helm-operator-app $(GOFLAGS) ./go-helm-operator
	chmod +x go-helm-operator-app
	./go-helm-operator-app -version

clean:
	rm -f go-helm-operator-app
	rm -f cover.out
	rm -f cpu.pprof

cover:
	go test -count=1 -cover -coverprofile=cover.out ./...
	go tool cover -func=cover.out

debug: build
	./go-helm-operator-app -PProf -CPUProfile=cpu.pprof -ServerTLSCert=server.crt -ServerTLSKey=server.key

lint:
	go fmt ./ ./go-helm-operator/...
	go vet

release:
	mkdir -p release
	rm -f release/go-helm-operator-app release/go-helm-operator-app.exe
ifeq ($(shell go env GOOS), windows)
	go build -o release/go-helm-operator-app.exe $(GOFLAGS) ./go-helm-operator
	cd release; zip -m "go-helm-operator-app-$(shell git describe --tags --abbrev=0)-$(shell go env GOOS)-$(shell go env GOARCH).zip" go-helm-operator-app.exe
else
	go build -o release/go-helm-operator-app $(GOFLAGS) ./go-helm-operator
	cd release; zip -m "go-helm-operator-app-$(shell git describe --tags --abbrev=0)-$(shell go env GOOS)-$(shell go env GOARCH).zip" go-helm-operator-app
endif
	cd release; sha256sum "go-helm-operator-app-$(shell git describe --tags --abbrev=0)-$(shell go env GOOS)-$(shell go env GOARCH).zip" > "go-helm-operator-app-$(shell git describe --tags --abbrev=0)-$(shell go env GOOS)-$(shell go env GOARCH).zip.sha256"


run: build
	./go-helm-operator-app -ServerTLSCert=server.crt -ServerTLSKey=server.key

sync:
	go get ./...

test: clean
	go test -count=1 -cover ./...

tls:
	openssl ecparam -genkey -name secp384r1 -out server.key
	openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650 -subj "/CN=selfsigned.go-helm-operator.local"

update:
	go mod tidy
	go get -u ./...

# build-client-deps: clean-client
# 	npm whatever

run-client: # build-client
	# ./go-helm-operator-webclient
	npm --prefix `pwd`/webclient start 
