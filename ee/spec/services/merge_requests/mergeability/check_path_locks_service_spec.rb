# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::Mergeability::CheckPathLocksService, feature_category: :code_review_workflow do
  subject(:check_path_locks) { described_class.new(merge_request: merge_request, params: params) }

  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { build(:merge_request, source_project: project) }
  let(:params) { { skip_locked_paths_check: skip_check } }
  let(:skip_check) { false }
  let(:file_locks_enabled) { true }
  let(:target_branch) { project.default_branch }

  before do
    stub_licensed_features(file_locks: file_locks_enabled)
    allow(merge_request).to receive(:target_branch).and_return(target_branch)
  end

  it_behaves_like 'mergeability check service',
    :locked_paths, 'Checks whether the merge request contains locked paths'

  describe '#execute' do
    subject(:execute) { check_path_locks.execute }

    context 'when file locks is enabled' do
      let(:only_allow_merge_if_pipeline_succeeds) { true }
      let(:changed_paths) do
        [
          instance_double('Gitlab::Git::ChangedPath', path: 'README.md'),
          instance_double('Gitlab::Git::ChangedPath', path: 'conflict.rb'),
          instance_double('Gitlab::Git::ChangedPath', path: 'README.md')
        ]
      end

      before do
        allow(merge_request).to receive(:changed_paths).and_return(changed_paths)
        allow(project.path_locks).to receive(:exists?).and_call_original
        allow(project.path_locks).to receive(:for_paths).and_call_original
      end

      context 'when there are no path locks for this project' do
        it 'returns a check result with status success' do
          expect(execute.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end

        it 'returns early before querying for matching path locks' do
          execute
          expect(project.path_locks).to have_received(:exists?)
          expect(project.path_locks).not_to have_received(:for_paths)
        end
      end

      context 'when there are paths locked by the merge request author' do
        before do
          create(:path_lock, project: project, path: changed_paths.first.path, user: merge_request.author)
        end

        it 'returns a check result with status success' do
          expect(execute.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end

        it 'deduplicates the changed paths' do
          execute
          expect(project.path_locks).to have_received(:exists?)
          expect(project.path_locks).to have_received(:for_paths).with(changed_paths.map(&:path).uniq)
        end
      end

      context 'when there are paths locked by another user' do
        before do
          allow(merge_request).to receive(:author_id).and_return(0)
          create(:path_lock, project: project, path: changed_paths.second.path)
        end

        it 'returns a check result with status failure' do
          expect(execute.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
        end

        it 'deduplicates the changed paths' do
          execute
          expect(project.path_locks).to have_received(:exists?)
          expect(project.path_locks).to have_received(:for_paths).with(changed_paths.map(&:path).uniq)
        end
      end
    end

    context 'when file locks is not enabled' do
      let(:file_locks_enabled) { false }

      it 'returns a check result with inactive status' do
        expect(execute.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      end
    end

    context 'when the target branch is not the default branch' do
      let(:target_branch) { 'not_the_default_branch' }

      it 'returns a check result with inactive status' do
        expect(execute.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      end
    end
  end

  describe '#skip?' do
    subject(:skip) { check_path_locks.skip? }

    context 'when skip check is true' do
      let(:skip_check) { true }

      it { expect(skip).to be(true) }
    end

    context 'when skip check is false' do
      let(:skip_check) { false }

      it { expect(skip).to be(false) }
    end
  end

  describe '#cacheable?' do
    subject(:cacheable) { check_path_locks.cacheable? }

    it { expect(cacheable).to be(true) }
  end

  describe '#cache_key' do
    subject(:cache_key) { check_path_locks.cache_key }

    context 'when the feature flag is enabled' do
      let(:id) { 'id' }
      let(:sha) { 'sha' }
      let(:epoch) { 'epoch' }
      let(:expected_cache_key) { format(described_class::CACHE_KEY, id: id, sha: sha, epoch: epoch) }

      before do
        allow(merge_request).to receive(:id).and_return(id)
        allow(merge_request).to receive(:diff_head_sha).and_return(sha)
        allow(project).to receive(:path_locks_changed_epoch).and_return(epoch)
      end

      it { expect(cache_key).to eq(expected_cache_key) }
    end

    context 'when file locks is disabled' do
      let(:file_locks_enabled) { false }

      it { expect(cache_key).to eq('inactive_path_locks_mergeability_check') }
    end

    context 'when target_branch is not the default_branch' do
      let(:target_branch) { 'not_the_default_branch' }

      it { expect(cache_key).to eq('inactive_path_locks_mergeability_check') }
    end
  end
end
