GEMSPEC = Gem::Specification.new do |s|
    s.name = "batch-kit"
    s.version = "0.3"
    s.authors = ["Adam Gardiner"]
    s.date = "2019-07-01"
    s.summary = "BatchKit is a framework for creating batch jobs with support for logging, configuration, and process management."
    s.description = <<-EOQ
        BatchKit is a framework that provides a number of capabilities to make the creation of batch jobs simpler,
        and the running of jobs robust and simple to monitor."
    EOQ
    s.email = "adam.b.gardiner@gmail.com"
    s.homepage = 'https://github.com/agardiner/batch-kit'
    s.require_paths = ['lib']
    s.add_runtime_dependency 'arg-parser', '~> 0.3'
    s.add_runtime_dependency 'color-console', '~> 0.3'
    s.files = ['README.md', 'LICENSE'] + Dir['lib/**/*.rb']
    s.has_rdoc = 'yard'
    s.license = 'BSD-2-Clause'
end
