# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteMirror do
  let(:project) { create(:project, :small_repo, :remote_mirror) }

  describe 'validations' do
    context 'when enabling only_protected_branches and mirror_branch_regex' do
      it 'is invalid' do
        remote_mirror = build(:remote_mirror, only_protected_branches: true, mirror_branch_regex: 'text')

        expect(remote_mirror).not_to be_valid
      end
    end

    context 'when disable only_protected_branches and enable mirror_branch_regex' do
      it 'is valid' do
        remote_mirror = build(:remote_mirror, only_protected_branches: false, mirror_branch_regex: 'test')

        expect(remote_mirror).to be_valid
      end

      it 'is invalid with invalid regex' do
        remote_mirror = build(:remote_mirror, only_protected_branches: false, mirror_branch_regex: '\\')

        expect(remote_mirror).not_to be_valid
      end
    end
  end

  describe '#sync?', feature_category: :geo_replication do
    let(:remote_mirror) { project.remote_mirrors.first }

    context 'when the remote mirror is enabled' do
      context 'when the project is a Geo replica' do
        it 'returns false' do
          allow(Gitlab::Geo).to receive(:replica_project?).with(project).and_return(true)

          expect(remote_mirror.sync?).to be(false)
        end
      end

      context 'when the project is not a Geo replica' do
        it 'returns true' do
          allow(Gitlab::Geo).to receive(:replica_project?).with(project).and_return(false)

          expect(remote_mirror.sync?).to be(true)
        end
      end

      context 'when project is nil' do
        let(:remote_mirror) { build(:remote_mirror, project: nil) }

        it 'returns false' do
          expect(remote_mirror.sync?).to be(false)
        end
      end
    end

    context 'when the remote mirror is disabled' do
      it 'returns false without checking Geo replica status' do
        remote_mirror.update!(enabled: false)
        expect(Gitlab::Geo).not_to receive(:replica_project?)

        expect(remote_mirror.sync?).to be(false)
      end
    end
  end

  describe '#sync' do
    let(:remote_mirror) { project.remote_mirrors.first }

    context 'as a Geo secondary' do
      it 'returns nil' do
        allow(Gitlab::Geo).to receive(:replica_project?).with(project).and_return(true)

        expect(remote_mirror.sync).to be_nil
      end
    end
  end

  describe '#only_mirror_protected_branches_column' do
    it 'returns true as only_protected_branches enabled' do
      remote_mirror = build_stubbed(:remote_mirror, only_protected_branches: true)

      expect(remote_mirror.only_mirror_protected_branches_column).to be_truthy
    end

    it 'returns false as only_protected_branches return' do
      remote_mirror = build_stubbed(:remote_mirror, only_protected_branches: false)

      expect(remote_mirror.only_mirror_protected_branches_column).to be_falsy
    end
  end

  describe '#options_for_update' do
    context 'when mirror_branch_regex is set' do
      let(:user) { build(:user) }
      let(:mirror) do
        build(
          :remote_mirror,
          project: project,
          only_protected_branches: false,
          mirror_branch_regex: '^matched*'
        )
      end

      before do
        project.repository.create_branch(branch_name = 'matched', create_commit(branch_name))
        project.repository.create_branch(branch_name = 'mismatched', create_commit(branch_name))
      end

      it 'only sync matched and recently updated branch' do
        options = mirror.options_for_update

        expect(options).to include(only_branches_matching: %w[matched])
      end
    end
  end

  def create_commit(branch_name)
    project.repository.commit_files(
      user,
      branch_name: branch_name,
      message: 'commit message',
      actions: []
    )
  end
end
