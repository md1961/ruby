# Minimal sample configuration file for Unicorn (not Rack) when used
# with daemonization (unicorn -D) started in your working directory.
#
# See http://unicorn.bogomips.org/Unicorn/Configurator.html for complete
# documentation.
# See also http://unicorn.bogomips.org/examples/unicorn.conf.rb for
# a more verbose configuration using more features.


# Please prepare file 'config/unicorn_port' which has only port No. in it

PORT_NUMBER_FILE = "config/unicorn_port"

working_directory(File.dirname(__FILE__) + "/..")

listen `cat #{PORT_NUMBER_FILE}`.chomp # by default Unicorn listens on port 8080
worker_processes 2 # this should be >= nr_cpus
pid "tmp/pids/unicorn.pid"
stderr_path "log/unicorn.log"
stdout_path "log/unicorn.log"

