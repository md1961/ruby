#! /bin/env ruby

require 'tempfile'
require_relative 'rails_util'


unless RailsUtil.rails_dir?
  STDERR.puts "Quit execution as you're not in a Rails root directory."
  exit
end

unless RailsUtil.git_repository?
  STDERR.puts "Quit execution as you're not in a git repository."
  exit
end


DIR_SOURCE = File.expand_path(File.join(File.dirname(__FILE__), 'files_for_generate_error_messages_for')).freeze

DIR_HELPER     = File.join(%w(app helpers)).freeze
DIR_TEMPLATE   = File.join(%w(app views application)).freeze
DIR_STYLESHEET = File.join(%w(app assets stylesheets)).freeze

TARGET_HELPER        = 'application_helper.rb'
SOURCE_HELPER_APPEND = 'application_helper_append.rb'
HELPER_METHOD_NAME   = 'error_messages_for'

SOURCE_TEMPLATE   = '_error_messages_for.html.erb'
SOURCE_STYLESHEET = 'errors.css'


# app/helpers/application_helper.rb

RE_METHOD_IN_HELPER = /\A\s*def\s+#{HELPER_METHOD_NAME}/
RE_END_OF_HELPER_BODY = /\Aend\s*\z/

f_tmp = Tempfile.open(TARGET_HELPER)
is_helper_method_written = false
helper_method_exists = false
File.open(File.join(DIR_HELPER, TARGET_HELPER), 'r') do |f|
  f.each do |line|
    helper_method_exists = true if line =~ RE_METHOD_IN_HELPER
    if line =~ RE_END_OF_HELPER_BODY && ! is_helper_method_written
      File.open(File.join(DIR_SOURCE, SOURCE_HELPER_APPEND)) do |f2|
        f2.each do |line2|
          f_tmp.write line2
        end
      end
      is_helper_method_written = true
    end
    f_tmp.write line
  end
end
f_tmp.close

FileUtils.cp(f_tmp.path, File.join(DIR_HELPER, TARGET_HELPER))


# app/views/application/_error_messages_for.html.erb

FileUtils.mkdir(DIR_TEMPLATE) unless File.exist?(DIR_TEMPLATE)
FileUtils.cp(File.join(DIR_SOURCE, SOURCE_TEMPLATE), DIR_TEMPLATE)


# app/assets/stylesheets/errors.css

FileUtils.cp(File.join(DIR_SOURCE, SOURCE_STYLESHEET), DIR_STYLESHEET)


if helper_method_exists
  STDERR.puts "#{HELPER_METHOD_NAME}() already exists in #{TARGET_HELPER}, but append a method anyway."
  STDERR.puts "Remove either method definition."
end

