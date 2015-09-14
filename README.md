# Batch

Batch is a framework for creating batch jobs: Ruby programs that are simple to
write, but which are:

- Robust: Batch jobs handle any uncaught exceptions gracefully, ensuring the
  exception is reported, resources are freed, and the job itself exits with a
  non-zero error code.
- Configurable: It should be easy to define the command-line arguments the job
  can take, and it should also be possible to provide configuration files for
  a job in either property or YAML format.
- Secure: Configuration files support encryption of sensitive items such as
  passwords.
- Measured: Batch jobs can use a database to gather statistics of runs, such as
  the number of runs of each job, the average, minimum, and maximum duration,
  arguments passed to the job, etc.

To provide these capabilities, the batch framework provides:

- A job framework, which can be used to turn any class into a batch job. This
  can be done either by extending the Batch::Job class, or by including the
  Batch::ActsAsJob module. The job framework allows for new or existing job
  and task methods to be created. Both job and task methods add aspects that
  wrap the logic of the method with exception handlers, as well as gathering
  statistics about the status and duration of the task or job. These can be
  persisted to a database for job reporting.

- A facade over the Log4r and java.util.logging log frameworks, allowing
  sophisticated logging with colour output to the console, and persistent
  output to log files and the database.

- A configuration class (Batch::Config), which supports either property or
  YAML-based configuration files. The Config class extends Hash, providing:

    + Flexible Access: keys are case-insensitive, can be accessed using either
      Strings or Symbols, and can be accessed using [] or accessor-style methods
    + Support for Placeholder Variables: substitution variables can be used in
      the configuration file, and will be expanded either from higher-level
      properties in the configuration tree, or left to be resolved at a later
      time.
    + Encryption: any property value can be encrypted, and will be stored in
      memory in encrypted form, and only be decrypted when accessed explicitly.
      Encryption is performed using AES-128 bit encryption via a separate
      master key (which should not be stored in the same configuration file).

- A resource manager class that can be used to ensure the cleanup of any
  resource that has an acquire/release pair of methods. Use of the
  Batch::ResourceManager class ensures that a job releases all resources in
  both success and error outcomes. Support is also provided for locking
  resources, such that concurrent or discrete jobs that share a resource can
  coordinate their use.

- Helpers: helper modules are provided for common batch tasks, such as zipping
  files, sending emails, archiving files etc.

