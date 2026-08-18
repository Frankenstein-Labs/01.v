# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BypassContexts::MergeRequestContext, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:security_policy) { create(:security_policy, linked_projects: [project]) }
  let(:reason) { 'Emergency fix' }

  subject(:context) { described_class.new(merge_request: merge_request, reason: reason) }

  describe '#audit_name' do
    it 'returns merge request bypass name regardless of type' do
      expect(context.audit_name(:merge_request)).to eq('security_policy_merge_request_bypass')
      expect(context.audit_name(:user)).to eq('security_policy_merge_request_bypass')
    end
  end

  describe '#audit_message' do
    it 'returns merge request bypass message for regular user' do
      message = context.audit_message(bypass_type: :merge_request, identifier: nil,
        branch_name: 'main', project: project, user: user, security_policy: security_policy)

      expect(message).to eq(
        "Security policy #{security_policy.name} in merge request " \
          "(#{project.full_path}!#{merge_request.iid}) has been bypassed by #{user.name}"
      )
    end

    context 'when bypass_type is access_token' do
      it 'includes bot user description in the message' do
        message = context.audit_message(bypass_type: :access_token, identifier: nil,
          branch_name: 'main', project: project, user: user, security_policy: security_policy)

        expect(message).to eq(
          "Security policy #{security_policy.name} in merge request " \
            "(#{project.full_path}!#{merge_request.iid}) has been bypassed by access token #{user.name}"
        )
      end
    end

    context 'when bypass_type is service_account' do
      it 'includes service account description in the message' do
        message = context.audit_message(bypass_type: :service_account, identifier: nil,
          branch_name: 'main', project: project, user: user, security_policy: security_policy)

        expect(message).to eq(
          "Security policy #{security_policy.name} in merge request " \
            "(#{project.full_path}!#{merge_request.iid}) has been bypassed by service account #{user.name}"
        )
      end
    end
  end

  describe '#enrich_audit_details' do
    it 'adds merge request details with merge_request bypass_type when not present in details' do
      details = { some_key: :some_value }
      result = context.enrich_audit_details(details, project: project, user: user)

      expect(result).to eq(
        some_key: :some_value,
        bypass_type: :merge_request,
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        reason: reason
      )
    end

    it 'preserves existing bypass_type from details' do
      details = { bypass_type: :access_token, access_token_ids: [1, 2] }
      result = context.enrich_audit_details(details, project: project, user: user)

      expect(result).to eq(
        bypass_type: :access_token,
        access_token_ids: [1, 2],
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        reason: reason
      )
    end
  end
end
