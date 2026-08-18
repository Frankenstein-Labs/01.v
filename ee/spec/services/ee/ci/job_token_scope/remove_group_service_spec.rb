# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobTokenScope::RemoveGroupService, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:target_group) { create(:group, :private) }

  let_it_be(:current_user) { create(:user, maintainer_of: project, developer_of: target_group) }

  let_it_be(:policies) { %w[read_deployments read_packages] }

  let_it_be(:group_link) do
    create(:ci_job_token_group_scope_link,
      source_project: project,
      target_group: target_group,
      job_token_policies: policies
    )
  end

  subject(:service_result) { described_class.new(project, current_user).execute(target_group) }

  describe '#execute' do
    let(:expected_audit_message) do
      "Group #{target_group.full_path} was removed from list of allowed groups for #{project.full_path}, " \
        "with job token policies: read_deployments, read_packages"
    end

    let(:audit_event) do
      {
        name: 'secure_ci_job_token_group_removed',
        author: current_user,
        scope: project,
        target: target_group,
        message: expected_audit_message
      }
    end

    it 'returns a success response', :aggregate_failures do
      expect { service_result }.to change { Ci::JobToken::GroupScopeLink.count }.by(-1)
      expect(service_result).to be_success
    end

    it 'audits the event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_event)

      service_result
    end

    context 'when deleting the group link fails' do
      before do
        allow(::Ci::JobToken::GroupScopeLink).to receive(:for_source_and_target).and_return(group_link)
        allow(group_link).to receive(:destroy).and_return(false)
        allow(group_link).to receive(:errors).and_return(ActiveModel::Errors.new(group_link))
        group_link.errors.add(:base, 'Custom error message')
      end

      it 'returns an error response' do
        expect(service_result).to be_error
      end

      it 'does not audit the event' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)

        service_result
      end
    end
  end
end
