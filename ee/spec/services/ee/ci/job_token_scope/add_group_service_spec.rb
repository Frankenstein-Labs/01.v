# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobTokenScope::AddGroupService, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:target_group) { create(:group, :private) }

  let_it_be(:current_user) { create(:user, maintainer_of: project, developer_of: target_group) }

  let_it_be(:policies) { %w[read_deployments read_packages] }

  subject(:service_result) do
    described_class.new(project, current_user).execute(target_group, default_permissions: false, policies: policies)
  end

  describe '#execute' do
    let(:expected_audit_message) do
      "Group #{target_group.full_path} was added to list of allowed groups for #{project.full_path}, " \
        "with default permissions: false, job token policies: read_deployments, read_packages"
    end

    let(:audit_event) do
      {
        name: 'secure_ci_job_token_group_added',
        author: current_user,
        scope: project,
        target: target_group,
        message: expected_audit_message
      }
    end

    it 'returns a success response', :aggregate_failures do
      expect { service_result }.to change { Ci::JobToken::GroupScopeLink.count }.by(1)
      expect(service_result).to be_success
    end

    it 'audits the event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_event)

      service_result
    end

    context 'when adding a group fails' do
      before do
        allow_next_instance_of(Ci::JobToken::Allowlist) do |link|
          allow(link)
            .to receive(:add_group!)
            .and_raise(ActiveRecord::RecordInvalid)
        end
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
