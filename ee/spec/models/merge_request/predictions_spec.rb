# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequest::Predictions, feature_category: :code_review_workflow do
  describe 'associations' do
    it { is_expected.to belong_to(:merge_request) }
  end
end
