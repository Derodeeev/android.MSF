#!/usr/bin/ruby
require 'rubygems'
require 'rubygems/spec_fetcher'
begin
  require 'diff_match_patch_native'
rescue LoadError
  abort "gem 'diff_match_patch_native' required"
end
begin
  require 'json'
rescue LoadError
  abort "gem 'json' required"
end

USAGE = "Usage: #{$0} msf_directory"

msfDir = ARGV[0].sub /\/*$/, ""

abort USAGE if msfDir == nil or !(File.directory? msfDir)

result = {}

original = File.read("#{msfDir}/Gemfile")
patched = original.gsub(/source.*rubygems\.org.*$/,
                        "\\0\nsource 'http://gems.dsploit.net/'")

dmp = DiffMatchPatch.new

patch = dmp.patch_make(original, patched)

result['Gemfile'] = dmp.patch_to_text(patch)

fetcher = Gem::SpecFetcher::fetcher
fetcher.sources.clear
our_source = Gem::Source.new 'http://gems.dsploit.net'
fetcher.sources << our_source
remote_gems, _ = fetcher.available_specs :latest
remote_gems = remote_gems[our_source]

spec_files = Dir["#{msfDir}/**/*.gemspec"]

spec_files.each do |f|

  original = File.read(f)
  
  patched = original.gsub(/`git\s*ls-files`.split\(\$\/\)/,
                "Dir[\"**/*\"].reject {|f| File.directory?(f) }")
  
  remote_gems.each do |g|
    patched.gsub!(/spec.add_runtime_dependency\s+'#{g.name}'.*/,
                  "spec.add_runtime_dependency '#{g.name}', '#{g.version}'")
  end

  patch = dmp.patch_make(original, patched)
  
  next if patch.size == 0
  
  path = f[msfDir.size+1..-1]
  result[path] = dmp.patch_to_text(patch)
  
end

out = {}

out['url'] = "https://github.com/rapid7/metasploit-framework/archive/TAG.zip"
out['files'] = result

puts out.to_json
