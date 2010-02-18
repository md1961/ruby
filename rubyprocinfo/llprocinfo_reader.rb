
require 'socket'


DEFAULT_HOSTNAME = 'locus'
DEFAULT_PORT     = 15963

TIMEOUT_SEC = 1

READY = '220 READY'
COMMAND = 'procinfo'


class LLprocinfoReader
  def initialize(hostname=nil, port=nil)
    if hostname.nil?
      hostname = DEFAULT_HOSTNAME
    end
    if port.nil?
      port = DEFAULT_PORT
    end

    @soc = TCPSocket.open(hostname, port)
  end

  def iterator
    prompt = @soc.gets

    if prompt[0, READY.length] == READY
      @soc.puts(COMMAND)
      #sleep 0.1
      return Iterator.new(@soc)
    end

    return nil
  end

  class Iterator
    def initialize(soc)
      @soc = soc
    end

    def each
      @soc.each do |line|
        yield line
      end
    end
  end
end


if __FILE__ == $0
  hostname = ARGV[0]
  if hostname.nil? || hostname.empty?
    reader = LLprocinfoReader.new
  else
    reader = LLprocinfoReader.new(hostname)
  end

  iter = reader.iterator
  if iter.nil?
    puts "Failed to get llprocinfo from host '#{hostname}'"
  else
    iter.each do |line|
      puts line
    end
  end
end

