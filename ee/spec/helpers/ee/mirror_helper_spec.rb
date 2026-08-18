# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::MirrorHelper, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  describe '#repository_mirrors_available?' do
    let(:project) { build_stubbed(:project) }

    before do
      helper.instance_variable_set(:@project, project)
    end

    where(:licensed, :expected) do
      true  | true
      false | false
    end

    with_them do
      it 'reflects the repository_mirrors licensed feature' do
        allow(project).to receive(:licensed_feature_available?).with(:repository_mirrors).and_return(licensed)

        expect(helper.repository_mirrors_available?).to be(expected)
      end
    end
  end

  describe '#pull_mirror_table_data' do
    let(:project) { build_stubbed(:project) }
    let(:import_state) { build_stubbed(:import_state, project: project, status: 'finished') }
    let(:import_data) { instance_double(ProjectImportData, ssh_key_auth?: false, ssh_public_key: nil) }

    before do
      allow(project).to receive_messages(
        mirror?: true,
        import_state: import_state,
        import_data: import_data,
        safe_import_url: 'https://*****:*****@example.com/repo.git',
        self_or_ancestors_archived?: false
      )
      allow(import_state).to receive_messages(
        mirror_update_due?: false,
        updating_mirror?: false
      )
      allow(import_data).to receive_messages(
        ssh_key_auth?: false,
        ssh_public_key: nil
      )
    end

    subject(:result) { Gitlab::Json.safe_parse(helper.pull_mirror_table_data(project)) }

    it 'returns serialized pull mirror data' do
      allow(import_state).to receive_messages(
        last_update_started_at: Time.zone.parse('2024-01-01 00:00:00'),
        last_successful_update_at: Time.zone.parse('2024-01-01 00:00:00'),
        last_error: nil
      )

      expect(result['id']).to eq(import_state.id)
      expect(result['enabled']).to be(true)
      expect(result['url']).to eq('https://*****:*****@example.com/repo.git')
      expect(result['direction']).to eq('pull')
      expect(result['last_update_started_at']).to eq('2024-01-01T00:00:00Z')
      expect(result['last_update_at']).to eq('2024-01-01T00:00:00Z')
      expect(result['last_error']).to be_nil
      expect(result['update_status']).to eq('finished')
      expect(result['ssh_key_auth']).to be(false)
      expect(result).to have_key('mirror_branches_setting')
      expect(result).to have_key('mirror_branch_regex')
    end

    context 'with mirror branches setting' do
      it 'includes mirror_branches_setting and mirror_branch_regex from the project' do
        allow(project).to receive_messages(
          mirror_branches_setting: 'regex',
          mirror_branch_regex: 'main|release.*'
        )

        expect(result['mirror_branches_setting']).to eq('regex')
        expect(result['mirror_branch_regex']).to eq('main|release.*')
      end
    end

    it 'returns nil when project is not a mirror' do
      allow(project).to receive(:mirror?).and_return(false)

      expect(helper.pull_mirror_table_data(project)).to be_nil
    end

    it 'returns nil when import_state is nil' do
      allow(project).to receive(:import_state).and_return(nil)

      expect(helper.pull_mirror_table_data(project)).to be_nil
    end

    context 'when mirror update is in progress' do
      it 'returns update_status as started when updating_mirror?' do
        allow(import_state).to receive(:updating_mirror?).and_return(true)

        expect(result['update_status']).to eq('started')
      end

      it 'returns update_status as started when mirror_update_due?' do
        allow(import_state).to receive(:mirror_update_due?).and_return(true)

        expect(result['update_status']).to eq('started')
      end
    end

    context 'when last error is present' do
      before do
        allow(import_state).to receive(:last_error).and_return(" Connection refused \n")
      end

      it 'strips the error message' do
        expect(result['last_error']).to eq('Connection refused')
      end
    end

    context 'when project is archived' do
      before do
        allow(project).to receive(:self_or_ancestors_archived?).and_return(true)
      end

      it 'sets archived to true' do
        expect(result['archived']).to be(true)
      end
    end

    context 'when import_data has SSH key auth' do
      before do
        allow(import_data).to receive_messages(ssh_key_auth?: true, ssh_public_key: 'ssh-rsa AAAA...')
      end

      it 'includes SSH key information' do
        expect(result['ssh_key_auth']).to be(true)
        expect(result['ssh_public_key']).to eq('ssh-rsa AAAA...')
      end
    end
  end

  describe '#remote_mirrors_table_data' do
    let(:remote_mirror) do
      build_stubbed(:remote_mirror,
        url: 'https://user:pass@example.com/mirror.git',
        enabled: true,
        last_update_started_at: Time.zone.parse('2024-01-01 00:00:00'),
        last_update_at: Time.zone.parse('2024-01-01 00:00:00'),
        last_error: nil,
        update_status: 'finished')
    end

    before do
      allow(remote_mirror).to receive_messages(
        safe_url: 'https://user:*****@example.com/mirror.git',
        ssh_key_auth?: false,
        ssh_public_key: nil,
        mirror_branches_setting: 'all',
        mirror_branch_regex: nil
      )
      allow(remote_mirror).to receive(:read_attribute).with(:enabled).and_return(true)
    end

    subject(:result) { Gitlab::Json.safe_parse(helper.remote_mirrors_table_data([remote_mirror])) }

    it 'includes EE mirror branch keys for push mirrors' do
      mirror_data = result.first

      expect(mirror_data['mirror_branches_setting']).to eq('all')
      expect(mirror_data).to have_key('mirror_branch_regex')
    end
  end
end
