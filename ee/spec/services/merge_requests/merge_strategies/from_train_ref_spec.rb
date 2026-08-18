# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::MergeStrategies::FromTrainRef, feature_category: :merge_trains do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user) }

  let(:merge_request) { create(:merge_request, :simple, author: user2, assignees: [user2], squash: squash_on_merge) }
  let(:squash_on_merge) { false }
  let(:project) { merge_request.project }
  let(:merge_train_car) { create(:merge_train_car, merge_request: merge_request, target_project: project) }
  let(:source_sha) { merge_train_car&.pipeline&.sha }
  let(:train_ref_merge_params) { { 'commit_sha' => source_sha } }

  # Result of the mergeability run. Feeds not_mergable? and the failure
  # explanation when the detailed-reasons flag is on. Overridden below.
  let(:mergeability_response) { ServiceResponse.success(payload: { results: [] }) }

  subject(:strategy) { described_class.new(merge_request, user) }

  before do
    allow(merge_request).to receive(:check_mergeability)
    allow(merge_request).to receive(:execute_merge_checks).and_return(mergeability_response)
    merge_request.update!(merge_params: { 'train_ref' => train_ref_merge_params })
    project.add_maintainer(user)
  end

  describe '#validate!' do
    context 'when source is missing' do
      let!(:merge_train_car) { nil }

      it 'raises source error when source is missing' do
        error_message = 'No source for merge'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end

    context 'when merge request should be squashed but is not' do
      let(:squash_on_merge) { true }

      it 'raises squashing error' do
        error_message = 'Outdated merge train: Squash commit SHA missing.'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end

    context 'when merge request should not be squashed but it is' do
      let(:squash_on_merge) { false }
      let(:train_ref_merge_params) { { 'commit_sha' => source_sha, 'squash_commit_sha' => 'the squash commit sha' } }

      it 'raises squashing error' do
        error_message = 'Outdated merge train: Unexpected commit SHA in train ref parameters.'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end

    context 'when the merge train ref has changed in the meantime' do
      before do
        allow(project.repository).to(
          receive(:commit)
            .with(merge_request.train_ref_path)
            .and_return(instance_double(Gitlab::Git::Commit, sha: nil))
        )
      end

      it 'raises outdated merge source error' do
        error_message = 'Outdated merge train: Merge source out-of-date.'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end

    context 'when merge request is not mergeable' do
      let(:mergeability_response) do
        ServiceResponse.error(
          message: 'Checks were not successful',
          payload: { unsuccessful_check_explanation: 'The merge request must not be a draft.' }
        )
      end

      it 'raises a mergeability error naming the blocking explanation' do
        expect { strategy.validate! }.to raise_error(
          MergeRequests::MergeStrategies::StrategyError,
          'Merge request is not mergeable. Explanation: The merge request must not be a draft.'
        )
      end

      context 'when the blocking check has no explanation' do
        let(:mergeability_response) do
          ServiceResponse.error(message: 'Checks were not successful', payload: {})
        end

        it 'raises with the plain mergeability message' do
          expect { strategy.validate! }.to raise_error(
            MergeRequests::MergeStrategies::StrategyError,
            'Merge request is not mergeable'
          )
        end
      end
    end

    context 'when the merge request is genuinely not mergeable (real checks)' do
      let(:merge_request) do
        create(:merge_request, :simple, author: user2, assignees: [user2], title: 'Draft: needs work')
      end

      before do
        # Run the real mergeability checks (the draft check is a cheap state
        # check, so no merge-ref sync is needed) to prove the blocking check
        # flows end-to-end into the failure explanation.
        allow(merge_request).to receive(:execute_merge_checks).and_call_original
      end

      it 'raises with the explanation from the actual blocking check' do
        expect { strategy.validate! }.to raise_error(
          MergeRequests::MergeStrategies::StrategyError,
          'Merge request is not mergeable. Explanation: The merge request must not be a draft.'
        )
      end
    end
  end

  describe '#execute_git_merge!' do
    subject(:result) { strategy.execute_git_merge! }

    it 'performs a fast-forward merge', :aggregate_failures do
      expect(merge_request.target_project.repository).to receive(:ff_merge).and_call_original
      expect(result[:commit_sha]).to eq(project.commit(merge_request.target_branch).sha)
    end

    it 'returns the symbolized train ref merge params', :aggregate_failures do
      merge_request.update!(merge_params: { 'train_ref' => train_ref_merge_params.merge('some_key' => 'some value') })
      expect(result).to eq train_ref_merge_params.symbolize_keys.merge(some_key: 'some value')
    end

    it 'returns an empty hash if #ff_merge does not return a sha' do
      expect(merge_request.target_project.repository).to receive(:ff_merge).and_return nil
      expect(result).to eq({})
    end
  end
end
