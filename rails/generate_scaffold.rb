#! /bin/env ruby

require 'tempfile'
require 'yaml'

require 'active_support'
require 'active_support/core_ext'

require_relative 'rails_util'


unless RailsUtil.rails_dir?
  STDERR.puts "Quit execution as you're not in a Rails root directory."
  exit
end

unless RailsUtil.git_repository?
  STDERR.puts "Quit execution as you're not in a git repository."
  exit
end


if ARGV.size != 1
  STDERR.puts "Specify only model data file."
  STDERR.puts "Usage: #{File.basename $0} model_data_file"
  exit
end


model_data_file = ARGV[0]

unless File.exist?(model_data_file)
  STDERR.puts "Cannot open file '#{model_data_file}'."
  exit
end


h_model_data = open(model_data_file, 'r') do |f|
  YAML.load_file(f)
end

unless h_model_data.key?(:model)
  STDERR.puts "Cannot find model name with key :model in '#{File.basename(model_data_file)}'."
  exit
end

unless h_model_data.key?(:attrs)
  STDERR.puts "Cannot find attribute name(s) with key :attrs in '#{File.basename(model_data_file)}'."
  exit
end

array_of_validates = h_model_data[:validates]
if array_of_validates && ! array_of_validates.is_a?(Array)
  STDERR.puts "Specify array of strings eligible for model validates() arguments for :validates"
  STDERR.puts "('#{array_of_validates}' specified.)"
  exit
end


model_name = h_model_data[:model].singularize.underscore
attr_names = h_model_data[:attrs].map { |x| x.split(':').first }


DIR_SCRIPT_BASE = File.expand_path(File.dirname(__FILE__)).freeze
DIR_SOURCE = File.join(DIR_SCRIPT_BASE, 'files_for_generate_scaffold').freeze


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
TEMPLATE_FILENAMES = %w(index show new edit _form).map { |x| "#{x}.html.erb".freeze }.freeze
  
TEMPLATE_FILENAMES.each do |template_filename|
  original_file = File.join(DIR_SOURCE, template_filename + '.orig')
  current_file  = File.join(DIR_SCAFFOLD_TEMPLATE, template_filename)
  unless FileUtils.compare_file(original_file, current_file)
    STDERR.puts "Quit execution as scaffold template '#{template_filename}' has been changed."
    STDERR.puts "diff '#{original_file}' vs '#{current_file}'"
    system("diff #{original_file} #{current_file}")
    exit
  end
end

TEMPLATE_FILENAMES.each do |template_filename|
  FileUtils.cp(File.join(DIR_SOURCE, template_filename), DIR_SCAFFOLD_TEMPLATE)
end


# Remove gem 'jbuilder', and add Gemfile entries for Rspec

system(%q(sed -i -e "s/^gem 'jbuilder'/# &/" Gemfile))
system("cat #{File.join(DIR_SOURCE, 'Gemfile_for_rspec')} >> Gemfile")

system('bundle install')


# Generate scaffold

SCAFFOLD_GENERATE_COMMAND = "rails generate scaffold #{model_name} #{h_model_data[:attrs].join(' ')}".freeze

puts "Executing '#{SCAFFOLD_GENERATE_COMMAND}'..."
is_success = system(SCAFFOLD_GENERATE_COMMAND)
unless is_success
  STDERR.puts
  STDERR.puts "Quit execution as '#{SCAFFOLD_GENERATE_COMMAND}' failed."
  exit
end

system('rake db:migrate')


