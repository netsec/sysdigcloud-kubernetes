IMAGE_NAME ?= configurator
MANIFESTS = "$(PWD)/tmp"
UBER_TAR = "$(MANIFESTS)/uber_archive.tar.gz"
LOCAL_SCRIPTS := $(shell find $(SOURCEDIR) -name '*.sh' -exec basename {} \;)
CONTAINER_SCRIPTS := $(addprefix /sysdig-chart/, $(LOCAL_SCRIPTS))

build:
	docker build . -t $(IMAGE_NAME)

shellcheck:
	docker run --rm -v $(PWD)/sysdig-chart:/sysdig-chart koalaman/shellcheck \
		--exclude=SC2164,SC1090 -- $(CONTAINER_SCRIPTS)

config_gen: build
	docker run --rm -v $(PWD)/sysdig-chart:/sysdig-chart --entrypoint \
		/sysdig-chart/test.sh $(IMAGE_NAME) config_gen

create_uber_tar: build shellcheck
	docker run --entrypoint /sysdig-chart/airgap.sh --rm \
		-v $(MANIFESTS):/manifests \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v ~/.docker:/root/.docker \
		$(IMAGE_NAME) create_uber_tar $(IMAGE_NAME)

clean:
	docker run --entrypoint /bin/bash --rm -v \
		$(MANIFESTS):/manifests $(IMAGE_NAME) \
		-c "rm -rf /manifests/*; chmod 777 /manifests"

test: build shellcheck
	docker run --rm --entrypoint /sysdig-chart/test.sh $(IMAGE_NAME)

test_uber_tar: create_uber_tar
	docker run --rm --entrypoint /sysdig-chart/test.sh \
		-v $(MANIFESTS):/manifests \
		-v /var/run/docker.sock:/var/run/docker.sock \
		$(IMAGE_NAME) uber_tests

# This assumes that create_uber_tar ran previously
push_uber_tar:
	docker run --entrypoint /sysdig-chart/airgap.sh --rm \
		-e VERSION=${VERSION} -e ARTIFACTORY_API_KEY=${ARTIFACTORY_API_KEY} \
		-v $(MANIFESTS):/manifests -v /var/run/docker.sock:/var/run/docker.sock \
		$(IMAGE_NAME) push_uber_tar

run: build
	docker run -v ~/.kube:/root/.kube -v $(PWD):/manifests $(IMAGE_NAME)
