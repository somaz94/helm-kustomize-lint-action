.PHONY: lint test test-fixture template-fixture kubeconform-fixture clean help

FIXTURE := tests/fixtures/sample_chart

## Quality

lint: ## yamllint action.yml + workflows + fixtures (dockerized, no host install)
	docker run --rm -v $$(pwd):/data cytopia/yamllint action.yml .github/workflows/ tests/

## Testing

test: test-fixture template-fixture ## Run helm lint + helm template against the fixture chart locally

test-fixture: ## Run `helm lint` against the fixture chart
	helm lint $(FIXTURE) --strict
	helm lint $(FIXTURE) -f $(FIXTURE)/values-prod.yaml --strict

template-fixture: ## Render the fixture chart with `helm template --debug`
	helm template ci-render $(FIXTURE) --debug > /dev/null
	helm template ci-render $(FIXTURE) -f $(FIXTURE)/values-prod.yaml --debug > /dev/null

kubeconform-fixture: ## Pipe `helm template` into kubeconform (requires kubeconform in PATH)
	helm template ci-render $(FIXTURE) | kubeconform -strict -ignore-missing-schemas -summary

## Cleanup

clean: ## Remove local helm packaged artefacts
	rm -f *.tgz

## Help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
