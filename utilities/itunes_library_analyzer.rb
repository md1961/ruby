#! /bin/env ruby

require 'rexml/document'

doc = File.open(ARGV[0]) do |f|
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
  'Composer:string',
  'Album:string',
  'Genre:string',
  'Kind:string',
  'Size:integer',
  'Total Time:integer',
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
#  'Skip Count:integer',
#  'Skip Date:date',
#  'Album Rating:integer',
#  'Album Rating Computed:boolean',
#  'Normalization:integer',
#  'Artwork Count:integer',
#  'Persistent ID:string',
#  'Track Type:string',
#  'File Type:integer',
#  'Location:string',
#  'File Folder Count:integer',
]

if false
  puts COLUMN_NAMES_AND_TYPES.map { |x| x.downcase.gsub(/\s+/, '_') }.join(' ')

  column_names = COLUMN_NAMES_AND_TYPES.map { |x| x.split(':').first }
  now = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  tracks.each_with_index do |track, index|
    values = column_names.map { |name|
      element = track.find_child_by_name_and_text(:key, name)
      element && element.next_element.text
    }
    values.unshift index + 1
    values << now << now
    STDERR.puts "#{values.size} columns at line #{index+1}" if values.size != 22
    puts values.join("\t")
  end
end

if true
  columns = []
  tracks.each do |track|
    columns |= track.find_all_children_by_name(:key).map { |e|
      name = e.text
      n = e.next_element
      type = n.name
      value = n.text
      "#{name}:#{type}"
    }
  end
end
puts columns.join("\n")

if false
  puts tracks.map { |e|
    e.find_child_by_name_and_text(:key, :Album).find_next_sibling_by_name(:string).text
  }.uniq
end
