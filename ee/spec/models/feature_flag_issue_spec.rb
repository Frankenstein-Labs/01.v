# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FeatureFlagIssue, feature_category: :feature_flags do
  describe 'associations' do
    it { is_expected.to belong_to(:feature_flag) }
    it { is_expected.to belong_to(:issue) }
    it { is_expected.to belong_to(:project) }
  end
end
