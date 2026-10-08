# oobar v0.2.0 Makefile

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oobar

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.2.0)

.PHONY: build check line-cap file-law academy density verify clean test package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/oobar-linux-x86_64
	@sha256sum dist/oobar-linux-x86_64 > dist/oobar-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/oobar-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" | grep -v "/dist/" | grep -v "/.ooda-cache/"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*" -not -path "./qa*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@echo "=== testing default progress bar ==="
	@./$(BIN) | grep -q "50%" && echo "PASS: default progress bar"
	@echo "=== testing custom current/total ==="
	@./$(BIN) -c 75 -t 100 | grep -q "75%" && echo "PASS: 75% progress"
	@echo "=== testing ascii style ==="
	@./$(BIN) -s ascii -c 25 -t 100 | grep -q "====" && echo "PASS: ascii style"
	@echo "=== testing cyber style ==="
	@./$(BIN) -s cyber -c 50 -t 100 | grep -q "▰" && echo "PASS: cyber style"
	@echo "=== testing braille style ==="
	@./$(BIN) -s braille -c 50 -t 100 | grep -q "⣿" && echo "PASS: braille style"
	@echo "=== testing byte formatting ==="
	@./$(BIN) --bytes -c 1048576 -t 2097152 | grep -q "1MB/2MB" && echo "PASS: byte formatting"
	@echo "=== testing label and ETA ==="
	@./$(BIN) -l "Sync" -c 50 -t 100 -e 10 | grep -q "ETA" && echo "PASS: label and ETA"
	@echo "=== testing completed state ==="
	@./$(BIN) -c 100 -t 100 -e 10 | grep -q "done in" && echo "PASS: completed state"
	@echo "=== testing structured JSON output ==="
	@./$(BIN) --json -c 40 -t 100 | grep -q '"percent":40' && echo "PASS: structured JSON"
	@echo "=== testing MCP initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "bar_render" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP tools/call bar_render ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"bar_render","arguments":{"current":60,"total":100,"style":"block"}}}\n' | ./$(BIN) --mcp | grep -q 'percent.*60' && echo "PASS: MCP bar_render"
	@echo "=== testing MCP tools/call bar_styles ==="
	@printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"bar_styles","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q 'styles' && echo "PASS: MCP bar_styles"
	@echo "=== testing MCP tools/call bar_eta ==="
	@printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"bar_eta","arguments":{"current":50,"total":100,"elapsed_seconds":10}}}\n' | ./$(BIN) --mcp | grep -q 'eta_seconds' && echo "PASS: MCP bar_eta"
	@echo "=== testing MCP tools/call bar_stats ==="
	@printf '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"bar_stats","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q 'styles_count' && echo "PASS: MCP bar_stats"
	@echo "ALL TESTS PASSED"

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oobar
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oobar-uninstall
	@echo "installed oobar and oobar-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oobar $(DESTDIR)$(BINDIR)/oobar-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oobar $(HOME)/.config/oobar; echo "purged user cache and config"; fi
	@echo "uninstalled oobar and oobar-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oobar
	@chmod 0755 dist/deb-root/usr/bin/oobar
	@cp uninstall.sh dist/deb-root/usr/bin/oobar-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oobar-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oobar_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oobar_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oobar-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oobar.spec > ~/rpmbuild/SPECS/oobar.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oobar.spec
	@cp ~/rpmbuild/RPMS/x86_64/oobar-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oobar
	@chmod 0755 dist/arch-pkg/usr/bin/oobar
	@cp uninstall.sh dist/arch-pkg/usr/bin/oobar-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oobar-uninstall
	@printf "pkgname = oobar\npkgbase = oobar\npkgver = $(VERSION)-1\npkgdesc = Renders smooth terminal progress bars with ETA, throughput, and percent gauges.\nurl = https://github.com/openOODA-tools/oobar\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oobar\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oobar-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oobar-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cd dist && sha256sum oobar* > checksums.txt 2>/dev/null || true
	@echo "built all packages and dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
