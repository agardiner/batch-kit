# Batch

Batch is a framework for creating batch jobs: Ruby programs that are simple to
write, but which are:

- __Robust__: Batch jobs handle any uncaught exceptions gracefully, ensuring the
  exception is reported, resources are freed, and the job itself exits with a
  non-zero error code.
- __Configurable__: It should be easy to define the command-line arguments the job
  can take, and it should also be possible to provide configuration files for
  a job in either property or YAML format.
- __Secure__: Configuration files support encryption of sensitive items such as
  passwords.
- __Measured__: Batch jobs can use a database to gather statistics of runs, such as
  the number of runs of each job, the average, minimum, and maximum duration,
  arguments passed to the job, etc.

To provide these capabilities, the batch framework provides:

- A job framework, which can be used to turn any class into a batch job. This
  can be done either by extending the {Batch::Job} class, or by including the
  {Batch::ActsAsJob} module. The job framework allows for new or existing job
  and task methods to be created. Both job and task methods add 
  {https://en.wikipedia.org/wiki/Advice_(programming) advices} that wrap
  the logic of the method with exception handlers, as well as gathering
  statistics about the status and duration of the task or job. These can be
  persisted to a database for job reporting.

- A facade over the Log4r and java.util.logging log frameworks, allowing
  sophisticated logging with colour output to the console, and persistent
  output to log files and the database.

- A configuration class ({Batch::Config}), which supports either property or
  YAML-based configuration files. The {Batch::Config} class extends Hash,
  providing:

    + __Flexible Access__: keys are case-insensitive, can be accessed using either
      strings or symbols, and can be accessed using Batch::Config#[] or accessor-
      style methods
    + __Support for Placeholder Variables__: substitution variables can be used in
      the configuration file, and will be expanded either from higher-level
      properties in the configuration tree, or left to be resolved at a later
      time.
    + __Encryption__: any property value can be encrypted, and will be stored in
      memory in encrypted form, and only be decrypted when accessed explicitly.
      Encryption is performed using AES-128 bit encryption via a separate
      master key (which should not be stored in the same configuration file).

- A resource manager class that can be used to ensure the cleanup of any
  resource that has an acquire/release pair of methods. Use of the
  {Batch::ResourceManager} class ensures that a job releases all resources in
  both success and error outcomes. Support is also provided for locking
  resources, such that concurrent or discrete jobs that share a resource can
  coordinate their use.

- Helpers: helper modules are provided for common batch tasks, such as zipping
  files, sending emails, archiving files etc.

## Example Usage

The simplest way to use the batch framework is to create a class for your job
that extends the {Batch::Job} class.

```
require 'batch/job'

class MyJob < Batch::Job
```

Next, use the {Batch::Configurable::ClassMethods#configure configure} method to
add any configuration file(s) your job needs to read to load configuration
settings that control its behaviour:

```
configure 'my_config.yaml'
```

The job configuration is now available from both the class itself, and instances
of the class, via the {Batch::Job.config #config} method. Making the configuration
available from the class allows it to be used while defining the class, e.g. when
defining default values for command-line arguments your job provides.

Command-line arguments are supported in batch jobs via the use of the
{https://github.com/agardiner/arg-parser arg-parser} gem. This provides a
DSL for defining various different kinds of command-line arguments:

```
positional_arg :spec, 'A path to a specification file',
    default: config.default_spec
flag_arg :verbose, 'Output more details during processing'
```

When your job is run, you will be able to access the values supplied on the
command line via the job's provided {Batch::Job#arguments #arguments} accessor.

```
if arguments.verbose
    # Do something verbosely
end
```

We now come to the meat of our job - the tasks it is going to perform when
run. Tasks are simply methods, but have added functionality wrapped around
them. To define a task, there are two approaches that can be used:

```
desc 'A one-line description for my task'
task :method1 do |param1|
    # Define the steps this method is to perform
    ...
end

def method2(param1, param2)
    # Another task method
    ...
end
task :method2, 'A short description for my task method'
```

Both methods are equivalent, and both leave your class with a method named
for the task (which is then invoked like any other method) - so use
whichever appraoch you prefer.

While performing actions in your job, you can make use of the {Batch::Job#log #log}
method to output logging at various levels:

```
log.config "Spec: #{arguments.spec}"
log.info "Doing some work now"
log.detail "Here are some more detailed messages about what we are doing"
log.warn "Oh-oh, looks like trouble ahead"
log.error "Oh no, an exception has occurred!"
```

Finally, we need a method that will act as the main entry point to the job. We
define a job method much like a task, but there should only be one job method
in our class:

```
job 'This job does XYZ' do
    p1, p2, p3 = ...
    method1(p1)
    method2(p2, p3)
end
```

As with tasks, we can use the {Batch::ActsAsJob#job #job} DSL method above to define
the main entry method, or we can pass a symbol identifying an existing method
in our class to be the job entry point.

Finally, to allow our job to run when it is passed as the main program to the
Ruby engine, we call the {Batch::Job.run run} method on our class at the end of our script:

```
MyJob.run
```

This instructs the batch framework to instantiate our job class, parse any
command-line arguments, and then invoke our job entry method to start processing.

