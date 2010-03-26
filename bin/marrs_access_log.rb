#! /bin/env ruby

# Script to perform 'ls -lrt' on files of which filename match a specific grep pattern
# in a specific directory 
IO.popen("find /etc/httpd/logs/ | grep access_log | xargs ls -rt") do |line|
  puts line
end

