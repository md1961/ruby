#! /bin/env ruby

require 'tempfile'
require_relative 'rails_util'

require 'active_support'
require 'active_support/core_ext'


unless RailsUtil.rails_dir?
  STDERR.puts "Quit execution as you're not in a Rails root directory."
  exit
end

unless RailsUtil.git_repository?
  STDERR.puts "Quit execution as you're not in a git repository."
  exit
end

if ARGV.size <= 0
  STDERR.puts "Specify at least model name."
  STDERR.puts "Usage: #{File.basename $0} model_name [field[:type][:index] field[:type][:index]]"
  exit
end

model_name = ARGV.first

DIR_SOURCE = File.expand_path(File.join(File.dirname(__FILE__), 'files_for_generate_scaffold')).freeze


# Copy .vimrc

VIMRC_FILENAME = '.vimrc'.freeze

FileUtils.cp(File.join(DIR_SOURCE, VIMRC_FILENAME), '.') unless File.exist?(VIMRC_FILENAME)


# Add generator configurations

DIR_CONFIG = 'config'.freeze
TARGET_CONFIG_FILENAME = 'application.rb'.freeze
GENERATOR_CONFIG = 'generator_config.rb'.freeze

target_file = File.join(DIR_CONFIG, TARGET_CONFIG_FILENAME)
f_tmp = Tempfile.open(TARGET_CONFIG_FILENAME)
indent = ''
File.open(target_file, 'r') do |f|
  f.each do |line|
    if line =~ /\A(\s*)class Application/
      indent = Regexp.last_match(1)
    elsif line =~ /\A#{indent}end\s*\z/
      File.open(File.join(DIR_SOURCE, GENERATOR_CONFIG)) do |f2|
        f2.each do |line2|
          f_tmp.write indent unless line2 == "\n"
          f_tmp.write line2
        end
      end
    end
    f_tmp.write line
  end
end
f_tmp.close

FileUtils.cp(f_tmp.path, target_file)


# Copy scaffold templates by rake

SCAFFOLD_TEMPLATE_COPY_COMMAND = 'rake rails:templates:copy'.freeze

is_success = system(SCAFFOLD_TEMPLATE_COPY_COMMAND)
unless is_success
  STDERR.puts
  STDERR.puts "Quit execution as '#{SCAFFOLD_TEMPLATE_COPY_COMMAND}' failed."
  exit
end


# Modify scaffold templates

DIR_SCAFFOLD_TEMPLATE = 'lib/templates/erb/scaffold'.freeze
TEMPLATE_INDEX_FILENAME = 'index.html.erb'.freeze
TEMPLATE_SHOW_FILENAME  =  'show.html.erb'.freeze

[TEMPLATE_INDEX_FILENAME, TEMPLATE_SHOW_FILENAME].each do |template_filename|
  original_file = File.join(DIR_SOURCE, template_filename + '.orig')
  current_file  = File.join(DIR_SCAFFOLD_TEMPLATE, template_filename)
  unless FileUtils.compare_file(original_file, current_file)
    STDERR.puts "Quit execution as scaffold template '#{template_filename}' has been changed."
    STDERR.puts "diff '#{original_file}' vs '#{current_file}'"
    system("diff #{original_file} #{current_file}")
    exit
  end
end

FileUtils.cp(File.join(DIR_SOURCE, TEMPLATE_INDEX_FILENAME), DIR_SCAFFOLD_TEMPLATE)
FileUtils.cp(File.join(DIR_SOURCE, TEMPLATE_SHOW_FILENAME ), DIR_SCAFFOLD_TEMPLATE)


# Remove gem 'jbuilder'

system(%q(sed -i -e "s/^gem 'jbuilder'/# &/" Gemfile))


# Generate scaffold
system("rails generate scaffold #{ARGV.join(' ')}")
system('rake db:migrate')


# Add root route
ROUTE_FILE = File.join(%w(config routes.rb))
system(%Q(sed -i -e "s/^  # root 'welcome#/  root '#{model_name.underscore.pluralize}#/" #{ROUTE_FILE}))


# Copy table_base.css

FileUtils.cp(File.join(DIR_SOURCE, 'table_base.css'), File.join(%w(app assets stylesheets)))

