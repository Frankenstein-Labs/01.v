# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Tasks::Gitlab::AiGateway::Utils, feature_category: :duo_agent_platform do
  describe '.ensure_duo_workflow_service' do
    let(:path) { '/tmp/ai-gateway' }

    before do
      allow(described_class).to receive(:install_with_retry)
      allow(described_class).to receive(:run_duo_workflow_service)
    end

    it 'calls install_with_retry and run_duo_workflow_service' do
      described_class.ensure_duo_workflow_service(path: path)

      expect(described_class).to have_received(:install_with_retry).with(path: path)
      expect(described_class).to have_received(:run_duo_workflow_service).with(path: path)
    end
  end

  describe '.install_with_retry' do
    let(:path) { '/tmp/ai-gateway' }
    let(:temp_dir) { Dir.mktmpdir }

    before do
      allow(described_class).to receive(:print_warn)
      allow(described_class).to receive(:sleep)
      FileUtils.mkdir_p(temp_dir)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    context 'when install succeeds on first attempt' do
      before do
        allow(described_class).to receive(:install)
      end

      it 'calls install once' do
        described_class.install_with_retry(path: temp_dir)

        expect(described_class).to have_received(:install).with(path: temp_dir).once
        expect(described_class).not_to have_received(:print_warn)
      end
    end

    context 'when install fails then succeeds on retry' do
      it 'calls install twice and prints warning' do
        call_count = 0
        allow(described_class).to receive(:install) do
          call_count += 1
          raise 'clone failed' if call_count == 1
        end
        allow(FileUtils).to receive(:rm_rf).and_call_original

        described_class.install_with_retry(path: temp_dir)

        expect(call_count).to eq(2)
        expect(described_class).to have_received(:print_warn)
          .with('installation failure of AI Gateway project. Retrying...', anything)
        expect(FileUtils).to have_received(:rm_rf).with(temp_dir)
      end
    end

    context 'when install fails repeatedly' do
      before do
        allow(described_class).to receive(:install).and_raise(RuntimeError, 'installation failed')
      end

      it 'raises the error after all retries exhausted' do
        expect do
          described_class.install_with_retry(path: temp_dir)
        end.to raise_error(RuntimeError, 'installation failed')

        expect(described_class).to have_received(:print_warn)
          .with('installation failure of AI Gateway project', anything)
      end

      it 'cleans up directory on each retry attempt' do
        allow(FileUtils).to receive(:rm_rf).and_call_original

        expect do
          described_class.install_with_retry(path: temp_dir)
        end.to raise_error(RuntimeError)

        expect(FileUtils).to have_received(:rm_rf).with(temp_dir).exactly(2).times
      end
    end

    context 'when attempts is 0' do
      before do
        allow(described_class).to receive(:install).and_raise(RuntimeError, 'installation failed')
      end

      it 'raises immediately' do
        expect do
          described_class.install_with_retry(path: temp_dir, attempts: 0)
        end.to raise_error(RuntimeError, 'installation failed')

        expect(described_class).to have_received(:install).with(path: temp_dir).once
      end
    end
  end

  describe '.install' do
    let(:path) { '/tmp/ai-gateway' }

    shared_examples 'installation steps' do
      it 'calls clone, checkout, install_project_deps, install_runtime_deps, and mark_installed!' do
        described_class.install(path: path)

        expect(described_class).to have_received(:clone!).with(path)
        expect(described_class).to have_received(:checkout!).with(path)
        expect(described_class).to have_received(:install_project_deps!).with(path)
        expect(described_class).to have_received(:install_runtime_deps!).with(path)
        expect(described_class).to have_received(:mark_installed!).with(path)
      end
    end

    shared_examples 'skips installation' do
      it 'does not proceed with installation' do
        described_class.install(path: path)

        expect(described_class).not_to have_received(:clone!)
        expect(described_class).not_to have_received(:checkout!)
        expect(described_class).not_to have_received(:install_project_deps!)
        expect(described_class).not_to have_received(:install_runtime_deps!)
        expect(described_class).not_to have_received(:mark_installed!)
      end
    end

    before do
      allow(described_class).to receive(:clone!)
      allow(described_class).to receive(:checkout!)
      allow(described_class).to receive(:install_project_deps!)
      allow(described_class).to receive(:install_runtime_deps!)
      allow(described_class).to receive(:mark_installed!)
      allow(described_class).to receive(:print_warn)
    end

    context 'when duo_workflow_service is enabled and dependencies are available' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          prerequisites_met?: true,
          installed?: false
        )
      end

      include_examples 'installation steps'
    end

    context 'when already installed and up to date' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          prerequisites_met?: true,
          installed?: true,
          up_to_date?: true
        )
      end

      include_examples 'skips installation'
    end

    context 'when already installed but not up to date' do
      let(:temp_dir) { Dir.mktmpdir }

      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          prerequisites_met?: true,
          installed?: true,
          up_to_date?: false
        )
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'removes the old installation and reinstalls' do
        described_class.install(path: temp_dir)

        expect(described_class).to have_received(:clone!).with(temp_dir)
        expect(described_class).to have_received(:checkout!).with(temp_dir)
        expect(described_class).to have_received(:install_project_deps!).with(temp_dir)
        expect(described_class).to have_received(:install_runtime_deps!).with(temp_dir)
        expect(described_class).to have_received(:mark_installed!).with(temp_dir)
      end
    end

    context 'when duo_workflow_service is disabled' do
      before do
        allow(described_class).to receive(:duo_workflow_service_enabled?).and_return(false)
      end

      include_examples 'skips installation'
    end

    context 'when dependencies are not available' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          prerequisites_met?: false
        )
      end

      include_examples 'skips installation'
    end

    context 'when installation fails' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          prerequisites_met?: true,
          installed?: false
        )
        allow(described_class).to receive(:clone!).and_raise(RuntimeError, 'clone failed')
      end

      it 'raises the error' do
        expect { described_class.install(path: path) }.to raise_error(RuntimeError, 'clone failed')
      end
    end
  end

  describe '.run_duo_workflow_service' do
    let(:temp_root) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_root, path) }

    before do
      FileUtils.mkdir_p(full_path)
    end

    after do
      FileUtils.rm_rf(temp_root)
    end

    context 'when duo_workflow_service is enabled and installed' do
      context 'when mise is not available' do
        before do
          allow(described_class).to receive_messages(
            duo_workflow_service_enabled?: true,
            installed?: true,
            current_duo_workflow_service_pid: nil,
            duo_workflow_service_port: '50053',
            mise_available?: false,
            save_duo_workflow_service_pid: nil
          )
          allow(Process).to receive(:spawn).and_return(12345)
        end

        it 'spawns the duo workflow service with correct environment variables' do
          expect(Process).to receive(:spawn).with(
            hash_including(
              'AIGW_MOCK_MODEL_RESPONSES' => 'true',
              'AIGW_USE_AGENTIC_MOCK' => 'true',
              'PORT' => '50053',
              'DUO_WORKFLOW_AUTH__ENABLED' => 'false',
              'LANGCHAIN_ENDPOINT' => ''
            ),
            'poetry', '-C', full_path, 'run', 'duo-workflow-service'
          ).and_return(12345)

          described_class.run_duo_workflow_service(path: full_path)
        end

        it 'saves the process ID' do
          allow(Process).to receive(:spawn).and_return(12345)

          described_class.run_duo_workflow_service(path: full_path)

          expect(described_class).to have_received(:save_duo_workflow_service_pid).with(12345, full_path)
        end
      end

      context 'when mise is available' do
        before do
          allow(described_class).to receive_messages(
            duo_workflow_service_enabled?: true,
            installed?: true,
            current_duo_workflow_service_pid: nil,
            duo_workflow_service_port: '50053',
            mise_available?: true,
            save_duo_workflow_service_pid: nil
          )
          allow(Process).to receive(:spawn).and_return(12345)
        end

        it 'spawns the duo workflow service with mise exec prefix' do
          expect(Process).to receive(:spawn).with(
            hash_including(
              'AIGW_MOCK_MODEL_RESPONSES' => 'true',
              'AIGW_USE_AGENTIC_MOCK' => 'true',
              'PORT' => '50053',
              'DUO_WORKFLOW_AUTH__ENABLED' => 'false',
              'LANGCHAIN_ENDPOINT' => ''
            ),
            'mise', '-C', full_path, 'exec', 'poetry', '--',
            'poetry', '-C', full_path, 'run', 'duo-workflow-service'
          ).and_return(12345)

          described_class.run_duo_workflow_service(path: full_path)
        end
      end

      context 'when service is already running' do
        before do
          allow(described_class).to receive_messages(
            duo_workflow_service_enabled?: true,
            installed?: true,
            current_duo_workflow_service_pid: 12345
          )
        end

        it 'does not spawn a new service' do
          expect(Process).not_to receive(:spawn)

          described_class.run_duo_workflow_service(path: path)
        end
      end
    end

    context 'when duo_workflow_service is disabled' do
      before do
        allow(described_class).to receive(:duo_workflow_service_enabled?).and_return(false)
      end

      it 'does not spawn the service' do
        expect(Process).not_to receive(:spawn)

        described_class.run_duo_workflow_service(path: path)
      end
    end

    context 'when not installed' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          installed?: false
        )
        allow(described_class).to receive(:print_warn)
      end

      it 'does not spawn the service' do
        expect(Process).not_to receive(:spawn)

        described_class.run_duo_workflow_service(path: path)
      end

      it 'prints a warning' do
        described_class.run_duo_workflow_service(path: path)

        expect(described_class).to have_received(:print_warn).with('incomplete installation of AI Gateway project')
      end
    end
  end

  describe '.terminate_duo_workflow_service' do
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }

    context 'when service is running' do
      before do
        allow(described_class).to receive(:current_duo_workflow_service_pid).with(path).and_return(12345)
        allow(described_class).to receive(:delete_duo_workflow_service_pid).with(path)
        allow(Process).to receive(:kill).with('TERM', 12345)
        allow(Process).to receive(:wait).with(12345)
      end

      it 'terminates the service' do
        described_class.terminate_duo_workflow_service(path: path)

        expect(Process).to have_received(:kill).with('TERM', 12345)
        expect(Process).to have_received(:wait).with(12345)
      end

      it 'deletes the pid file' do
        described_class.terminate_duo_workflow_service(path: path)

        expect(described_class).to have_received(:delete_duo_workflow_service_pid).with(path)
      end
    end

    context 'when service is not running' do
      before do
        allow(described_class).to receive(:current_duo_workflow_service_pid).with(path).and_return(nil)
        allow(described_class).to receive(:delete_duo_workflow_service_pid).with(path)
      end

      it 'does not attempt to kill the process' do
        expect(Process).not_to receive(:kill)

        described_class.terminate_duo_workflow_service(path: path)
      end
    end

    context 'when process is already terminated' do
      before do
        allow(described_class).to receive(:current_duo_workflow_service_pid).with(path).and_return(12345)
        allow(described_class).to receive(:delete_duo_workflow_service_pid).with(path)
        allow(Process).to receive(:kill).with('TERM', 12345).and_raise(Errno::ESRCH)
        allow(Process).to receive(:wait).with(12345)
      end

      it 'handles the error gracefully' do
        expect { described_class.terminate_duo_workflow_service(path: path) }.not_to raise_error
      end

      it 'still deletes the pid file' do
        described_class.terminate_duo_workflow_service(path: path)

        expect(described_class).to have_received(:delete_duo_workflow_service_pid).with(path)
      end
    end
  end

  describe '.latest_sha' do
    let(:repo_url) { described_class::REPO_URL }
    let(:ref) { 'main' }
    let(:sha) { 'abc123def456' }

    before do
      allow(described_class).to receive(:ai_gateway_repo_ref).and_return(ref)
    end

    context 'when git command succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(["#{sha}\trefs/heads/#{ref}", 0])
      end

      it 'returns the latest SHA' do
        result = described_class.latest_sha

        expect(result).to eq(sha)
      end

      it 'calls git ls-remote with correct parameters' do
        described_class.latest_sha

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('ls-remote', repo_url, ref)
        )
      end
    end

    context 'when git command fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['error message', 1])
      end

      it 'raises an error' do
        expect { described_class.latest_sha }.to raise_error(
          /Failed to fetch the latest SHA of gitlab-ai-gateway/
        )
      end
    end
  end

  describe '.current_sha' do
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:sha) { 'abc123def456' }

    before do
      allow(described_class).to receive(:ai_gateway_repo_ref).and_return('main')
    end

    context 'when git command succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return([sha, 0])
      end

      it 'returns the current SHA' do
        result = described_class.current_sha(path)

        expect(result).to eq(sha)
      end

      it 'calls git rev-parse with correct parameters' do
        described_class.current_sha(path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('-C', path, 'rev-parse', 'refs/remotes/origin/main')
        )
      end
    end

    context 'when git command fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['error message', 1])
      end

      it 'raises an error' do
        expect { described_class.current_sha(path) }.to raise_error(
          /Failed to fetch the current SHA of gitlab-ai-gateway/
        )
      end
    end
  end

  describe '.up_to_date?' do
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:sha) { 'abc123def456' }

    context 'when current SHA matches latest SHA' do
      before do
        allow(described_class).to receive_messages(
          current_sha: sha,
          latest_sha: sha
        )
      end

      it 'returns true' do
        result = described_class.up_to_date?(path)

        expect(result).to be(true)
      end
    end

    context 'when current SHA does not match latest SHA' do
      before do
        allow(described_class).to receive_messages(
          current_sha: 'old_sha',
          latest_sha: 'new_sha'
        )
      end

      it 'returns false' do
        result = described_class.up_to_date?(path)

        expect(result).to be(false)
      end
    end
  end

  describe '.duo_workflow_service_port' do
    context 'when TEST_DUO_WORKFLOW_SERVICE_PORT environment variable is set' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_PORT', '9999')
      end

      it 'returns the environment variable value' do
        result = described_class.duo_workflow_service_port

        expect(result).to eq('9999')
      end
    end

    context 'when TEST_DUO_WORKFLOW_SERVICE_PORT environment variable is not set' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_PORT', nil)
      end

      it 'returns the default port' do
        result = described_class.duo_workflow_service_port

        expect(result).to eq(described_class::DEFAULT_PORT)
      end
    end
  end

  describe '.ai_gateway_repo_ref' do
    context 'when TEST_AI_GATEWAY_REPO_REF environment variable is set' do
      before do
        stub_env('TEST_AI_GATEWAY_REPO_REF', 'custom-ref')
        stub_env('TEST_AI_GATEWAY_REPO_BRANCH', nil)
      end

      it 'returns the environment variable value' do
        result = described_class.ai_gateway_repo_ref

        expect(result).to eq('custom-ref')
      end
    end

    context 'when TEST_AI_GATEWAY_REPO_BRANCH environment variable is set' do
      before do
        stub_env('TEST_AI_GATEWAY_REPO_REF', nil)
        stub_env('TEST_AI_GATEWAY_REPO_BRANCH', 'custom-branch')
      end

      it 'returns the environment variable value' do
        result = described_class.ai_gateway_repo_ref

        expect(result).to eq('custom-branch')
      end
    end

    context 'when neither environment variable is set' do
      before do
        stub_env('TEST_AI_GATEWAY_REPO_REF', nil)
        stub_env('TEST_AI_GATEWAY_REPO_BRANCH', nil)
      end

      it 'returns the default branch' do
        result = described_class.ai_gateway_repo_ref

        expect(result).to eq(described_class::DEFAULT_BRANCH)
      end
    end
  end

  describe '.duo_workflow_service_enabled?' do
    context 'when TEST_DUO_WORKFLOW_SERVICE_ENABLED is not set to false' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_ENABLED', nil)
      end

      it 'returns true' do
        result = described_class.duo_workflow_service_enabled?

        expect(result).to be(true)
      end
    end

    context 'when TEST_DUO_WORKFLOW_SERVICE_ENABLED is set to false' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_ENABLED', 'false')
      end

      it 'returns false' do
        result = described_class.duo_workflow_service_enabled?

        expect(result).to be(false)
      end

      it 'prints a warning message' do
        expect do
          described_class.duo_workflow_service_enabled?
        end.to output(/\[WARN\] Some feature tests/).to_stdout
      end
    end
  end

  describe '.prerequisites_met?' do
    context 'when mise is available' do
      before do
        allow(described_class).to receive_messages(
          mise_available?: true,
          poetry_available?: false
        )
      end

      it 'returns true' do
        result = described_class.prerequisites_met?

        expect(result).to be(true)
      end
    end

    context 'when poetry is available' do
      before do
        allow(described_class).to receive_messages(
          mise_available?: false,
          poetry_available?: true
        )
      end

      it 'returns true' do
        result = described_class.prerequisites_met?

        expect(result).to be(true)
      end
    end

    context 'when neither mise nor poetry is available' do
      before do
        allow(described_class).to receive_messages(
          mise_available?: false,
          poetry_available?: false
        )
      end

      it 'returns false' do
        result = described_class.prerequisites_met?

        expect(result).to be(false)
      end

      it 'prints a warning message' do
        expect do
          described_class.prerequisites_met?
        end.to output(/\[WARN\] Some feature tests/).to_stdout
      end
    end
  end

  describe '.poetry_available?' do
    context 'when poetry command succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['Poetry (version 1.0.0)', 0])
      end

      it 'returns true' do
        result = described_class.poetry_available?

        expect(result).to be(true)
      end
    end

    context 'when poetry command fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['command not found', 127])
      end

      it 'returns nil (falsy)' do
        result = described_class.poetry_available?

        expect(result).to be_falsy
      end

      it 'prints an info message' do
        expect do
          described_class.poetry_available?
        end.to output(/\[INFO\] poetry is not available/).to_stdout
      end
    end

    context 'when poetry command is not found (Errno::ENOENT)' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_raise(Errno::ENOENT, 'No such file or directory')
      end

      it 'returns nil (falsy)' do
        result = described_class.poetry_available?

        expect(result).to be_falsy
      end

      it 'prints an info message with error details' do
        expect do
          described_class.poetry_available?
        end.to output(/\[INFO\] poetry is not available/).to_stdout
      end
    end
  end

  describe '.mise_available?' do
    context 'when mise command succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['mise 2024.1.0', 0])
      end

      it 'returns true' do
        result = described_class.mise_available?

        expect(result).to be(true)
      end
    end

    context 'when mise command fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['command not found', 127])
      end

      it 'returns nil (falsy)' do
        result = described_class.mise_available?

        expect(result).to be_falsy
      end

      it 'prints an info message' do
        expect do
          described_class.mise_available?
        end.to output(/\[INFO\] mise is not available/).to_stdout
      end
    end

    context 'when mise command is not found (Errno::ENOENT)' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_raise(Errno::ENOENT, 'No such file or directory')
      end

      it 'returns nil (falsy)' do
        result = described_class.mise_available?

        expect(result).to be_falsy
      end

      it 'prints an info message with error details' do
        expect do
          described_class.mise_available?
        end.to output(/\[INFO\] mise is not available/).to_stdout
      end
    end
  end

  describe '.clone!' do
    let(:path) { '/tmp/ai-gateway' }
    let(:repo_url) { described_class::REPO_URL }

    context 'when clone succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
      end

      it 'does not raise an error' do
        expect { described_class.clone!(path) }.not_to raise_error
      end

      it 'calls git clone with correct parameters' do
        described_class.clone!(path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('clone', '--depth', '1', repo_url, path)
        )
      end

      it 'prints an info message' do
        expect do
          described_class.clone!(path)
        end.to output(/\[INFO\] Cloned AIGW repository/).to_stdout
      end
    end

    context 'when clone fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['fatal: repository not found', 128])
      end

      it 'raises an error' do
        expect { described_class.clone!(path) }.to raise_error(
          /git-clone failure of gitlab-ai-gateway repo/
        )
      end
    end
  end

  describe '.checkout!' do
    let(:path) { '/tmp/ai-gateway' }
    let(:ref) { 'main' }

    before do
      allow(described_class).to receive(:ai_gateway_repo_ref).and_return(ref)
    end

    context 'when fetch succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
      end

      it 'calls git fetch and checkout' do
        described_class.checkout!(path)

        expect(::Gitlab::Popen).to have_received(:popen).at_least(:twice)
      end

      it 'does not raise an error' do
        expect { described_class.checkout!(path) }.not_to raise_error
      end

      it 'prints an info message' do
        expect do
          described_class.checkout!(path)
        end.to output(/\[INFO\] Checked out AIGW repository ref/).to_stdout
      end
    end

    context 'when fetch fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['fatal: unable to access repository', 128])
      end

      it 'raises an error' do
        expect { described_class.checkout!(path) }.to raise_error(
          /git-fetch failure of gitlab-ai-gateway ref/
        )
      end
    end

    context 'when checkout fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_call_original
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0], ['error: pathspec did not match', 1])
      end

      it 'raises an error' do
        expect { described_class.checkout!(path) }.to raise_error(
          /git-checkout failure of gitlab-ai-gateway ref/
        )
      end
    end
  end

  describe '.install_project_deps!' do
    let(:temp_root) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_root, path) }

    before do
      FileUtils.mkdir_p(full_path)
    end

    after do
      FileUtils.rm_rf(temp_root)
    end

    context 'when mise is available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(true)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
      end

      it 'does not raise an error' do
        expect { described_class.install_project_deps!(full_path) }.not_to raise_error
      end

      it 'calls mise install with correct path' do
        described_class.install_project_deps!(full_path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('mise', '-C', full_path, 'install')
        )
      end

      it 'prints an info message' do
        expect do
          described_class.install_project_deps!(full_path)
        end.to output(/\[INFO\] Installed AIGW project deps/).to_stdout
      end
    end

    context 'when mise is not available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(false)
      end

      it 'returns early without calling popen' do
        expect(::Gitlab::Popen).not_to receive(:popen)

        described_class.install_project_deps!(full_path)
      end
    end

    context 'when mise install fails' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(true)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['error: failed to install', 1])
      end

      it 'raises an error' do
        expect { described_class.install_project_deps!(full_path) }.to raise_error(
          /installation failure of AIGW project deps/
        )
      end
    end
  end

  describe '.install_runtime_deps!' do
    let(:temp_root) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_root, path) }

    before do
      FileUtils.mkdir_p(full_path)
    end

    after do
      FileUtils.rm_rf(temp_root)
    end

    context 'when mise is available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(true)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
      end

      it 'does not raise an error' do
        expect { described_class.install_runtime_deps!(full_path) }.not_to raise_error
      end

      it 'calls poetry install with mise exec prefix' do
        described_class.install_runtime_deps!(full_path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('mise', 'exec', 'poetry', '--', 'poetry', '-C', full_path, 'install')
        )
      end

      it 'prints an info message' do
        expect do
          described_class.install_runtime_deps!(full_path)
        end.to output(/\[INFO\] Installed AIGW runtime deps/).to_stdout
      end
    end

    context 'when mise is not available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(false)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
      end

      it 'does not raise an error' do
        expect { described_class.install_runtime_deps!(full_path) }.not_to raise_error
      end

      it 'calls poetry install without mise exec prefix' do
        described_class.install_runtime_deps!(full_path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('poetry', '-C', full_path, 'install')
        )
      end

      it 'prints an info message' do
        expect do
          described_class.install_runtime_deps!(full_path)
        end.to output(/\[INFO\] Installed AIGW runtime deps/).to_stdout
      end
    end

    context 'when poetry install fails' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(false)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['error: failed to install', 1])
      end

      it 'raises an error' do
        expect { described_class.install_runtime_deps!(full_path) }.to raise_error(
          /installation failure of AIGW runtime deps/
        )
      end
    end
  end

  describe '.current_duo_workflow_service_pid' do
    let(:temp_root) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_root, path) }
    let(:pid_file) { File.join(full_path, 'duo-workflow-service.pid') }

    before do
      FileUtils.mkdir_p(full_path)
      allow(Rails).to receive(:root).and_return(Pathname.new(temp_root))
    end

    after do
      FileUtils.rm_rf(temp_root)
    end

    context 'when pid file exists' do
      before do
        File.write(pid_file, '12345')
        allow(Process).to receive(:getpgid).with(12345).and_return(12345)
      end

      it 'returns the pid as an integer' do
        result = described_class.current_duo_workflow_service_pid(path)

        expect(result).to eq(12345)
      end
    end

    context 'when pid file does not exist' do
      it 'returns nil' do
        result = described_class.current_duo_workflow_service_pid(path)

        expect(result).to be_nil
      end
    end

    context 'when process is not running' do
      before do
        File.write(pid_file, '12345')
        allow(Process).to receive(:getpgid).with(12345).and_raise(Errno::ESRCH)
      end

      it 'returns nil' do
        result = described_class.current_duo_workflow_service_pid(path)

        expect(result).to be_nil
      end
    end
  end

  describe '.save_duo_workflow_service_pid' do
    let(:temp_root) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_root, path) }
    let(:pid) { 12345 }
    let(:pid_file) { File.join(full_path, 'duo-workflow-service.pid') }

    before do
      FileUtils.mkdir_p(full_path)
      allow(Rails).to receive(:root).and_return(Pathname.new(temp_root))
    end

    after do
      FileUtils.rm_rf(temp_root)
    end

    it 'writes the pid to the file' do
      described_class.save_duo_workflow_service_pid(pid, path)

      expect(File.read(pid_file).to_i).to eq(pid)
    end
  end

  describe '.delete_duo_workflow_service_pid' do
    let(:temp_root) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_root, path) }
    let(:pid_file) { File.join(full_path, 'duo-workflow-service.pid') }

    before do
      FileUtils.mkdir_p(full_path)
      File.write(pid_file, '12345')
      allow(Rails).to receive(:root).and_return(Pathname.new(temp_root))
    end

    after do
      FileUtils.rm_rf(temp_root)
    end

    it 'removes the pid file' do
      expect(File.exist?(pid_file)).to be(true)

      described_class.delete_duo_workflow_service_pid(path)

      expect(File.exist?(pid_file)).to be(false)
    end
  end

  describe '.duo_workflow_service_pid_path' do
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }

    it 'returns the correct path' do
      result = described_class.duo_workflow_service_pid_path(path)

      expect(result.to_s).to end_with('tmp/tests/gitlab-ai-gateway/duo-workflow-service.pid')
    end
  end

  describe '.mark_installed!' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_dir, path) }
    let(:flag_path) { File.join(full_path, 'ai-gateway-installed.txt') }

    before do
      FileUtils.mkdir_p(full_path)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it 'creates the installed flag file' do
      expect(File.exist?(flag_path)).to be(false)

      described_class.mark_installed!(full_path)

      expect(File.exist?(flag_path)).to be(true)
    end
  end

  describe '.installed?' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:path) { 'tmp/tests/gitlab-ai-gateway' }
    let(:full_path) { File.join(temp_dir, path) }
    let(:flag_path) { File.join(full_path, 'ai-gateway-installed.txt') }

    before do
      FileUtils.mkdir_p(full_path)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    context 'when installed flag file exists' do
      before do
        File.write(flag_path, '')
      end

      it 'returns true' do
        result = described_class.installed?(full_path)

        expect(result).to be(true)
      end
    end

    context 'when installed flag file does not exist' do
      it 'returns false' do
        result = described_class.installed?(full_path)

        expect(result).to be(false)
      end
    end
  end

  describe '.git_sha?' do
    it 'returns true for valid 40-character SHA' do
      result = described_class.git_sha?('abc123def456abc123def456abc123def456abc1')

      expect(result).to be(true)
    end

    it 'returns false for branch name' do
      result = described_class.git_sha?('main')

      expect(result).to be(false)
    end
  end

  describe '.refspec_dest' do
    it 'returns the correct refspec destination' do
      allow(described_class).to receive(:ai_gateway_repo_ref).and_return('main')

      result = described_class.refspec_dest

      expect(result).to eq('refs/remotes/origin/main')
    end
  end

  describe '.refspec_src' do
    context 'when ai_gateway_repo_ref is a branch name' do
      before do
        allow(described_class).to receive(:ai_gateway_repo_ref).and_return('main')
        allow(described_class).to receive(:git_sha?).with('main').and_return(false)
      end

      it 'returns the branch refspec' do
        result = described_class.refspec_src

        expect(result).to eq('refs/heads/main')
      end
    end

    context 'when ai_gateway_repo_ref is a SHA' do
      before do
        allow(described_class).to receive(:ai_gateway_repo_ref).and_return('abc123def456abc123def456abc123def456abc1')
        allow(described_class).to receive(:git_sha?).with('abc123def456abc123def456abc123def456abc1').and_return(true)
      end

      it 'returns the SHA directly' do
        result = described_class.refspec_src

        expect(result).to eq('abc123def456abc123def456abc123def456abc1')
      end
    end
  end
end
