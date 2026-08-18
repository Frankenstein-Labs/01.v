# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::GlabSetup, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user, username: 'glab-user') }

  subject(:glab_setup) { described_class.new(current_user: user) }

  describe '#commands' do
    subject(:commands) { glab_setup.commands }

    # The config command wraps a heredoc whose marker is quoted (`<<'GLAB_CONFIG'`).
    def find_config(cmds)
      cmds.find { |c| c.include?('GLAB_CONFIG') && c.start_with?('cat >') }
    end

    # Parses the config hash from the heredoc body written to config.yml.
    def config_yaml(cmds)
      body = find_config(cmds)[/<<'GLAB_CONFIG'\n(.*)\nGLAB_CONFIG/m, 1]
      YAML.safe_load(body)
    end

    context 'when the GitLab URL uses the default HTTPS port' do
      before do
        allow(Gitlab.config.gitlab).to receive(:url).and_return('https://gitlab.example.com')
      end

      it 'installs the configured glab version' do
        archive = "glab_#{described_class::VERSION}_${GLAB_OS}_${GLAB_ARCH}.tar.gz"

        expect(commands).to include(a_string_including("Installing glab@#{described_class::VERSION}"))
        expect(commands).to include(a_string_including(archive))
      end

      it 'puts the glab binary on PATH and verifies the install' do
        expect(commands).to include(%(export PATH="#{described_class::GLAB_BIN_DIR}:$PATH"))
        expect(commands).to include(%(which glab || echo "glab not in PATH"))
        expect(commands).to include(a_string_starting_with('glab version || echo "glab not working.'))
      end

      it 'guards the install against silent failures' do
        install = commands.find { |c| c.include?("Installing glab@") }

        expect(install).to start_with('if command -v glab')
        expect(install).to include('set -o pipefail')
        expect(install).to include('curl --silent --show-error --fail --location')
        expect(install).to include('*) echo "Unsupported architecture: $GLAB_ARCH" >&2; exit 1 ;;')
      end

      it 'installs the command shared with the third-party flow seeder' do
        expect(commands).to include(described_class.install_command)
      end

      it 'does not halt the runner if the install itself fails' do
        install = commands.find { |c| c.include?("Installing glab@") }

        expect(install).to include(
          %{) || echo "Warning: glab installation failed; continuing without glab" >&2}
        )
      end

      it 'writes a glab config for the GitLab host without an explicit port' do
        config = find_config(commands)

        expect(config).to include('api_host: gitlab.example.com')
        expect(config).to include('api_protocol: https')
        expect(config).to include('git_protocol: https')
        expect(config).to include("user: #{user.username}")
        expect(config).not_to include('gitlab.example.com:443')
      end

      it 'does not embed a static auth token field in the config' do
        config = find_config(commands)

        # Anchored to avoid colliding with `oauth2_refresh_token:`, which is
        # a deliberately empty placeholder (see config_file_command).
        expect(config).not_to match(/^\s*token:/)
      end

      it 'creates the config directory and locks down config file permissions' do
        expect(commands).to include('mkdir -p ~/.config/glab-cli')
        expect(commands).to include('chmod 600 ~/.config/glab-cli/config.yml')
      end

      it 'orders install steps before configuration steps before skills install' do
        install_idx = commands.index { |c| c.include?("Installing glab@") }
        config_dir_idx = commands.index('mkdir -p ~/.config/glab-cli')
        chmod_idx = commands.index('chmod 600 ~/.config/glab-cli/config.yml')
        skills_idx = commands.index { |c| c.include?('glab skills install') }

        expect(install_idx).to be < config_dir_idx
        expect(config_dir_idx).to be < chmod_idx
        expect(chmod_idx).to be < skills_idx
      end

      it 'installs glab skills globally' do
        skills_cmd = commands.find { |c| c.include?('glab skills install') }

        expected = 'glab skills install --global || echo "Warning: glab skills install failed; ' \
          'continuing without glab skills"'
        expect(skills_cmd).to eq(expected)
      end
    end

    context 'when the GitLab URL includes a non-default port' do
      before do
        allow(Gitlab.config.gitlab).to receive(:url).and_return('http://gitlab.example.com:3000')
      end

      it 'includes the port in the configured host and uses the matching protocol' do
        config = find_config(commands)

        expect(config).to include('api_host: gitlab.example.com:3000')
        expect(config).to include('api_protocol: http')
        expect(config).to include('git_protocol: http')
      end
    end

    context 'when the GitLab URL is served at the domain root' do
      before do
        allow(Gitlab.config.gitlab).to receive_messages(url: 'https://gitlab.example.com', relative_url_root: '')
      end

      it 'does not emit a subfolder field' do
        config = find_config(commands)

        expect(config).not_to include('subfolder:')
      end
    end

    context 'when the GitLab URL includes a relative URL root' do
      before do
        allow(Gitlab.config.gitlab).to receive_messages(url: 'http://gitlab.example.com:3000/gdk-instance',
          relative_url_root: '/gdk-instance')
      end

      it 'keeps the host free of the subfolder and sets it via the subfolder field' do
        host_config = config_yaml(commands).dig('hosts', 'gitlab.example.com:3000')

        expect(host_config['api_host']).to eq('gitlab.example.com:3000')
        # Relative URL root is carried by glab's first-class subfolder field,
        # not embedded in the host key.
        expect(host_config['subfolder']).to eq('gdk-instance')
      end

      it 'strips surrounding slashes from the subfolder' do
        allow(Gitlab.config.gitlab).to receive(:relative_url_root).and_return('/gdk-instance/')

        host_config = config_yaml(commands).dig('hosts', 'gitlab.example.com:3000')

        expect(host_config['subfolder']).to eq('gdk-instance')
      end

      it 'produces a config body that parses as valid YAML' do
        expect { config_yaml(commands) }.not_to raise_error
        expect(config_yaml(commands).dig('hosts', 'gitlab.example.com:3000', 'subfolder'))
          .to eq('gdk-instance')
      end
    end
  end

  describe '.install_command' do
    subject(:install) { described_class.install_command }

    it 'downloads the pinned version to a file so it can be verified' do
      expect(install).to include(
        %(curl --silent --show-error --fail --location --output #{described_class::GLAB_ARCHIVE} ) +
          %("https://gitlab.com/gitlab-org/cli/-/releases/v#{described_class::VERSION}/downloads/) +
          %(glab_#{described_class::VERSION}_${GLAB_OS}_${GLAB_ARCH}.tar.gz")
      )
    end

    it 'checks the archive against the digest vetted for the running platform' do
      described_class::CHECKSUMS.fetch(described_class::VERSION).each do |platform, digest|
        expect(install).to include("#{platform}) GLAB_SHA256=#{digest} ;;")
      end
    end

    it 'refuses to install on a platform we have no digest for' do
      expect(install).to include('*) echo "No vetted glab checksum for ${GLAB_OS}_${GLAB_ARCH}" >&2; exit 1 ;;')
    end

    # `squish` collapses the two spaces of sha256sum's default format, which
    # would make every check fail as a malformed line.
    it 'passes the digest to sha256sum in binary-mode format' do
      expect(install).to include(
        %(echo "$GLAB_SHA256 *#{described_class::GLAB_ARCHIVE}" | sha256sum --check --quiet && tar --extract)
      )
    end

    it 'pins a digest for every platform it can resolve' do
      digests = described_class::CHECKSUMS.fetch(described_class::VERSION)

      expect(digests.keys).to include('linux_amd64', 'linux_arm64', 'darwin_amd64', 'darwin_arm64')
      expect(digests.values).to all(match(/\A[0-9a-f]{64}\z/))
    end

    context 'when VERSION is bumped without refreshing the digests' do
      before do
        stub_const("#{described_class}::VERSION", '9.9.9')
      end

      it 'refuses to build an install command instead of pairing a new release with stale digests' do
        expect { install }.to raise_error(
          %r{No vetted glab checksums for 9\.9\.9\. Refresh CHECKSUMS from .*/v9\.9\.9/downloads/checksums\.txt}
        )
      end
    end
  end
end
