module RailsUtil

  module_function

    FILES_FOR_RAILS_DIR = [
      %w(app models),
      %w(app controllers),
      %w(app views),
      %w(config application.rb),
    ].freeze

    def rails_dir?
      FILES_FOR_RAILS_DIR.map { |array| File.join(*array) }.each do |file|
        return false unless File.exist?(file)
      end
      true
    end

    FILES_FOR_GIT_REPOSITORY = [
      %w(.git config),
    ].freeze

    def git_repository?
      FILES_FOR_GIT_REPOSITORY.map { |array| File.join(*array) }.each do |file|
        return false unless File.exist?(file)
      end
      true
    end
end
