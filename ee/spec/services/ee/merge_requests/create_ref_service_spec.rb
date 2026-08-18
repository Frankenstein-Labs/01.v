# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreateRefService, feature_category: :merge_trains do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be_with_reload(:project) { create(:project, :empty_repo) }
    let_it_be(:user) { project.creator }
    let_it_be(:first_parent_ref) { project.default_branch_or_main }
    let_it_be(:source_branch) { 'branch' }
    let(:target_ref) { "refs/merge-requests/#{merge_request.iid}/train" }
    let(:source_sha) { project.commit(source_branch).sha }
    let(:squash) { false }
    let(:default_commit_message) { merge_request.default_merge_commit_message(user: user) }
    let(:expected_commit_message) { "#{merge_request.title}\n" }
    let(:merge_params) { {} }

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

    let(:service) do
      described_class.new(
        current_user: user,
        merge_request: merge_request,
        target_ref: target_ref,
        source_sha: source_sha,
        first_parent_ref: first_parent_ref,
        merge_params: merge_params
      )
    end

    subject(:result) do
      service.execute
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
      shared_examples 'generate ref merge request commits' do |commit_count|
        context 'when coming from a merge train' do
          let!(:train_car) { create(:merge_train_car, merge_request: merge_request) }

          it 'created generated ref merge request commits' do
            result

            expect(MergeRequests::GeneratedRefCommit.where.not(project: project, merge_request_iid: merge_request.iid))
              .to be_empty

            expect(MergeRequests::GeneratedRefCommit.where(project: project,
              merge_request_iid: merge_request.iid).count).to eq(
                commit_count
              )
          end
        end
      end

      shared_examples 'does not generate ref merge request commits' do
        it 'does not create generated ref merge request commits' do
          result

          expect(MergeRequests::GeneratedRefCommit.exists?).to be false
        end
      end

      context 'when a database error occurs' do
        let!(:train_car) { create(:merge_train_car, merge_request: merge_request) }

        before do
          project.merge_method = :rebase_merge
          project.save!
          allow(project).to receive(:can_create_new_ref_commits?).and_return(true)
        end

        context 'when pg error' do
          before do
            allow(MergeRequests::GeneratedRefCommit).to receive(:upsert_all).and_raise(PG::Error)
          end

          it 'rescues and logs PG::Error' do
            expect(Gitlab::AppLogger).to receive(:error).with(
              a_string_including("Failed to store generated ref commits")
            )

            result
          end
        end
      end

      context 'when merged commit strategy' do
        include_examples 'does not generate ref merge request commits'
      end

      context 'when semi-linear merge strategy' do
        before do
          project.merge_method = :rebase_merge
          project.save!
        end

        include_examples 'generate ref merge request commits', 3
      end

      context 'when fast-forward merge strategy' do
        before do
          project.merge_method = :ff
          project.save!
        end

        it_behaves_like 'generate ref merge request commits', 2
      end
    end
  end
end
