$LOAD_PATH.push('lib')
require File.join(File.dirname(__FILE__), 'lib', 'rhcp_shell', 'version')

spec = Gem::Specification.new do |s|
    s.name       = "rhcp_shell"
    s.version    = RhcpShell::Version.to_s
    s.author = "Philipp T."
    s.email      = "philipp at virtualop dot org"
    s.homepage   = "http://rubyforge.org/projects/rhcp"
    s.platform   = Gem::Platform::RUBY
    s.summary    = "command line shell for RHCP"
    s.description    = "command line shell for RHCP"
    s.files      = Dir["{bin,docs,lib,test}/**/*"].select { |x| x != "rdoc" }.to_a
    s.require_path      = "lib"
    s.has_rdoc          = true
    s.add_dependency('rhcp', '>= 0.1.9')
    s.bindir = 'bin'
    s.executables = 'rhcp_shell'
end