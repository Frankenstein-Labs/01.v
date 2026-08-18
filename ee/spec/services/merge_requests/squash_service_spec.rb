# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::SquashService, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { project.first_owner }

  let(:commit_message) { nil }
  let(:repository) { project.repository.raw }
  let(:service) do
    described_class.new(merge_request: merge_request, current_user: user, commit_message: commit_message)
  end

  let(:squash_dir_path) do
    File.join(Gitlab.config.shared.path, 'tmp/squash', repository.gl_repository, merge_request.id.to_s)
  end

  let_it_be_with_refind(:merge_request_with_only_new_files) do
    create(
      :merge_request,
      source_branch: 'video', source_project: project,
      target_branch: 'master', target_project: project
    )
  end

  shared_examples 'the squash succeeds' do
    it 'returns the squashed commit SHA' do
      result = service.execute

      expect(result).to match(status: :success, squash_sha: a_string_matching(/\h{40}/))
      expect(result[:squash_sha]).not_to eq(merge_request.diff_head_sha)
    end

    it 'cleans up the temporary directory' do
      service.execute

      expect(File.exist?(squash_dir_path)).to be(false)
    end

    it 'does not keep the branch push event' do
      expect { service.execute }.not_to change { Event.count }
    end

    context 'when there is a single commit in the merge request' do
      let(:mock_sha) { 'sha' }

      before do
        allow(merge_request).to receive(:commits_count).and_return(1)
        allow(merge_request.target_project.repository).to receive(:squash).and_return(mock_sha)
      end

      subject(:result) { service.execute }

      context 'and the squash message does not match the commit message' do
        it 'squashes the commit' do
          expect(result).to match(status: :success, squash_sha: mock_sha)
        end
      end

      context 'when squash message matches commit message' do
        let(:commit_message) { merge_request.first_commit.safe_message }

        it 'returns that commit SHA' do
          expect(result).to match(status: :success, squash_sha: merge_request.diff_head_sha)
        end

        it 'does not perform any git actions' do
          service.execute

          expect(merge_request.target_project.repository).not_to have_received(:squash)
        end
      end

      context 'when squash message matches commit message but without trailing new line' do
        let(:commit_message) { merge_request.first_commit.safe_message.strip }

        it 'returns that commit SHA' do
          expect(result).to match(status: :success, squash_sha: merge_request.diff_head_sha)
        end

        it 'does not perform any git actions' do
          service.execute

          expect(merge_request.target_project.repository).not_to have_received(:squash)
        end
      end
    end

    describe 'the squashed commit' do
      let(:squash_sha) { service.execute[:squash_sha] }

      subject(:squash_commit) { project.repository.commit(squash_sha) }

      it 'copies the author info from the merge request' do
        expect(squash_commit.author_name).to eq(merge_request.author.name)
        expect(squash_commit.author_email).to eq(merge_request.author.email)
      end

      it 'sets the current user as the committer' do
        expect(squash_commit.committer_name).to eq(user.name.chomp('.'))
        expect(squash_commit.committer_email).to eq(user.email)
      end

      it 'has the same diff as the merge request, but a different SHA' do
        mr_diff = project.repository.diff(merge_request.diff_base_sha, merge_request.diff_head_sha)
        squash_diff = project.repository.diff(merge_request.diff_start_sha, squash_sha)

        expect(squash_diff.size).to eq(mr_diff.size)
        expect(squash_commit.sha).not_to eq(merge_request.diff_head_sha)
      end

      it 'has a default squash commit message if no message was provided' do
        expect(squash_commit.message.chomp).to eq(merge_request.default_squash_commit_message.chomp)
      end

      context 'if a message was provided' do
        let(:commit_message) { 'My custom message' }

        it 'has the same message as the message provided' do
          expect(squash_commit.message.chomp).to eq(commit_message)
        end
      end
    end
  end

  shared_examples 'the squash is forbidden' do
    it 'raises a squash error' do
      expect(service.execute).to match(
        status: :error,
        message: "Squashing not allowed: This project doesn't allow you to squash commits when merging."
      )
    end
  end

  describe '#execute' do
    let(:merge_request) { merge_request_with_only_new_files }

    context 'when squashing is forbidden on the project' do
      before do
        allow(merge_request.target_project.project_setting).to receive(:squash_never?).and_return(true)
      end

      it_behaves_like 'the squash is forbidden'

      context 'and squashing is allowed for the target branch' do
        before do
          protected_branch = create(:protected_branch, name: merge_request.target_branch, project: project)
          create(:branch_rule_squash_option, :always, project: project, protected_branch: protected_branch)
        end

        it_behaves_like 'the squash succeeds'
      end
    end

    context 'and squashing is forbidden for the target branch' do
      before do
        protected_branch = create(:protected_branch, name: merge_request.target_branch, project: project)
        create(:branch_rule_squash_option, :never, project: project, protected_branch: protected_branch)
      end

      it_behaves_like 'the squash is forbidden'
    end
  end
end
