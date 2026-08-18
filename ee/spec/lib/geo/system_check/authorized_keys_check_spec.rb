# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::AuthorizedKeysCheck, :silence_stdout, feature_category: :geo_replication do
  subject(:authorized_keys_check) { described_class.new }

  describe '#multi_check' do
    before do
      allow(File).to receive(:file?).and_call_original # provides a default behavior when mocking
      allow(File).to receive(:file?)
                       .with('/opt/gitlab/embedded/service/gitlab-shell/bin/gitlab-shell-authorized-keys-check')
                       .and_return(true)
    end

    context 'with OpenSSH config file' do
      context 'in docker' do
        it 'fails when config file does not exist' do
          allow(authorized_keys_check).to receive(:in_docker?).and_return(true)
          allow(File).to receive(:file?).with('/assets/sshd_config').and_return(false)

          expect_failure('Cannot find OpenSSH configuration file at: /assets/sshd_config')

          authorized_keys_check.multi_check
        end
      end

      it 'fails when config file does not exist' do
        allow(authorized_keys_check).to receive(:in_docker?).and_return(false)
        allow(File).to receive(:file?).with('/etc/ssh/sshd_config').and_return(false)

        expect_failure('Cannot find OpenSSH configuration file at: /etc/ssh/sshd_config')

        authorized_keys_check.multi_check
      end

      it 'skips when config file is not readable' do
        override_sshd_config('system_check/sshd_config')
        allow(File).to receive(:readable?).with(expand_fixture_path('system_check/sshd_config',
          dir: 'ee')).and_return(false)

        expect_skipped('Cannot access OpenSSH configuration file')

        authorized_keys_check.multi_check
      end
    end

    context 'with AuthorizedKeysCommand' do
      it 'fails when config file does not contain the AuthorizedKeysCommand' do
        override_sshd_config('system_check/sshd_config_no_command')

        expect_failure('OpenSSH configuration file does not contain an AuthorizedKeysCommand')

        authorized_keys_check.multi_check
      end

      it 'warns when config file does not contain the correct AuthorizedKeysCommand' do
        override_sshd_config('system_check/sshd_config_invalid_command')

        expect_warning('OpenSSH configuration file points to a different AuthorizedKeysCommand')

        authorized_keys_check.multi_check
      end

      it 'fails when cannot find referred authorized keys file on disk' do
        override_sshd_config('system_check/sshd_config')
        allow(authorized_keys_check)
          .to receive(:extract_authorized_keys_command).and_return('/tmp/nonexistent/authorized_keys')

        expect_failure('Cannot find configured AuthorizedKeysCommand: /tmp/nonexistent/authorized_keys')

        authorized_keys_check.multi_check
      end
    end

    context 'with AuthorizedKeysCommandUser' do
      it 'fails when config file does not contain the AuthorizedKeysCommandUser' do
        override_sshd_config('system_check/sshd_config_no_user')

        expect_failure('OpenSSH configuration file does not contain an AuthorizedKeysCommandUser')

        authorized_keys_check.multi_check
      end

      it 'fails when config file does not contain the correct AuthorizedKeysCommandUser' do
        override_sshd_config('system_check/sshd_config_invalid_user')

        expect_warning('OpenSSH configuration file points to a different AuthorizedKeysCommandUser')

        authorized_keys_check.multi_check
      end
    end

    it 'succeed when all conditions are met' do
      override_sshd_config('system_check/sshd_config')
      allow(authorized_keys_check).to receive(:gitlab_user).and_return('git')

      result = authorized_keys_check.multi_check
      expect($stdout.string).to include('yes')
      expect(result).to be_truthy
    end
  end

  describe '#extract_authorized_keys_command' do
    it 'returns false when no command is available' do
      override_sshd_config('system_check/sshd_config_no_command')

      expect(authorized_keys_check.extract_authorized_keys_command).to be_falsey
    end

    it 'returns correct (uncommented) command' do
      override_sshd_config('system_check/sshd_config')

      expect(authorized_keys_check.extract_authorized_keys_command)
        .to eq('/opt/gitlab/embedded/service/gitlab-shell/bin/gitlab-shell-authorized-keys-check git %u %k')
    end

    it 'returns correct (leading whitespace) command' do
      override_sshd_config('system_check/sshd_config_leading_whitespace')

      expect(authorized_keys_check.extract_authorized_keys_command)
        .to eq('/opt/gitlab/embedded/service/gitlab-shell/bin/gitlab-shell-authorized-keys-check git %u %k')
    end

    it 'returns command without comments and without quotes' do
      override_sshd_config('system_check/sshd_config_invalid_command')

      expect(authorized_keys_check.extract_authorized_keys_command)
        .to eq('/opt/gitlab-shell/invalid_authorized_keys   %u      %k')
    end
  end

  describe '#extract_authorized_keys_command_user' do
    it 'returns false when no command user is available' do
      override_sshd_config('system_check/sshd_config_no_command')

      expect(authorized_keys_check.extract_authorized_keys_command_user).to be_falsey
    end

    it 'returns correct (uncommented) command' do
      override_sshd_config('system_check/sshd_config')

      expect(authorized_keys_check.extract_authorized_keys_command_user).to eq('git')
    end

    it 'returns correct (leading whitespace) command' do
      override_sshd_config('system_check/sshd_config_leading_whitespace')

      expect(authorized_keys_check.extract_authorized_keys_command_user).to eq('git')
    end

    it 'returns command without comments' do
      override_sshd_config('system_check/sshd_config_invalid_command')

      expect(authorized_keys_check.extract_authorized_keys_command_user).to eq('anotheruser')
    end
  end

  describe '#openssh_config_path' do
    context 'when in docker container' do
      it 'returns /assets/sshd_config' do
        allow(authorized_keys_check).to receive(:in_docker?).and_return(true)

        expect(authorized_keys_check.openssh_config_path).to eq('/assets/sshd_config')
      end
    end

    context 'when not in docker container' do
      it 'returns /etc/ssh/sshd_config' do
        allow(authorized_keys_check).to receive(:in_docker?).and_return(false)

        expect(authorized_keys_check.openssh_config_path).to eq('/etc/ssh/sshd_config')
      end
    end
  end

  def expect_failure(reason)
    expect(subject).to receive(:print_failure).with(reason).and_call_original
  end

  def expect_warning(reason)
    expect(subject).to receive(:print_warning).with(reason).and_call_original
  end

  def expect_skipped(reason)
    expect(subject).to receive(:print_skipped).with(reason).and_call_original
  end

  def override_sshd_config(relative_path)
    allow(subject).to receive(:openssh_config_path) { expand_fixture_path(relative_path, dir: 'ee') }
  end
end
