# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyDismissalPolicy, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
  let_it_be(:policy_dismissal) { create(:policy_dismissal, project: project, merge_request: merge_request) }

  subject(:policy) { described_class.new(user, policy_dismissal) }

  describe 'read_security_resource' do
    context 'when user has permission on the project' do
      before_all do
        project.add_developer(user)
      end

      before do
        stub_licensed_features(security_dashboard: true)
      end

      it { is_expected.to be_allowed(:read_security_resource) }
    end

    context 'when user does not have permission on the project' do
      it { is_expected.to be_disallowed(:read_security_resource) }
    end
  end
end