# Add root route
ROUTE_FILE = File.join(%w(config routes.rb))
system(%Q(sed -i -e "s/^  # root 'welcome#/  root '#{model_name.pluralize}#/" #{ROUTE_FILE}))


# Copy table_base.css

FileUtils.cp(File.join(DIR_SOURCE, 'table_base.css'), File.join(%w(app assets stylesheets)))


# Add helper error_messages_for()

system(File.join(DIR_SCRIPT_BASE, 'generate_error_messages_for.rb'))


# Configure translation for :ja
system(%Q(sed -i -e "s/^\\(  *\\)# \\(config.i18n.default_locale = \\):de/\\1\\2:ja/" config/application.rb))
system('wget https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/ja.yml -P config/locales/ --no-check-certificate')

t_model_name = h_model_data[:t_model] || model_name.camelize

TRANSLATIONS_FOR_NON_ACTIVERECORD = [
  %Q(  #{model_name.pluralize}:),
  %Q(    index:),
  %Q(      page_title: "%{model_name}の一覧"),
  %Q(      no_record_exists: "%{model_name}は存在しません。"),
  %Q(    show:),
  %Q(      page_title: "%{model_name}の詳細"),
  %Q(    new:),
  %Q(      page_title: "%{model_name}の新規作成"),
  %Q(    create:),
  %Q(      notice: "%{model_name}を新規に作成しました"),
  %Q(    edit:),
  %Q(      page_title: "%{model_name}の編集"),
  %Q(    update:),
  %Q(      notice: "%{model_name}を更新しました"),
  %Q(    destroy:),
  %Q(      notice: "%{model_name}を削除しました"),
  %Q(  link:),
  %Q(    cancel: "キャンセル"),
  %Q(    back: "戻る"),
  %Q(    show: "詳細"),
  %Q(    new: "新規作成"),
  %Q(    edit: "編集"),
  %Q(    destroy: "削除"),
  %Q(  confirm:),
  %Q(    #{model_name}:),
  %Q(      destroy: "#{t_model_name}「%{#{model_name}}」を削除してよろしいですか？"),
]

a = [] \
  << %Q(  models:) \
  << %Q(    #{model_name}: "#{t_model_name}") \
  << %Q(  attributes:) \
  << %Q(    #{model_name}:)
attr_names.each_with_index do |attr_name, index|
  t_attr_name = h_model_data[:t_attrs].try(:[], index) || attr_name.camelize
  a \
  << %Q(      #{attr_name}: "#{t_attr_name}")
end
TRANSLATIONS_FOR_ACTIVERECORD = a.freeze

target_file = File.join(DIR_CONFIG, File.join(%w(locales ja.yml)))
f_tmp = Tempfile.open('config-ja.yml')
File.open(target_file, 'r') do |f|
  f.each do |line|
    f_tmp.write line
    if line =~ /\Aja:\s*\z/
      TRANSLATIONS_FOR_NON_ACTIVERECORD.each do |t|
        f_tmp.puts t
      end
    elsif line =~ /\A(\s+)activerecord:\s*\z/
      indent_ar = Regexp.last_match(1)
      TRANSLATIONS_FOR_ACTIVERECORD.each do |t|
        f_tmp.puts indent_ar + t
      end
    end
  end
end
f_tmp.close

FileUtils.cp(f_tmp.path, target_file)


# Add validations to the model, and to_s() definition if requested.

if array_of_validates
  TARGET_MODEL_FILENAME = "#{model_name}.rb".freeze

  target_file = File.join(%w(app models), TARGET_MODEL_FILENAME)
  f_tmp = Tempfile.open(TARGET_MODEL_FILENAME)
  File.open(target_file, 'r') do |f|
    f.each do |line|
      if line =~ /\Aend\s*\z/
        array_of_validates.each do |arg|
          f_tmp.write "  validates #{arg}\n"
        end

        if h_model_data[:attr_for_to_s]
          f_tmp.write "\n"
          f_tmp.write "  def to_s\n"
          f_tmp.write "    #{h_model_data[:attr_for_to_s]}\n"
          f_tmp.write "  end\n"
        end
      end
      f_tmp.write line
    end
  end
  f_tmp.close

  FileUtils.cp(f_tmp.path, target_file)
end


# Modify scaffold controller
TARGET_CONTROLLER = "app/controllers/#{model_name.pluralize}_controller.rb"
NOTICE_STATEMENT = %Q(t(".notice") % {model_name: #{model_name.camelize}.model_name.human})
system(%Q(sed -i -e 's/^\\(.*notice: \\).*$/\\1#{NOTICE_STATEMENT}/' #{TARGET_CONTROLLER}))


# Create seed data and load.

File.open(File.join(%w(db seeds.rb)), 'a') do |f|
  f.write "\n"
  f.write "#{model_name.camelize}.create!([\n"
  h_model_data[:data].each do |values|
    values = values.map { |v| v.is_a?(Date) ? v.strftime('%Y-%m-%d') : v }
    f.write "  #{Hash[attr_names.zip(values)].symbolize_keys},\n"
  end
  f.write "])\n"
end

system('rake db:seed')

