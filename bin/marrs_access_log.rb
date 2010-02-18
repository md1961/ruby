#! /bin/env ruby

IO.popen("find /etc/httpd/logs/ | grep access_log | xargs ls -rt") do |line|
  puts line
end
#| xargs egrep --no-filename 'GET /flex/(marrs|main)\.(html|swf)' | cut -d- -f1,2,3
