# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Project::RepositorySquashRestorer, feature_category: :importers do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, creator: user) }

  let(:shared) { project.import_export_shared }
  let(:restorer) { described_class.new(project: project, shared: shared, user: user) }

  before_all do
    project.add_maintainer(user)
  end

  describe '#restore' do
    context 'when repository has multiple commits' do
      it 'squashes repository history and preserves content' do
        original_files = project.repository.ls_files('HEAD')
        default_branch = project.repository.root_ref

        expect(project.repository.commit.parent_ids).to be_present
        expect(shared.logger).to receive(:info).with(
          hash_including(message: 'Squashing repository history for custom template import')
        )

        expect(restorer.restore).to be true

        # Verify squash results
        expect(project.repository.commit_count).to eq(2)
        expect(project.repository.root_ref).to eq(default_branch)

        # Verify commit structure
        head_commit = project.repository.commit
        initial_commit = project.repository.initial_commit

        expect(head_commit.message.chomp).to eq("Initialize from template: #{project.name}")
        expect(head_commit.parent_ids).to eq([initial_commit.sha])

        # Verify content preserved
        expect(project.repository.ls_files('HEAD')).to match_array(original_files)
      end
    end

    context 'when repository has only one commit' do
      let_it_be_with_reload(:project) { create(:project, :empty_repo, creator: user) }

      before_all do
        project.repository.create_file(
          user, 'README.md', 'content',
          message: 'Initial commit', branch_name: 'main'
        )
      end

      it 'skips squashing and returns true' do
        expect(shared.logger).to receive(:info).with(
          hash_including(message: 'Skipping repository squash: repository has only one commit')
        )
        expect(project.repository).not_to receive(:squash_commits)

        expect(restorer.restore).to be true
        expect(project.repository.commit_count).to eq(1)
      end
    end

    context 'when repository is empty' do
      let_it_be(:project) { create(:project, :empty_repo, creator: user) }

      it 'skips squashing and returns true' do
        expect(shared.logger).to receive(:info).with(
          hash_including(message: 'Skipping repository squash: repository is empty or does not exist')
        )

        expect(restorer.restore).to be true
      end
    end

    context 'when repository does not exist' do
      before do
        allow(project.repository).to receive(:exists?).and_return(false)
      end

      it 'skips squashing and returns true' do
        expect(shared.logger).to receive(:info).with(
          hash_including(message: 'Skipping repository squash: repository is empty or does not exist')
        )

        expect(restorer.restore).to be true
      end
    end

    context 'when head_commit is nil' do
      before do
        allow(project.repository).to receive(:commit).and_return(nil)
      end

      it 'skips squashing and returns true' do
        expect(shared.logger).to receive(:info).with(
          hash_including(message: 'Skipping repository squash: repository has only one commit')
        )

        expect(restorer.restore).to be true
      end
    end

    context 'when head_commit has empty parent_ids' do
      before do
        commit = project.repository.commit
        allow(commit).to receive(:parent_ids).and_return([])
        allow(project.repository).to receive(:commit).and_return(commit)
      end

      it 'skips squashing and returns true' do
        expect(shared.logger).to receive(:info).with(
          hash_including(message: 'Skipping repository squash: repository has only one commit')
        )

        expect(restorer.restore).to be true
      end
    end

    context 'when an error occurs during squash' do
      let_it_be_with_reload(:project) { create(:project, :repository, creator: user) }

      before do
        allow(project.repository).to receive(:squash_commits)
          .and_raise(StandardError, 'Squash failed')
      end

      it 'records the error and returns false' do
        expect(restorer.restore).to be false
        expect(shared.errors).to include(match(/Squash failed/))
      end
    end

    context 'when squash_history_for_project_templates feature flag is disabled' do
      before do
        stub_feature_flags(squash_history_for_project_templates: false)
      end

      it 'returns true without squashing' do
        expect(project.repository).not_to receive(:squash_commits)

        expect(restorer.restore).to be true
      end
    end
  end
end
