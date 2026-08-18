# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::MergeRequests::DismissPolicyViolations, feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:policy) { create(:security_policy, :enforcement_type_warn) }
  let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

  let_it_be(:policy_without_warn_mode) { create(:security_policy) }
  let_it_be(:approval_policy_rule_without_warn_mode) do
    create(:approval_policy_rule, security_policy: policy_without_warn_mode)
  end

  let(:current_user) { developer }
  let(:security_policy_ids) do
    [
      policy.id,
      policy_without_warn_mode.id
    ]
  end

  let(:mutation_vars) do
    {
      project_path: project.full_path,
      iid: merge_request.iid.to_s,
      security_policy_ids: security_policy_ids,
      dismissal_types: [Security::PolicyDismissal::DISMISSAL_TYPES[:emergency_hot_fix]],
      comment: 'Test dismissal'
    }
  end

  let(:service_args) { { current_user: current_user, params: mutation_vars.except(:project_path, :iid) } }

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  before_all do
    project.add_developer(developer)
    project.add_guest(guest)
  end

  describe '#resolve' do
    subject(:resolve) { mutation.resolve(**mutation_vars) }

    context 'when the user is not authorized' do
      let(:current_user) { guest }

      it 'raises an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user is authorized' do
      context 'when the service returns a success' do
        let_it_be(:violation_1) do
          create(:scan_result_policy_violation,
            :new_scan_finding,
            merge_request: merge_request,
            security_policy: policy,
            project: project,
            approval_policy_rule: approval_policy_rule,
            uuids: %w[uuid-1])
        end

        it 'calls the service with the correct arguments' do
          expect_next_instance_of(::Security::ScanResultPolicies::DismissPolicyViolationsService,
            merge_request, **service_args) do |service|
            expect(service).to receive(:execute).and_call_original
          end

          resolve
        end

        it 'creates a dismissal and returns no errors' do
          expect { resolve }.to change { Security::PolicyDismissal.count }.by(1)

          expect(resolve[:errors]).to be_empty
          expect(resolve[:merge_request]).to eq(merge_request)
        end
      end

      context 'when the service returns an error' do
        let(:security_policy_ids) { [] }
        let(:error_message) { 'No warn mode policies are found.' }

        it 'does not create any records and returns the error message' do
          expect { resolve }.not_to change { Security::PolicyDismissal.count }

          expect(resolve[:errors]).to contain_exactly(error_message)
        end
      end
    end
  end
end
