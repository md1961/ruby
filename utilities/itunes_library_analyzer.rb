#! /bin/env ruby

require 'rexml/document'

COMMAND_COLUMN   = 'column'  .freeze
COMMAND_SCAFFOLD = 'scaffold'.freeze
COMMAND_DATA     = 'data'    .freeze
ALL_COMMANDS = [COMMAND_COLUMN, COMMAND_SCAFFOLD, COMMAND_DATA]

USAGE = "Usage: #{$0} [column|scaffold|[data]] LIBRARY.xml"

if ARGV.empty?
  STDERR.puts USAGE
  exit
end

command = COMMAND_DATA
if ALL_COMMANDS.include?(ARGV[0])
  command = ARGV.shift
end

filename = ARGV.shift
if filename.nil?
  STDERR.puts USAGE
  exit
elsif ! File.exist?(filename)
  STDERR.puts "Cannot file file '#{filename}'"
  STDERR.puts USAGE
  exit
end

doc = File.open(filename) do |f|
  REXML::Document.new(f)
end

module REXML::Node
  def find_child_by_name(name)
    children.find { |n| n.respond_to?(:name) && n.name == name.to_s }
  end

  def find_child_by_name_and_text(name, text)
    children.find { |n| n.respond_to?(:name) && n.name == name.to_s && n.text == text.to_s }
  end

  def find_all_children_by_name(name)
    children.select { |n| n.respond_to?(:name) && n.name == name.to_s }
  end

  def find_next_sibling_by_name(name)
    n = self
    while n = n.next_sibling_node
      return n if n.respond_to?(:name) && n.name == name.to_s
    end
    nil
  end
end

whole_dict = doc.root.find_child_by_name(:dict)
tracks = whole_dict.find_child_by_name_and_text(:key, :Tracks)
track_dict = tracks.find_next_sibling_by_name(:dict)
tracks = track_dict.find_all_children_by_name(:dict)

COLUMN_NAMES_AND_TYPES = [
  'Track ID:integer',
  'Name:string',
  'Artist:string',
  'Album Artist:string',
  'Composer:string',
  'Album:string',
  'Genre:string',
  'Kind:string',
  'Size:integer',
  'Total Time:integer',
  'Start Time:integer',
  'Disc Number:integer',
  'Disc Count:integer',
  'Track Number:integer',
  'Track Count:integer',
  'Year:integer',
  'BPM:integer',
  'Date Modified:date',
  'Date Added:date',
  'Bit Rate:integer',
  'Sample Rate:integer',
  'Comments:string',
  'Volume Adjustment:integer',
  'Play Count:integer',
  'Play Date:integer',
  'Play Date UTC:date',
  'Skip Count:integer',
  'Skip Date:date',
  'Release Date:date',
  'Rating:integer',
  'Album Rating:integer',
  'Album Rating Computed:true',
  'Normalization:integer',
  'Sort Album Artist:string',
  'Compilation:true',
  'Artwork Count:integer',
  'Sort Artist:string',
  'Sort Composer:string',
  'Sort Album:string',
  'Sort Name:string',
  'Persistent ID:string',
  'Disabled:true',
  'Track Type:string',
  'Protected:true',
  'Purchased:true',
  'Has Video:true',
  'HD:false',
  'Video Width:integer',
  'Video Height:integer',
  'Music Video:true',
  'File Type:integer',
  'Location:string',
  'File Folder Count:integer',
  'Library Folder Count:integer',
]

if command == COMMAND_DATA
  column_names = COLUMN_NAMES_AND_TYPES.map { |x| x.split(':').first }
  puts (%w(id) + column_names + %w(created_at updated_at)).map { |x| x.downcase.gsub(/\s+/, '_') }.join("\t")

  now = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  tracks.each_with_index do |track, index|
    values = column_names.map { |name|
      element = track.find_child_by_name_and_text(:key, name)
      element && element.next_element.text
    }
    STDERR.puts "#{values.size} columns at line #{index+1}" if values.size != column_names.size
    values.unshift index + 1
    values << now << now
    puts values.join("\t")
  end
else
  columns = []
  tracks.each do |track|
    next_columns = track.find_all_children_by_name(:key).map { |e|
      name = e.text
      n = e.next_element
      type = n.name
      type = 'boolean' if %w(true false).include?(type)
      value = n.text
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

  if command == COMMAND_COLUMN
    puts columns.join("\n")
  else
    puts columns.map { |c| c.downcase.gsub(/\s+/, '_') }.join(' ')
  end
end
