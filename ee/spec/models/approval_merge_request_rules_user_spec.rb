# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalMergeRequestRulesUser, factory_default: :keep, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }

  describe 'validations' do
    it { is_expected.to belong_to(:project).required }
  end
end
