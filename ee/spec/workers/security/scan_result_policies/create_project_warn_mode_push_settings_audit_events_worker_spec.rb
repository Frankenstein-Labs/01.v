# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CreateProjectWarnModePushSettingsAuditEventsWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy) { create(:security_policy) }

  let(:project_id) { project.id }
  let(:policy_id) { policy.id }

  subject(:perform) { described_class.new.perform(project_id, policy_id) }

  shared_examples 'calls service' do
    specify do
      expect_next_instance_of(
        Security::ScanResultPolicies::CreateProjectWarnModePushSettingsAuditEventService, project, policy) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      perform
    end
  end

  shared_examples 'does not call service' do
    specify do
      expect(Security::ScanResultPolicies::CreateProjectWarnModePushSettingsAuditEventService).not_to receive(:new)

      perform
    end
  end

  context 'with project and policy' do
    include_examples 'calls service'
  end

  context 'with non-existent project ID' do
    let(:project_id) { non_existing_record_id }

    include_examples 'does not call service'
  end

  context 'with non-existent policy ID' do
    let(:policy_id) { non_existing_record_id }

    include_examples 'does not call service'
  end
end
