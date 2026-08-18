# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobTokenScope::UpdatePoliciesService, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:target_project) { create(:project) }

  let_it_be(:current_user) { create(:user, maintainer_of: project, developer_of: target_project) }

  let(:default_permissions) { false }
  let(:policies) { %w[read_deployments read_packages] }

  subject(:service_result) do
    described_class.new(project, current_user).execute(target_project, default_permissions, policies)
  end

  describe '#execute' do
    context 'when the link to update exists' do
      before_all do
        create(:ci_job_token_project_scope_link,
          source_project: project,
          target_project: target_project,
          default_permissions: true,
          job_token_policies: %w[read_deployments read_packages],
          direction: :inbound
        )
      end

      let(:audit_event) do
        {
          name: 'secure_ci_job_token_policies_updated',
          author: current_user,
          scope: project,
          target: target_project,
          message: 'CI job token updated to default permissions: false, policies: read_deployments, read_packages'
        }
      end

      it 'returns a success response', :aggregate_failures do
        expect(service_result).to be_success

        link = service_result.payload

        expect(link.source_project).to eq(project)
        expect(link.target_project).to eq(target_project)
        expect(link.default_permissions).to be(default_permissions)
        expect(link.job_token_policies).to eq(policies)
      end

      it 'audits the event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_event)

        service_result
      end
    end

    context 'when the link to update does not exist' do
      it 'returns an error response' do
        expect(service_result).to be_error
      end

      it 'does not audit the event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        service_result
      end
    end
  end
end
