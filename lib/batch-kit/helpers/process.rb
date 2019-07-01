require 'shellwords'
require 'open3'

require_relative '../logging'


class BatchKit

    module Helpers

        # Provides support for running an external process.
        # This support consists of support for:
        # - launching the process as a child
        # - capturing the output of the process and logging it
        # - handling the return code of the process, and raising an exception for
        #   failures.
        module Process

            # Provides a means for executing a command-line.
            #
            # @param cmd_line [String] The command-line that is to be launched.
            # @param options [Hash] An options hash.
            # @option options [Proc] :callback If specified, the supplied Proc will
            #   be invoked for each line of output produced by the process.
            # @option options [Proc] :input If specified, the supplied Proc will
            #   be invoked for each line of output produced by the process. It will
            #   be passed the pipe on which input for the process can be written,
            #   plus the last line of output produced. This is useful in cases where
            #   it is necessary to communicate with the child process via its STDIN.
            # @return [Fixnum] The exit status code from the external process.
            def popen(cmd_line, options = {}, &block)
                callback = options[:callback]
                input = options[:input]
                IO.popen(cmd_line, input ? 'r+' : 'r') do |pipe|
                    while !pipe.eof?
                        line = pipe.gets.chomp
                        input.call(pipe, line) if input
                        callback.call(line) if callback
                        block.call(line) if block_given?
                    end
                end
                $?.exitstatus
            end
            module_function :popen


            # Launch an external process with logging etc. By default, an exception
            # will be raised if the process returns a non-zero exit code.
            #
            # @param cmd_line [String, Array<String>] The command-line to be run,
            #   in the form of either a single String, or an Array of Strings.
            # @param options [Hash] An options hash.
            # @option options [Boolean] :raise_on_error If true (default), an
            #   exception is raised if the return code is not a success code.
            # @option options [Fixnum, Array<Fixnum>] The return code(s) that the
            #   process can return if successful (default 0).
            # @option options [Boolean] :show_duration If true (default), logs the
            #   duration taken by the process.
            # @option options [Logger] :logger The logger to use; defaults to using
            #   a logger named after the process being executed.
            def launch(cmd_line, options = {}, &block)
                exe = cmd_line.is_a?(String) ?
                    File.basename(Shellwords.shellwords(cmd_line.gsub(/\\/, '/')).first) :
                    File.basename(cmd_line.first)

                raise_on_error = options.fetch(:raise_on_error, true)
                show_duration = options.fetch(:show_duration, true)
                success_code = options.fetch(:success_code, 0)
                log = options.fetch(:logger, BatchKit::LogManager.logger(exe))
                log_level = options.fetch(:log_level, :detail)
                unless block_given? || options[:callback]
                    options = options.dup
                    options[:callback] = lambda{ |line| log.send(log_level, line) }
                end

                log.trace("Executing command line: #{cmd_line}") if log
                begin
                    start = Time.now
                    rc = popen(cmd_line, options, &block)
                ensure
                    if log && show_duration
                        log.detail "#{exe} completed in #{Time.now - start} seconds with exit code #{rc}"
                    end
                end

                if raise_on_error
                    ok = case success_code
                    when Fixnum then success_code == rc
                    when Array then success_code.include?(rc)
                    end
                    raise "#{exe} returned failure exit code #{rc}" unless ok
                end
                rc
            end
            module_function :launch

        end

    end

end
