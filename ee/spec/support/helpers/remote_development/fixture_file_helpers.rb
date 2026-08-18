# frozen_string_literal: true

module RemoteDevelopment
  # NOTE: These methods must be in a module, instead of directly in an RSpec shared context, because we
  #       need to call them from within FactoryBot factories
  module FixtureFileHelpers
    include WorkspaceOperations::WorkspaceOperationsConstants
    include WorkspaceOperations::Create::CreateConstants

    extend self # This makes the instance methods available as class methods, for use in FactoryBot factories

    # @param [String] filename
    # @param [String] project_name
    # @param [String] namespace_path
    # @return [String]
    def read_devfile_yaml(
      filename, project_name: "test-project",
      namespace_path: "test-group",
      main_component_name: "tooling-container",
      is_legacy_poststart: false
    )
      erb_devfile_contents = read_fixture_file(filename)
      fixture_file_binding = FixtureFileErbBinding.new.get_fixture_file_binding
      devfile_contents = ERB.new(erb_devfile_contents).result(fixture_file_binding)
      devfile_contents.gsub!('http://localhost/', root_url)
      devfile_contents.gsub!('test-project', project_name)
      devfile_contents.gsub!('test-group', namespace_path)
      devfile_contents.gsub!('%<main_component_name>s', main_component_name) unless is_legacy_poststart

      format_clone_project_script!(devfile_contents, project_name: project_name, namespace_path: namespace_path)

      devfile_contents
    end

    # @param [String] filename
    # @return [String]
    def read_fixture_file(filename)
      File.read(Rails.root.join('ee/spec/fixtures/remote_development', filename).to_s)
    end

    # @return [String]
    def root_url
      # NOTE: Default to http://example.com/ if GitLab::Application is not defined. This allows this helper to be used
      #       from ee/spec/remote_development/fast_spec_helper.rb
      defined?(Gitlab::Application) ? Gitlab::Routing.url_helpers.root_url : "https://example.com/"
    end

    # @param [String] content
    # @param [String] project_name
    # @param [String] namespace_path
    # @return [void]
    def format_clone_project_script!(
      content,
      project_name: "test-project",
      namespace_path: "test-group"
    )
      # NOTE: These replacements correspond to the `format` command in `project_cloner_component_inserter.rb`
      content.gsub!(
        "%<project_cloning_successful_file>s",
        Shellwords.shellescape("#{WORKSPACE_DATA_VOLUME_PATH}/#{PROJECT_CLONING_SUCCESSFUL_FILE_NAME}")
      )
      content.gsub!("%<project_ref>s", Shellwords.shellescape("master"))
      content.gsub!("%<project_url>s", Shellwords.shellescape("#{root_url}#{namespace_path}/#{project_name}.git"))
      content.gsub!(
        "%<clone_dir>s",
        Shellwords.shellescape("#{WORKSPACE_DATA_VOLUME_PATH}/#{project_name}")
      )
      content.gsub!("%<clone_depth_option>s", CLONE_DEPTH_OPTION)

      nil
    end
  end
end
