Name:           oobar
Version:        0.1.0
Release:        1%{?dist}
Summary:        Renders smooth terminal progress bars with ETA, throughput, and percent gauges.
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oobar
Source0:        oobar-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
oobar is a sovereign, capability-bounded PROGRESS METER written
in pure openOODA, featuring zero ambient authority, oote color themes,
and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oobar
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/oobar-uninstall

%files
/usr/bin/oobar
/usr/bin/oobar-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign blueprint scaffolding
