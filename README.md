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



