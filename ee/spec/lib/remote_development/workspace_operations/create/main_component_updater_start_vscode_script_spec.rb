# frozen_string_literal: true

require "fast_spec_helper"
require "tempfile"
require "fileutils"
require "shellwords"

RSpec.describe "Remote Development VSCode Startup Script", feature_category: :workspaces do
  include_context "with constant modules"

  let(:main_component_name) { "tooling-container" }
  let(:script_content) do
    format(
      RemoteDevelopment::Files::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT,
      main_component_name: Shellwords.shellescape(main_component_name)
    )
  end

  let(:script_file) { Tempfile.new(%w[start_vscode .sh]) }
  let(:log_dir) { Dir.mktmpdir }
  let(:tools_dir) { Dir.mktmpdir }
  let(:product_json_path) { File.join(tools_dir, "vscode-reh-web/product.json") }
  let(:log_file_path) { File.join(log_dir, main_component_name, "start-vscode.log") }
  let(:extension_marketplace_service_url) { "https://marketplace.example.com" }
  let(:extension_marketplace_item_url) { "https://item.example.com" }
  let(:extension_marketplace_resource_url_template) { "https://resource.example.com/{path}" }
  let(:editor_log_level) { "info" }
  let(:editor_port) { create_constants_module::WORKSPACE_EDITOR_PORT }
  let(:editor_host) { "0.0.0.0" }
  let(:initial_product_json) { '{"commit": "test-commit", "otherKey": "value"}' }
  let(:base_env) do
    {
      GL_TOOLS_DIR: tools_dir,
      GL_WORKSPACE_LOGS_DIR: log_dir
    }
  end

  # Helper method to run the script with given environment variables
  # @param [Hash, nil] custom_env
  # @return [Hash]
  def run_script(custom_env = nil)
    env_vars = custom_env || env
    # Convert symbol keys to strings for the environment variables
    env_string = env_vars.map { |k, v| "#{k}=#{v}" }.join(" ")

    # Execute the script
    result = `env -i #{env_string} #{script_file.path} 2>&1`
    status = $?&.success? || false

    # Read the log file if it exists
    log_content = File.exist?(log_file_path) ? File.read(log_file_path) : nil

    {
      output: result,
      success: status,
      logs: log_content
    }
  end

  before do
    # Create the directory structure
    FileUtils.mkdir_p(File.join(tools_dir, "vscode-reh-web"))
    FileUtils.mkdir_p(File.join(log_dir, main_component_name))

    # Create a mock product.json file
    FileUtils.mkdir_p(File.dirname(product_json_path))
    File.write(product_json_path, initial_product_json)

    mock_vscode_server_command = "echo 'Mock VSCode server execution - skipping actual server start'"

    unless script_content.match?(%r{"\${GL_TOOLS_DIR}/vscode-reh-web/bin/gitlab-webide-server"})
      raise "Expected VSCode server execution pattern not found in script. The script may have changed."
    end

    # Modify the script to replace the server execution command
    # Script mocks the server execution because we don't have the vscode-reh-web executables setup
    modified_script = script_content.gsub(
      %r{"\${GL_TOOLS_DIR}/vscode-reh-web/bin/gitlab-webide-server"},
      mock_vscode_server_command
    )

    script_file.write(modified_script)
    script_file.close
    FileUtils.chmod(0o755, script_file.path.to_s)
  end

  after do
    script_file.unlink
    FileUtils.remove_entry(log_dir)
    FileUtils.remove_entry(tools_dir)
  end

  describe "happy path script execution with default settings" do
    let(:env) do
      base_env.merge({
        GL_VSCODE_IGNORE_VERSION_MISMATCH: "true",
        GL_VSCODE_ENABLE_MARKETPLACE: "true",
        GL_VSCODE_EXTENSION_MARKETPLACE_SERVICE_URL: extension_marketplace_service_url,
        GL_VSCODE_EXTENSION_MARKETPLACE_ITEM_URL: extension_marketplace_item_url,
        GL_VSCODE_EXTENSION_MARKETPLACE_RESOURCE_URL_TEMPLATE: extension_marketplace_resource_url_template
      })
    end

    let!(:script_result) { run_script }
    let(:output) { script_result.fetch(:output) }
    let(:status) { script_result.fetch(:success) }
    let(:log_content) { script_result.fetch(:logs) }

    it "executes successfully and creates the log file" do
      expect(status).to be true
      expect(output).to include("VS Code initialization started")
      expect(File).to exist(log_file_path)
    end

    it "sets default environment variables for unspecified values" do
      expect(log_content).to include("Setting default GL_VSCODE_LOG_LEVEL=#{editor_log_level}")
      expect(log_content).to include("Setting default GL_VSCODE_PORT=#{editor_port}")
    end

    it "logs the correct server startup information" do
      expect(log_content).to include("Starting server for the editor with:")
      expect(log_content).to include("- Host: #{editor_host}")
      expect(log_content).to include("- Port: #{editor_port}")
      expect(log_content).to include("- Log level: #{editor_log_level}")
      expect(log_content).to include("- Without connection token: yes")
      expect(log_content).to include("- Workspace trust disabled: yes")
    end

    it "removes the commit key from product.json for version mismatch handling" do
      expect(log_content).to include("Ignoring VS Code client-server version mismatch")
      expect(log_content).to include("Removed 'commit' key from #{product_json_path}")
    end

    it "adds the extensions gallery configuration to product.json for marketplace" do
      expect(log_content).to include("Extensions gallery configuration added")

      # Check if the log shows the modified content
      expect(log_content).to include("Contents of #{product_json_path} are:")
      expect(log_content).to include("extensionsGallery")
      expect(log_content).to include("\"serviceUrl\": \"#{extension_marketplace_service_url}\"")
      expect(log_content).to include("\"itemUrl\": \"#{extension_marketplace_item_url}\"")
      expect(log_content).to include("\"resourceUrlTemplate\": \"#{extension_marketplace_resource_url_template}\"")
    end
  end

  describe "script execution with custom settings" do
    let(:custom_editor_log_level) { "debug" }
    let(:custom_editor_port) { "8080" }
    let(:env) do
      base_env.merge({
        GL_VSCODE_LOG_LEVEL: custom_editor_log_level,
        GL_VSCODE_PORT: custom_editor_port
      })
    end

    let!(:script_result) { run_script }
    let(:status) { script_result.fetch(:success) }
    let(:log_content) { script_result.fetch(:logs) }

    it "uses the provided environment variables instead of defaults" do
      expect(status).to be true

      # Verify custom values were used (not default values)
      expect(log_content).not_to include("Setting default GL_VSCODE_LOG_LEVEL")
      expect(log_content).not_to include("Setting default GL_VSCODE_PORT")

      # Verify custom server configuration in logs
      expect(log_content).to include("- Port: #{custom_editor_port}")
      expect(log_content).to include("- Log level: #{custom_editor_log_level}")
    end
  end

  describe "script execution without required variables" do
    let(:env_without_tools) { { GL_WORKSPACE_LOGS_DIR: log_dir } }
    let!(:script_result) { run_script(env_without_tools) }
    let(:status) { script_result.fetch(:success) }
    let(:log_content) { script_result.fetch(:logs) }

    it "fails when GL_TOOLS_DIR is not set" do
      expect(status).to be false
      expect(log_content).to include("GL_TOOLS_DIR is not set")
    end
  end
end
