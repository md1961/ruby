#! /bin/env ruby

require 'fileutils'
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

