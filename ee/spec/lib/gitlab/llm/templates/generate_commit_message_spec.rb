# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::GenerateCommitMessage, feature_category: :code_review_workflow do
  let_it_be(:merge_request) { create(:merge_request) }

  subject { described_class.new(merge_request) }

  describe '#to_prompt' do
    it 'includes raw diff' do
      diff_file = merge_request.raw_diffs.to_a[0]

      expect(subject.to_prompt[:messages][0][:content]).to include(diff_file.diff.split("\n")[1])
    end
  end
end
