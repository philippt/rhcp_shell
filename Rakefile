require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'rubygems'
require 'rake/gempackagetask'
require 'rubyforge'

$LOAD_PATH.push('lib')
require File.join(File.dirname(__FILE__), 'lib', 'version')

PKG_NAME = 'rhcp_shell'
PKG_VERSION = RhcpShell::Version.to_s
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

desc "Default Task"
task :default => [ :test ]

###############################################
### TESTS
Rake::TestTask.new() { |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
}

###############################################
### RDOC
Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "RHCP Shell"
  rdoc.options << '--line-numbers' << '--inline-source' <<
    '--accessor' << 'cattr_accessor=object'
  rdoc.template = "#{ENV['template']}.rb" if ENV['template']
  #rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
}

###############################################
### METRICS
task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  for file_name in FileList["lib/**/*.rb"]
    f = File.open(file_name)

    while line = f.gets
      lines += 1
      next if line =~ /^\s*$/
      next if line =~ /^\s*#/
      codelines += 1
    end
    puts "L: #{sprintf("%4d", lines)}, LOC #{sprintf("%4d", codelines)} | #{file_name}"
    
    total_lines     += lines
    total_codelines += codelines
    
    lines, codelines = 0, 0
  end

  puts "Total: Lines #{total_lines}, LOC #{total_codelines}"
end

task :coverage do
  system "rcov -I lib/ -I test/ -x rcov.rb -x var/lib -x lib/shell_backend.rb  test/*test.rb"
end


spec = Gem::Specification.new do |s|
    s.rubyforge_project = "rhcp"
    s.name       = PKG_NAME
    s.version    = PKG_VERSION
    s.author = "Philipp Traeder"
    s.email      = "philipp at hitchhackers.net"
    s.homepage   = "http://rubyforge.org/projects/rhcp"
    s.platform   = Gem::Platform::RUBY
    s.summary    = "RHCP is a protocol designed for building up a command-metadata-based communication infrastructure making it easier for application developers to export commands in applications to generic clients - this is the generic shell for it."
    s.files      = FileList["{bin,docs,lib,test}/**/*"].exclude("rdoc").to_a
    s.require_path      = "lib"
    s.has_rdoc          = true
    s.add_dependency('rhcp', '>= 0.1.9')
    s.bindir = 'bin'
    s.executables = 'rhcp_shell'
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end

desc 'package the gem and upload it to RubyForge'
task :upload_gem => [:package] do
  rf = RubyForge.new.configure
  rf.login
  rf.add_release("rhcp", PKG_NAME, PKG_VERSION, File.join("pkg", "#{PKG_FILE_NAME}.gem"))
end
