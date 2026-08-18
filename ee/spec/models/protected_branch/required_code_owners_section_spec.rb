# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranch::RequiredCodeOwnersSection, feature_category: :source_code_management do
  describe 'associations' do
    it { is_expected.to belong_to(:protected_branch) }
  end
end
