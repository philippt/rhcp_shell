# Generated from rhcp_shell-0.0.11.gem by gem2rpm -*- rpm-spec -*-
%define ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemname rhcp_shell
%define geminstdir %{gemdir}/gems/%{gemname}-%{version}

Summary: RHCP is a protocol designed for building up a command-metadata-based communication infrastructure making it easier for application developers to export commands in applications to generic clients - this is the generic shell for it
Name: rubygem-%{gemname}
Version: 0.2.13
Release: 1%{?dist}
Group: Development/Languages
License: GPLv2+ or Ruby
URL: http://rubyforge.org/projects/rhcp
Source0: %{gemname}-%{version}.gem
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires: rubygems
Requires: rubygem-rhcp >= 0.2.10
BuildRequires: rubygems
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
RHCP is a protocol designed for building up a command-metadata-based
communication infrastructure making it easier for application developers to
export commands in applications to generic clients - this is the generic shell
for it.


%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gemdir}
gem install --local --install-dir %{buildroot}%{gemdir} \
            --force --rdoc %{SOURCE0}
mkdir -p %{buildroot}/%{_bindir}
mv %{buildroot}%{gemdir}/bin/* %{buildroot}/%{_bindir}
rmdir %{buildroot}%{gemdir}/bin
find %{buildroot}%{geminstdir}/bin -type f | xargs chmod a+x

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%{_bindir}/rhcp_shell
%{gemdir}/gems/%{gemname}-%{version}/
%doc %{gemdir}/doc/%{gemname}-%{version}
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec


%changelog
* Fri Apr 22 2011 xop <philipp@xop-consulting.com> - 0.2.13-1
- bugfix: the request constructor was inadvertently modifying parameter values.
* Wed Feb 16 2011 xop <philipp@xop-consulting.com> - 0.2.11-1
- added support for setting the prompt through a cookie
- added color support for result status
* Fri Sep 10 2010 xop <philipp@xop-consulting.com> - 0.2.10-3
- disabling the MemcachedBroker for lookups for now; can be activated from outside
* Fri Sep 10 2010 xop <philipp@xop-consulting.com> - 0.2.10-2
- new local command 'show_context', adapted to new context/broker approach from rhcp 0.2.10-2
* Thu Sep 09 2010 xop <philipp@xop-consulting.com> - 0.2.10-1
- starting to refactor the rhcp_shell_backend; pulled out local commands and display formatting
- bugfix: wrong parameter values shouldn't cause the shell to commit suicide
- added memcached broker for lookup values
- bugfix for syntax of multiple parameters in help screen
* Mon Jul 12 2010 xop <philipp@xop-consulting.com> - 0.2.9-1
- 'exit' should work again now
- hopefully improved error handling on invalid parameter values
* Mon Jun 07 2010 xop <philipp@xop-consulting.com> - 0.2.8-1
- minor changes for rhcp 0.2.7
* Sat May 01 2010 xop <philipp@xop-consulting.com> - 0.2.4-1
- migrated to rhcp 0.2.4
- deactivated unused wildcard support to avoid extra lookups
- added spec file to subversion
* Sun Apr 25 2010 xop <philipp@xop-consulting.com> - 0.2.1-1
- shell is working with rhcp 0.2.2 now; fixed accidental wildcard extension bug
- storing the already collected param values in the context aware broker now
* Sun Feb 21 2010 xop <xop@xop-consulting.com> - 0.0.11-1
- Initial package
