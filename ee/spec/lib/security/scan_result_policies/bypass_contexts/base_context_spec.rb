# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BypassContexts::BaseContext, feature_category: :security_policy_management do
  subject(:context) { described_class.new }

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:security_policy) { create(:security_policy, linked_projects: [project]) }

  describe '#suppress_reason_required_error?' do
    it 'returns false by default' do
      expect(context.suppress_reason_required_error?).to be false
    end
  end

  describe '#audit_name' do
    it 'raises NotImplementedError' do
      expect { context.audit_name(:user) }.to raise_error(NotImplementedError)
    end
  end

  describe '#audit_message' do
    it 'raises NotImplementedError' do
      expect do
        context.audit_message(bypass_type: :user, identifier: 1,
          branch_name: 'main', project: project, user: user, security_policy: security_policy)
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#enrich_audit_details' do
    it 'returns details unchanged by default' do
      details = { bypass_type: :access_token }
      result = context.enrich_audit_details(details, project: project, user: user)

      expect(result).to eq(details)
    end
  end

  describe '#include_bypass_reason_in_details?' do
    it 'returns false by default' do
      expect(context.include_bypass_reason_in_details?).to be false
    end
  end

  describe '#bypass_reason' do
    it 'returns nil by default' do
      expect(context.bypass_reason).to be_nil
    end
  end
end
