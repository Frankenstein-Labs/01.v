# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::CreateRefService, feature_category: :merge_trains do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be_with_reload(:project) { create(:project, :empty_repo) }
    let_it_be(:user) { project.creator }
    let_it_be(:first_parent_ref) { project.default_branch_or_main }
    let_it_be(:source_branch) { 'branch' }
    let(:source_sha) { project.commit(source_branch).sha }
    let(:squash) { false }

    let(:merge_request) do
      create(
        :merge_request,
        title: 'Merge request ref test',
        author: user,
        source_project: project,
        target_project: project,
        source_branch: source_branch,
        target_branch: first_parent_ref,
        squash: squash
      )
    end

    subject(:result) do
      described_class.new(
        current_user: user,
        merge_request: merge_request,
        source_sha: source_sha,
        first_parent_ref: first_parent_ref
      ).execute
    end

    context 'with valid inputs' do
      before_all do
        # ensure first_parent_ref is created before source_sha
        project.repository.create_file(
          user,
          'README.md',
          '',
          message: 'Base parent commit 1',
          branch_name: first_parent_ref
        )
        project.repository.create_branch(source_branch, first_parent_ref)

        # create two commits source_branch to test squashing
        project.repository.create_file(
          user,
          '.gitlab-ci.yml',
          '',
          message: 'Feature branch commit 1',
          branch_name: source_branch
        )

        project.repository.create_file(
          user,
          '.gitignore',
          '',
          message: 'Feature branch commit 2',
          branch_name: source_branch
        )

        # create an extra commit not present on source_branch
        project.repository.create_file(
          user,
          'EXTRA',
          '',
          message: 'Base parent commit 2',
          branch_name: first_parent_ref
        )
      end

      shared_examples_for 'writing with a merge commit' do
        it 'updates commit_sha and merge_commit_sha', :aggregate_failures do
          subject

          expect(merge_request.reload.merge_params['train_ref']).to(
            eq({ 'commit_sha' => result[:commit_sha],
                 'merge_commit_sha' => result[:merge_commit_sha] })
          )
        end
      end

      shared_examples_for 'writing with a squash and merge commit' do
        it 'updates commit_sha, merge_commit_sha and squash_commit_sha', :aggregate_failures do
          subject

          expect(merge_request.reload.merge_params['train_ref']).to(
            eq({ 'commit_sha' => result[:commit_sha],
                 'merge_commit_sha' => result[:merge_commit_sha],
                 'squash_commit_sha' => result[:squash_commit_sha] })
          )
        end
      end

      shared_examples_for 'writing with a squash and no merge commit' do
        it 'updates commit_sha and squash_commit_sha', :aggregate_failures do
          subject

          expect(merge_request.reload.merge_params['train_ref']).to(
            eq({ 'commit_sha' => result[:commit_sha],
                 'squash_commit_sha' => result[:squash_commit_sha] })
          )
        end
      end

      shared_examples_for 'writing without a merge commit' do
        it 'updates commit_sha', :aggregate_failures do
          subject

          expect(merge_request.reload.merge_params['train_ref']).to eq({ 'commit_sha' => result[:commit_sha] })
        end
      end

      shared_examples 'merge commits without squash' do
        it_behaves_like 'writing with a merge commit'
      end

      shared_examples 'merge commits with squash' do
        context 'when squash is requested' do
          let(:squash) { true }
          let(:expected_merge_commit) { merge_request.default_merge_commit_message(user: user) }

          it_behaves_like 'writing with a squash and merge commit'
        end
      end

      context 'when merged commit strategy' do
        include_examples 'merge commits without squash'
        include_examples 'merge commits with squash'
      end

      context 'when semi-linear merge strategy' do
        before do
          project.merge_method = :rebase_merge
          project.save!
        end

        include_examples 'merge commits without squash'
        include_examples 'merge commits with squash'
      end

      context 'when fast-forward merge strategy' do
        before do
          project.merge_method = :ff
          project.save!
        end

        it_behaves_like 'writing without a merge commit'

        context 'when squash set' do
          let(:squash) { true }

          it_behaves_like 'writing with a squash and no merge commit'
        end
      end

      context 'when merge request fails to save' do
        it 'returns an error', :aggregate_failures do
          expect(merge_request).to receive(:save).and_return(false)
          expect(result).to be_error
          expect(result.message).to eq('Failed to update merge params')
        end
      end

      context 'when the underlying ref creation fails' do
        let(:source_sha) { '123' }

        it 'returns the error without persisting train ref merge params', :aggregate_failures do
          expect(merge_request).not_to receive(:save)

          expect(result).to be_error
          expect(merge_request.reload.merge_params).not_to have_key('train_ref')
        end
      end
    end
  end
end
