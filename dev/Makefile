REPO:=$(shell git rev-parse --show-toplevel)

create-cluster:
	k3d cluster create --image rancher/k3s:v1.33.5-k3s1 -v "$(REPO):/charts" \
					   --k3s-arg "--disable=traefik@server:0" \
					   --k3s-arg "--disable=servicelb@server:0"

delete-cluster:
	k3d cluster delete

all: create-cluster init deploy-services deploy

run-galoy-smoketest:
	kubectl -n galoy-dev-smoketest exec smoketest -- bash -c "cd /charts/ci/tasks && \
    CHART=galoy ./dev-smoketest-settings.sh && \
    ./galoy-smoketest.sh && \
    rm -rf smoketest-settings response.json"

run-bitcoin-smoketest:
	kubectl -n galoy-dev-smoketest exec smoketest -- bash -c "cd /charts/ci/tasks && \
		CHART=bitcoind ./dev-smoketest-settings.sh && \
		./bitcoind-smoketest.sh regtest && \
		rm -rf smoketest-settings"

run-kafka-connect-smoketest:
	kubectl -n galoy-dev-smoketest exec smoketest -- bash -c "cd /charts/ci/tasks && \
    CHART=kafka-connect ./dev-smoketest-settings.sh && \
    ./kafka-connect-smoketest.sh && \
    rm -rf smoketest-settings response.json"

helm-dep-updates:
	for dir in $$(ls ../charts); do \
		cd ../charts/$$dir && helm dependency update && cd -; \
	done
