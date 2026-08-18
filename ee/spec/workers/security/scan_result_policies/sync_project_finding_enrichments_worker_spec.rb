# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncProjectFindingEnrichmentsWorker,
  feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:security_policy) { create(:security_policy, :with_enrichment_filter_rule) }

  let(:worker) { described_class.new }

  describe 'worker settings' do
    it { expect(described_class).to be_idempotent }
    it { expect(described_class.get_urgency).to eq(:low) }
    it { expect(described_class.get_feature_category).to eq(:security_policy_management) }

    it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  end

  describe '#perform' do
    subject(:perform) { worker.perform(project.id, security_policy.id) }

    shared_examples_for 'does not call SyncFindingEnrichmentsService' do
      it 'does not call SyncFindingEnrichmentsService' do
        expect(Security::SyncFindingEnrichmentsService).not_to receive(:new)

        perform
      end
    end

    shared_examples_for 'calls SyncFindingEnrichmentsService with the project' do
      it 'calls SyncFindingEnrichmentsService with the project' do
        service = instance_double(Security::SyncFindingEnrichmentsService)
        expect(Security::SyncFindingEnrichmentsService).to receive(:new).with(project).and_return(service)
        expect(service).to receive(:execute)

        perform
      end
    end

    context 'when project does not exist' do
      subject(:perform) { worker.perform(non_existing_record_id, security_policy.id) }

      it_behaves_like 'does not call SyncFindingEnrichmentsService'
    end

    context 'when security policy does not exist' do
      subject(:perform) { worker.perform(project.id, non_existing_record_id) }

      it_behaves_like 'does not call SyncFindingEnrichmentsService'
    end

    context 'when security policy is not an approval policy' do
      let_it_be(:security_policy) do
        create(:security_policy, type: Security::Policy.types[:scan_execution_policy])
      end

      it_behaves_like 'does not call SyncFindingEnrichmentsService'
    end

    context 'when security policy has no KEV/EPSS filter rules' do
      let_it_be(:security_policy) { create(:security_policy) }

      it_behaves_like 'does not call SyncFindingEnrichmentsService'
    end

    context 'when security policy is an approval policy with KEV/EPSS filter rules' do
      it_behaves_like 'calls SyncFindingEnrichmentsService with the project'
    end

    context 'when security policy has a known_exploited filter rule' do
      let_it_be(:security_policy) { create(:security_policy, :with_known_exploited_filter_rule) }

      it_behaves_like 'calls SyncFindingEnrichmentsService with the project'
    end
  end
end
