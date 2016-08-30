#! /bin/env ruby

require 'rexml/document'

COMMAND_COLUMN   = 'column'  .freeze
COMMAND_SCAFFOLD = 'scaffold'.freeze
COMMAND_DATA     = 'data'    .freeze
ALL_COMMANDS = [COMMAND_COLUMN, COMMAND_SCAFFOLD, COMMAND_DATA]

USAGE = "Usage: COMMAND column   LIBRARY.xml\n" \
      + "       COMMAND scaffold COLUMNS.txt\n" \
      + "       COMMAND [data]   COLUMNS.txt LIBRARY.xml"

if ARGV.empty?
  STDERR.puts USAGE
  exit
end

command = COMMAND_DATA
if ALL_COMMANDS.include?(ARGV[0])
  command = ARGV.shift
end

def get_filename
  filename = ARGV.shift
  if filename.nil?
    STDERR.puts USAGE
    exit
  elsif ! File.exist?(filename)
    STDERR.puts "Cannot find file '#{filename}'"
    STDERR.puts USAGE
    exit
  end
  filename
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

if command == COMMAND_DATA || command == COMMAND_SCAFFOLD
  column_names_and_types = File.binread(get_filename).split("\n")
end

if command == COMMAND_COLUMN || command == COMMAND_DATA
  xml_doc = File.open(get_filename) { |f| REXML::Document.new(f) }
  whole_dict = xml_doc.root.find_child_by_name(:dict)
  tracks = whole_dict.find_child_by_name_and_text(:key, :Tracks)
  track_dict = tracks.find_next_sibling_by_name(:dict)
  tracks = track_dict.find_all_children_by_name(:dict)
end

if command == COMMAND_SCAFFOLD
  puts column_names_and_types.map { |c| c.downcase.gsub(/\s+/, '_') }.join(' ')
elsif command == COMMAND_DATA
  column_names = column_names_and_types.map { |x| x.split(':').first }
  puts (%w(id) + column_names + %w(created_at updated_at)).map { |x| x.downcase.gsub(/\s+/, '_') }.join("\t")

  now = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  tracks.each_with_index do |track, index|
    values = column_names.map { |name|
      element = track.find_child_by_name_and_text(:key, name)
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

  puts columns.join("\n")
end
