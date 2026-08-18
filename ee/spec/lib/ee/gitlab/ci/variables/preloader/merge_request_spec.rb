# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Variables::Preloader::MergeRequest, feature_category: :pipeline_composition do
  let_it_be(:merge_request) { create(:merge_request) }

  subject(:preload) { described_class.new(merge_request).preload }

  describe '#preload' do
    context 'when committer approval is not restricted' do
      before do
        allow(merge_request).to receive(:merge_requests_disable_committers_approval?).and_return(false)
      end

      it 'does not preload the merge request diff commits' do
        preload

        expect(merge_request.merge_request_diff.association(:merge_request_diff_commits).loaded?).to be(false)
      end
    end

    context 'when committer approval is restricted' do
      before do
        allow(merge_request).to receive(:merge_requests_disable_committers_approval?).and_return(true)
      end

      it 'preloads the merge request diff commits' do
        preload

        expect(merge_request.merge_request_diff.association(:merge_request_diff_commits).loaded?).to be(true)
      end
    end
  end
end
