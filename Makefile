.PHONY: build test lint scan clean

IMAGE_NAME ?= subversion-ldap-httpd
IMAGE_TAG  ?= 1.14.5

# Local lint and scan tools, pinned by digest. Renovate keeps them current.
# renovate: datasource=docker depName=hadolint/hadolint
HADOLINT_IMAGE   ?= hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d
# renovate: datasource=docker depName=aquasec/trivy
TRIVY_IMAGE      ?= aquasec/trivy:0.74.0@sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

test: build
	./tests/integration/test-integration.sh $(IMAGE_NAME):$(IMAGE_TAG)

lint:
	shellcheck tests/integration/*.sh .github/scripts/*.sh
	docker run --rm -i $(HADOLINT_IMAGE) < Dockerfile

scan: build
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock $(TRIVY_IMAGE) image --severity CRITICAL,HIGH --ignore-unfixed $(IMAGE_NAME):$(IMAGE_TAG)

clean:
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
