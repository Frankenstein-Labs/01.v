# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BypassContexts::PushPolicyContext, feature_category: :security_policy_management do
  subject(:context) { described_class.new(push_options: push_options) }

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let(:push_options) { nil }

  describe '#audit_name' do
    it 'returns type-specific push bypass name' do
      expect(context.audit_name(:access_token)).to eq('security_policy_access_token_push_bypass')
      expect(context.audit_name(:service_account)).to eq('security_policy_service_account_push_bypass')
      expect(context.audit_name(:user)).to eq('security_policy_user_push_bypass')
    end
  end

  describe '#audit_message' do
    let_it_be(:security_policy) { create(:security_policy, linked_projects: [project]) }

    it 'returns branch push restriction message' do
      message = context.audit_message(bypass_type: :access_token, identifier: [123],
        branch_name: 'main', project: project, user: user, security_policy: security_policy)

      expect(message).to eq(
        "Branch push restriction on 'main' for project '#{project.full_path}' " \
          "has been bypassed by access_token with ID: [123]"
      )
    end
  end

  it_behaves_like 'a bypass context with push options bypass reason'
end
