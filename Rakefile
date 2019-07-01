require 'rubygems'
require 'rubygems/package_task'

load 'batch-kit.gemspec'

Gem::PackageTask.new(GEMSPEC) do |pkg|
    pkg.need_tar = false
end

task :default => :gem
