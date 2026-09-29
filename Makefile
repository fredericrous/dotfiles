# The one check target (ADR-0017, ci.mirrors-the-local-check): what a
# workstation runs is what .github/workflows/ci.yaml runs, step for step.
# Each target is its own script under scripts/, so a red job names its step
# and the scripts are themselves under `make lint`.

.POSIX:

check: tools render lint private-refs
	@echo "  ok   tools render lint private-refs" >&2

# Pinned tools into .tools/ (tools.env); never the machine's.
tools:
	@sh scripts/tools.sh

# Every template renders against placeholder data, hermetically.
render: tools
	@sh scripts/render.sh

# shellcheck over every tracked shell script.
lint: tools
	@sh scripts/lint.sh

# No private identifier in any tracked plaintext file.
private-refs:
	@sh scripts/check-private-refs.sh --tree

clean:
	@rm -rf .tools

.PHONY: check tools render lint private-refs clean
