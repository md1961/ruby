#! /bin/env ruby

require 'nokogiri'

COMMAND_COLUMN   = 'column'  .freeze
COMMAND_SCAFFOLD = 'scaffold'.freeze
COMMAND_DATA     = 'data'    .freeze
ALL_COMMANDS = [COMMAND_COLUMN, COMMAND_SCAFFOLD, COMMAND_DATA]

USAGE = "Usage: COMMAND column   LIBRARY.xml\n" \
      + "       COMMAND scaffold COLUMNS.txt\n" \
      + "       COMMAND [data]   COLUMNS.txt LIBRARY.xml"

def print_usage_and_exit
  STDERR.puts USAGE
  exit
end

if ARGV.empty?
  print_usage_and_exit
end

command = COMMAND_DATA
if ALL_COMMANDS.include?(ARGV[0])
  command = ARGV.shift
end

def get_filename
  filename = ARGV.shift
  if filename.nil?
    print_usage_and_exit
  elsif ! File.exist?(filename)
    STDERR.puts "Cannot find file '#{filename}'"
    print_usage_and_exit
  end
  filename
end

if command == COMMAND_DATA || command == COMMAND_SCAFFOLD
  column_names_and_types = File.binread(get_filename).split("\n")
end

=begin
  ### Target XML format
  <plist>
    <dict>
      ...
      <key>Tracks</key>
      <dict>
        <key>1847</key>
->      <dict>
->        <key>Track ID</key><integer>1847</integer>
->        <key>Name</key><string>Johnny Don't Do It</string>
->        <key>Artist</key><string>(ten) 10cc</string>
->        ...
->      </dict>
->      ...
      </dict>
      ...
    </dict>
  </plist>
=end
if command == COMMAND_COLUMN || command == COMMAND_DATA
  xml_doc = File.open(get_filename) { |f| Nokogiri::XML::Document.parse(f) }
  tracks_key = xml_doc   .xpath("/plist/dict/key[.='Tracks']").first
  track_dict = tracks_key.xpath('following-sibling::dict'    ).first
  tracks     = track_dict.xpath('dict')
end

if command == COMMAND_SCAFFOLD
  puts column_names_and_types.map { |c| c.downcase.gsub(/\s+/, '_') }.join(' ')
elsif command == COMMAND_DATA
  column_names = column_names_and_types.map { |x| x.split(':').first }
  puts (%w(id) + column_names + %w(created_at updated_at)).map { |x| x.downcase.gsub(/\s+/, '_') }.join("\t")

  now = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  tracks.each_with_index do |track, index|
    values = column_names.map { |name|
      element = track.xpath("key[.='#{name}']").first
      if element.nil?
        nil
      else
        value_element = element.next_element
        if %w(true false).include?(value_element.name)
          value_element.name
        else
          value_element.text
        end
      end
    }
    STDERR.puts "#{values.size} columns at line #{index+1}" if values.size != column_names.size
    values.unshift index + 1
    values << now << now
    puts values.join("\t")
  end
else
  columns = []
  tracks.each do |track|
    next_columns = track.xpath('key').map { |element|
      name = element.text
      value_element = element.next_element
      type = value_element.name
      type = 'boolean' if %w(true false).include?(type)
      value = value_element.text
      "#{name}:#{type}"
    }
    new_columns = next_columns - columns
    new_columns.each do |new_column|
      index = next_columns.index(new_column)
      column_before = index == 0 ? nil : next_columns[index - 1]
      unless column_before
        columns.unshift(new_column)
      else
        index = columns.index(column_before)
        columns.insert(index + 1, new_column)
      end
    end
  end

  puts columns.join("\n")
end
