GEMSPEC = Gem::Specification.new do |s|
    s.name = "batch"
    s.version = "0.2"
    s.authors = ["Adam Gardiner"]
    s.date = "2017-06-22"
    s.summary = "Batch is a framework for creating batch jobs with support for logging, configuration, and process management."
    s.description = <<-EOQ
        Batch is a framework that provides a number of capabilities to make the creation of jobs simpler,
        and the running of jobs robust and simple to monitor."
    EOQ
    s.email = "adam.b.gardiner@gmail.com"
    s.homepage = 'https://github.com/agardiner/batch'
    s.require_paths = ['lib']
    s.files = ['README.md', 'LICENSE'] + Dir['lib/**/*.rb']
    s.has_rdoc = 'yard'
end
