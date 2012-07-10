class ReverseLineReader
  def initialize(io)
    @io = io
    @io.seek(0, IO::SEEK_END)
    @buffer = ""
  end

  def each
    separator = $/
    separator_length = separator.length
    while read_to_buffer
      loop do
        index = @buffer.rindex(separator, @buffer.length - 1 - separator_length)
        break if index.nil? or index.zero?
        last_line = @buffer.slice!((index + separator_length)..-1)
        yield(last_line)
      end
    end
    yield(@buffer) unless @buffer.empty?
  end

  private
  BYTES_PER_READ = 4096
  def read
    position = @io.pos
    if position < BYTES_PER_READ
      bytes_per_read = position
    else
      bytes_per_read = BYTES_PER_READ
    end

    retval = ''
    unless bytes_per_read.zero?
      @io.seek(-bytes_per_read, IO::SEEK_CUR)
      @io.read(bytes_per_read, retval)
      @io.seek(-bytes_per_read, IO::SEEK_CUR)
    end

    retval
  end

  def read_to_buffer
    data = read
    if data.empty?
      false
    else
      @buffer.insert(0, data)
      true
    end
  end
end
