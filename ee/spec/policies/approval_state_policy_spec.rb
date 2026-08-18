# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalStatePolicy, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let(:approval_state) { ApprovalState.new(merge_request) }

  subject(:policy) { described_class.new(user, approval_state) }

  context 'when user does not have access to project' do
    it { expect_disallowed(:read_merge_request) }
  end

  context 'when user does have access to project' do
    before_all do
      project.add_developer(user)
    end

    it { expect_allowed(:read_merge_request) }
  end
end
