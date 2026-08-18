# frozen_string_literal: true

module Tasks
  module Gitlab
    module AiGateway
      module Utils
        DEFAULT_INSTALLATION_DIR = 'tmp/tests/gitlab-ai-gateway'

        REPO_URL = 'https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist.git'
        DEFAULT_BRANCH = 'main'
        DEFAULT_PORT = '50053'

        INSTALLED_FLAG_FILE = 'ai-gateway-installed.txt'
        DWS_PID_FILE = 'duo-workflow-service.pid'

        def self.ensure_duo_workflow_service(path: DEFAULT_INSTALLATION_DIR)
          install_with_retry(path: path)
          run_duo_workflow_service(path: path)
        end

        def self.install_with_retry(path: DEFAULT_INSTALLATION_DIR, attempts: 3, interval: 10.0)
          install(path: path)
        rescue RuntimeError => e
          attempts -= 1

          if attempts <= 0
            print_warn('installation failure of AI Gateway project', e)
            raise
          end

          print_warn('installation failure of AI Gateway project. Retrying...', e)
          sleep interval
          FileUtils.rm_rf(path)
          install_with_retry(path: path, attempts: attempts, interval: interval)
        end

        def self.install(path: DEFAULT_INSTALLATION_DIR)
          return unless duo_workflow_service_enabled?
          return unless prerequisites_met?

          if installed?(path)
            return if up_to_date?(path)

            FileUtils.rm_rf(path)
          end

          clone!(path)
          checkout!(path)
          install_project_deps!(path)
          install_runtime_deps!(path)

          mark_installed!(path)
        end

        def self.run_duo_workflow_service(path: DEFAULT_INSTALLATION_DIR)
          return unless duo_workflow_service_enabled?
          return print_warn('incomplete installation of AI Gateway project') unless installed?(path)
          return if current_duo_workflow_service_pid(path)

          command = %W[poetry -C #{Rails.root.join(path)} run duo-workflow-service]
          command.prepend(*%W[mise -C #{Rails.root.join(path)} exec poetry --]) if mise_available?

          Process.spawn(
            {
              'AIGW_MOCK_MODEL_RESPONSES' => 'true',
              'AIGW_USE_AGENTIC_MOCK' => 'true',
              'PORT' => duo_workflow_service_port,
              'DUO_WORKFLOW_AUTH__ENABLED' => 'false',
              'LANGCHAIN_ENDPOINT' => ''
            },
            *command
          ).tap do |pid|
            save_duo_workflow_service_pid(pid, path)
          end
        end

        def self.terminate_duo_workflow_service(path: DEFAULT_INSTALLATION_DIR)
          pid = current_duo_workflow_service_pid(path)

          return unless pid

          Process.kill('TERM', pid)
          Process.wait(pid)
        rescue Errno::ESRCH
          # Process already terminated. no-op.
        ensure
          delete_duo_workflow_service_pid(path)
        end

        def self.latest_sha
          command = %W[#{::Gitlab.config.git.bin_path} ls-remote #{REPO_URL} #{ai_gateway_repo_ref}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to fetch the latest SHA of gitlab-ai-gateway: #{out}" unless exit_status == 0

          out.split[0]
        end

        def self.current_sha(path)
          command = %W[#{::Gitlab.config.git.bin_path} -C #{path} rev-parse #{refspec_dest}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "Failed to fetch the current SHA of gitlab-ai-gateway: #{out}" unless exit_status == 0

          out.split[0]
        end

        def self.up_to_date?(path)
          current_sha(path) == latest_sha
        end

        def self.duo_workflow_service_enabled?
          return true if ::Gitlab::Utils.to_boolean(ENV.fetch('TEST_DUO_WORKFLOW_SERVICE_ENABLED', true))

          print_warn('disablement of Duo Workflow Service in tests')

          false
        end

        def self.current_duo_workflow_service_pid(path)
          pid_path = duo_workflow_service_pid_path(path)

          return unless ::File.exist?(pid_path)

          ::File.read(pid_path).to_i.tap do |pid|
            Process.getpgid(pid)
          end
        rescue Errno::ESRCH
          nil
        end

        def self.save_duo_workflow_service_pid(pid, path)
          pid_path = duo_workflow_service_pid_path(path)

          ::File.write(pid_path, pid)
        end

        def self.delete_duo_workflow_service_pid(path)
          pid_path = duo_workflow_service_pid_path(path)

          FileUtils.rm_f(pid_path)
        end

        def self.duo_workflow_service_pid_path(path)
          Rails.root.join(path, DWS_PID_FILE)
        end

        def self.duo_workflow_service_port
          ENV['TEST_DUO_WORKFLOW_SERVICE_PORT'] || DEFAULT_PORT
        end

        def self.ai_gateway_repo_ref
          ENV['TEST_AI_GATEWAY_REPO_REF'] || ENV['TEST_AI_GATEWAY_REPO_BRANCH'] || DEFAULT_BRANCH
        end

        def self.prerequisites_met?
          return true if mise_available? || poetry_available?

          print_warn('unmet prerequisites in system')

          false
        end

        def self.print_warn(message, error = nil)
          line = "[WARN] Some feature tests that depend on Duo Workflow Service or AI Gateway " \
            "might fail due to #{message}.\n"
          line += "       Error: #{error.message.chomp}\n" if error
          line += "       See https://docs.gitlab.com/development/testing_guide/testing_ai_features/" \
            "#dap-feature-tests-in-core-feature-pages for more info."
          puts line
        end

        def self.poetry_available?
          command = %w[poetry --version]

          begin
            out, exit_status = ::Gitlab::Popen.popen(command)
          rescue Errno::ENOENT => e
            exit_status = -1
            out = e.message
          end

          return true if exit_status == 0

          puts "[INFO] poetry is not available. out: #{out}"
        end

        def self.mise_available?
          command = %w[mise --version]

          begin
            out, exit_status = ::Gitlab::Popen.popen(command)
          rescue Errno::ENOENT => e
            exit_status = -1
            out = e.message
          end

          return true if exit_status == 0

          puts "[INFO] mise is not available. out: #{out}"
        end

        def self.clone!(path)
          command = %W[#{::Gitlab.config.git.bin_path} clone --depth 1 #{REPO_URL} #{path}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "git-clone failure of gitlab-ai-gateway repo: #{out}" unless exit_status == 0

          puts "[INFO] Cloned AIGW repository (#{REPO_URL}) at #{path}"
        end

        def self.checkout!(path)
          command = %W[#{::Gitlab.config.git.bin_path} -C #{path} fetch origin
            #{refspec_src}:#{refspec_dest}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "git-fetch failure of gitlab-ai-gateway ref: #{out}" unless exit_status == 0

          command = %W[#{::Gitlab.config.git.bin_path} -C #{path} checkout #{refspec_dest}]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "git-checkout failure of gitlab-ai-gateway ref: #{out}" unless exit_status == 0

          puts "[INFO] Checked out AIGW repository ref (#{ai_gateway_repo_ref}) at #{path}"
        end

        def self.refspec_src
          return ai_gateway_repo_ref if git_sha?(ai_gateway_repo_ref)

          "refs/heads/#{ai_gateway_repo_ref}"
        end

        def self.refspec_dest
          "refs/remotes/origin/#{ai_gateway_repo_ref}"
        end

        def self.git_sha?(ref)
          ref.match?(/\A[0-9a-f]{40}\z/)
        end

        def self.install_project_deps!(path)
          return unless mise_available?

          command = %W[mise -C #{Rails.root.join(path)} install]

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "installation failure of AIGW project deps: #{out}" unless exit_status == 0

          puts "[INFO] Installed AIGW project deps at #{path}"
        end

        def self.install_runtime_deps!(path)
          command = %W[poetry -C #{Rails.root.join(path)} install]
          command.prepend(*%W[mise -C #{Rails.root.join(path)} exec poetry --]) if mise_available?

          out, exit_status = ::Gitlab::Popen.popen(command)

          raise "installation failure of AIGW runtime deps: #{out}" unless exit_status == 0

          puts "[INFO] Installed AIGW runtime deps at #{path}"
        end

        def self.mark_installed!(path)
          FileUtils.touch(Rails.root.join(path, INSTALLED_FLAG_FILE))
        end

        def self.installed?(path)
          File.exist?(Rails.root.join(path, INSTALLED_FLAG_FILE))
        end
      end
    end
  end
end
