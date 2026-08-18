# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BypassContexts::ProtectedBranchContext, feature_category: :security_policy_management do
  subject(:context) { described_class.new }

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  describe '#suppress_reason_required_error?' do
    it 'returns true' do
      expect(context.suppress_reason_required_error?).to be true
    end
  end

  describe '#audit_name' do
    it 'returns protected branch bypass name regardless of type' do
      expect(context.audit_name(:access_token)).to eq('security_policy_protected_branch_bypass')
      expect(context.audit_name(:service_account)).to eq('security_policy_protected_branch_bypass')
      expect(context.audit_name(:user)).to eq('security_policy_protected_branch_bypass')
    end
  end

  describe '#audit_message' do
    let_it_be(:security_policy) { create(:security_policy, linked_projects: [project]) }

    it 'returns protected branch bypass message' do
      message = context.audit_message(bypass_type: :access_token, identifier: [123],
        branch_name: 'main', project: project, user: user, security_policy: security_policy)

      expect(message).to eq(
        "Protected branch restrictions on 'main' for project '#{project.full_path}' " \
          "have been bypassed by #{user.name} using security policy '#{security_policy.name}'"
      )
    end
  end

  describe '#enrich_audit_details' do
    it 'adds project_path, user_name, and protected_branch_bypass flag' do
      details = { bypass_type: :access_token }
      result = context.enrich_audit_details(details, project: project, user: user)

      expect(result).to eq(
        bypass_type: :access_token,
        project_path: project.full_path,
        user_name: user.name,
        protected_branch_bypass: true
      )
    end
  end

  describe '#include_bypass_reason_in_details?' do
    it 'returns true' do
      expect(context.include_bypass_reason_in_details?).to be true
    end
  end

  it_behaves_like 'a bypass context with push options bypass reason'
end
