# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobTokenScope::RemoveProjectService, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, ci_outbound_job_token_scope_enabled: true) }
  let_it_be(:target_project) { create(:project) }

  let_it_be(:current_user) { create(:user, maintainer_of: project, developer_of: target_project) }

  let_it_be(:policies) { %w[read_deployments read_packages] }

  let_it_be(:direction) { :inbound }

  subject(:service_result) do
    described_class.new(project, current_user).execute(target_project, direction)
  end

  describe '#execute' do
    context 'when the direction is inbound' do
      before_all do
        create(:ci_job_token_project_scope_link,
          source_project: project,
          target_project: target_project,
          job_token_policies: policies,
          direction: :inbound
        )
      end

      let(:expected_audit_message) do
        "Project #{target_project.full_path} was removed from inbound list of allowed projects " \
          "for #{project.full_path}, with job token policies: read_deployments, read_packages"
      end

      let(:audit_event) do
        {
          name: 'secure_ci_job_token_project_removed',
          author: current_user,
          scope: project,
          target: target_project,
          message: expected_audit_message
        }
      end

      it 'returns a success response', :aggregate_failures do
        expect { service_result }.to change { Ci::JobToken::ProjectScopeLink.count }.by(-1)
        expect(service_result).to be_success
      end

      it 'audits the event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_event)

        service_result
      end
    end

    context 'when the direction is outbound' do
      let_it_be(:direction) { :outbound }

      before_all do
        create(:ci_job_token_project_scope_link,
          source_project: project,
          target_project: target_project,
          job_token_policies: policies,
          direction: :outbound
        )
      end

      it 'returns a success response', :aggregate_failures do
        expect { service_result }.to change { Ci::JobToken::ProjectScopeLink.count }.by(-1)
        expect(service_result).to be_success
      end

      it 'does not audit the event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        service_result
      end
    end

    context 'when deleting the group link fails' do
      let_it_be(:project_link) do
        create(:ci_job_token_project_scope_link,
          source_project: project,
          target_project: target_project
        )
      end

      before do
        allow(::Ci::JobToken::ProjectScopeLink).to receive(:for_source_and_target).and_return(project_link)
        allow(project_link).to receive(:destroy).and_return(false)
        allow(project_link).to receive(:errors).and_return(ActiveModel::Errors.new(project_link))
        project_link.errors.add(:base, 'Custom error message')
      end

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
