# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::DismissPolicyViolationsService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:current_user) { create(:user) }

  let(:params) do
    {
      security_policy_ids: [policy.id],
      dismissal_types: [Security::PolicyDismissal::DISMISSAL_TYPES[:other]],
      comment: 'Test dismissal'
    }
  end

  let_it_be(:policy) { create(:security_policy, :enforcement_type_warn) }
  let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

  let_it_be(:policy_without_warn_mode) { create(:security_policy) }

  subject(:service) { described_class.new(merge_request, current_user: current_user, params: params) }

  describe '#execute' do
    before_all do
      # violation for a different policy to ensure it is not included
      another_policy = create(:security_policy, :enforcement_type_warn)
      approval_policy_rule = create(:approval_policy_rule, security_policy: another_policy)
      create(:scan_result_policy_violation,
        :new_scan_finding,
        merge_request: merge_request,
        security_policy: another_policy,
        project: project,
        approval_policy_rule: approval_policy_rule,
        uuids: %w[uuid-5])
    end

    context 'when there are no warn mode policies' do
      let(:params) { super().merge(security_policy_ids: [policy_without_warn_mode.id]) }

      it 'returns an error' do
        response = service.execute

        expect(response.success?).to be_falsey
        expect(response.message).to eq('No warn mode policies are found.')
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { service.execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { service.execute }
      end
    end

    context 'when there are no violations for the policy' do
      it 'returns success and does not create a dismissal' do
        expect { service.execute }.not_to change { Security::PolicyDismissal.count }

        response = service.execute
        expect(response.success?).to be_truthy
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { service.execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { service.execute }
      end
    end

    context 'when there are violations for the policy' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation,
          :new_scan_finding,
          merge_request: merge_request,
          security_policy: policy,
          project: project,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1])
      end

      let_it_be(:violation_2) do
        create(:scan_result_policy_violation,
          :previous_scan_finding,
          merge_request: merge_request,
          security_policy: policy,
          project: project,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-2 uuid-3]
        )
      end

      it 'returns a success response' do
        response = service.execute

        expect(response).to be_success
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { service.execute }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { service.execute }
      end

      it 'creates a policy dismissal with the correct attributes' do
        expect { service.execute }.to change { Security::PolicyDismissal.count }.by(1)

        dismissal = Security::PolicyDismissal.last

        expect(dismissal).to have_attributes(
          security_policy_id: policy.id,
          merge_request_id: merge_request.id,
          project_id: project.id,
          user_id: current_user.id,
          dismissal_types: [Security::PolicyDismissal::DISMISSAL_TYPES[:other]],
          comment: 'Test dismissal'
        )

        expect(dismissal.security_findings_uuids).to match_array(%w[uuid-1 uuid-2 uuid-3])
      end

      context 'when a dismissal already exists' do
        let_it_be(:existing_dismissal) do
          create(:policy_dismissal,
            security_policy: policy,
            merge_request: merge_request,
            project: project,
            security_findings_uuids: %w[uuid-old])
        end

        it 'upserts the dismissal' do
          expect { service.execute }.not_to change { Security::PolicyDismissal.count }

          existing_dismissal.reload

          expect(existing_dismissal.security_findings_uuids).to match_array(%w[uuid-1 uuid-2 uuid-3])
        end
      end
    end

    context 'when the violations doesn\'t have uuid' do
      let_it_be(:violation_without_uuid) do
        create(:scan_result_policy_violation,
          merge_request: merge_request,
          security_policy: policy,
          project: project,
          approval_policy_rule: approval_policy_rule)
      end

      it 'creates a policy dismissal with empty finding uuids' do
        expect { service.execute }.to change { Security::PolicyDismissal.count }.by(1)

        dismissal = Security::PolicyDismissal.last
        expect(dismissal.security_findings_uuids).to be_empty
      end
    end

    context 'when there are license scanning violations for the policy' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation,
          :license_scanning,
          merge_request: merge_request,
          security_policy: policy,
          project: project,
          approval_policy_rule: approval_policy_rule)
      end

      it 'returns a success response' do
        response = service.execute

        expect(response).to be_success
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { service.execute }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { service.execute }
      end

      it 'creates a policy dismissal with the correct attributes' do
        expect { service.execute }.to change { Security::PolicyDismissal.count }.by(1)

        dismissal = Security::PolicyDismissal.last

        expect(dismissal).to have_attributes(
          security_policy_id: policy.id,
          merge_request_id: merge_request.id,
          project_id: project.id,
          user_id: current_user.id,
          dismissal_types: [Security::PolicyDismissal::DISMISSAL_TYPES[:other]],
          comment: 'Test dismissal',
          licenses: { 'MIT' => %w[A B] },
          security_findings_uuids: []
        )
      end

      context 'with multiple license scanning violations for the policy' do
        let_it_be(:violation_2) do
          create(:scan_result_policy_violation,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT' => %w[A C], 'Ruby' => ['json'] } } },
            merge_request: merge_request,
            security_policy: policy,
            project: project,
            approval_policy_rule: approval_policy_rule)
        end

        it 'creates a policy dismissal with the correct attributes' do
          expect { service.execute }.to change { Security::PolicyDismissal.count }.by(1)

          dismissal = Security::PolicyDismissal.last

          expect(dismissal).to have_attributes(
            security_policy_id: policy.id,
            merge_request_id: merge_request.id,
            project_id: project.id,
            user_id: current_user.id,
            dismissal_types: [Security::PolicyDismissal::DISMISSAL_TYPES[:other]],
            comment: 'Test dismissal',
            licenses: { 'MIT' => %w[A B C], 'Ruby' => ['json'] },
            security_findings_uuids: []
          )
        end
      end
    end

    context 'with multiple policies' do
      let_it_be(:policy_2) { create(:security_policy, :enforcement_type_warn) }
      let_it_be(:approval_policy_rule_2) { create(:approval_policy_rule, security_policy: policy_2) }

      let_it_be(:violation_for_policy_1) do
        create(:scan_result_policy_violation,
          :new_scan_finding,
          merge_request: merge_request,
          security_policy: policy,
          project: project,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1])
      end

      let_it_be(:violation_for_policy_2) do
        create(:scan_result_policy_violation,
          :new_scan_finding,
          merge_request: merge_request,
          security_policy: policy_2,
          project: project,
          approval_policy_rule: approval_policy_rule_2,
          uuids: %w[uuid-2])
      end

      let(:params) { super().merge(security_policy_ids: [policy.id, policy_2.id]) }

      it 'creates dismissals for each policy' do
        expect { service.execute }.to change { Security::PolicyDismissal.count }.by(2)

        dismissal_1 = Security::PolicyDismissal.find_by(security_policy_id: policy.id)
        dismissal_2 = Security::PolicyDismissal.find_by(security_policy_id: policy_2.id)

        expect(dismissal_1.security_findings_uuids).to eq(%w[uuid-1])
        expect(dismissal_2.security_findings_uuids).to eq(%w[uuid-2])
      end
    end
  end
end
