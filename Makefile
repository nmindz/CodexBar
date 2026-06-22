SHELL := /bin/bash
APP_IDENTITY ?= Apple Development: nightmaremindz@gmail.com (UF98E359JX)

.PHONY: build check docs-list format install lint release restart start start-debug start-release stop test test-live test-tty

start:
	./Scripts/compile_and_run.sh

start-debug:
	./Scripts/compile_and_run.sh

start-release:
	./Scripts/package_app.sh release
	pkill -x CodexBar || pkill -f CodexBar.app || true
	cd /Users/steipete/Projects/codexbar && open -n /Users/steipete/Projects/codexbar/CodexBar.app

restart: start

stop:
	pkill -x CodexBar || pkill -f CodexBar.app || true

check lint:
	./Scripts/lint.sh lint

format:
	./Scripts/lint.sh format

docs-list:
	node Scripts/docs-list.mjs

build:
	swift build

test:
	./Scripts/test.sh

test-tty:
	swift test --filter TTYIntegrationTests

test-live:
	LIVE_TEST=1 swift test --filter LiveAccountTests

release:
	./Scripts/package_app.sh release

install:
	APP_IDENTITY="$(APP_IDENTITY)" ./Scripts/package_app.sh release
	pkill -x CodexBar || pkill -f CodexBar.app || true
	rm -rf /Applications/CodexBar.app
	ditto CodexBar.app /Applications/CodexBar.app
