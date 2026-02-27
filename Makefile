.PHONY: build test integration-test test-all lint scan clean

IMAGE_NAME ?= subversion-ldap-httpd
IMAGE_TAG  ?= 1.14.5

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

test: build
	./tests/test-image.sh $(IMAGE_NAME):$(IMAGE_TAG)

integration-test: build
	./tests/integration/test-integration.sh $(IMAGE_NAME):$(IMAGE_TAG)

test-all: test integration-test

lint:
	shellcheck tests/*.sh tests/integration/*.sh
	docker run --rm -i hadolint/hadolint < Dockerfile

scan: build
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasecurity/trivy image --severity CRITICAL,HIGH --ignore-unfixed $(IMAGE_NAME):$(IMAGE_TAG)

clean:
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
