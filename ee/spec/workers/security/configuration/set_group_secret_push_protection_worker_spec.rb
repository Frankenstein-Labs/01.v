# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetGroupSecretPushProtectionWorker, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group_id) { group.id }
  let_it_be(:user_id) { user.id }

  let(:excluded_projects_ids) { [1, 2, 3] }
  let(:set_group_spp_service) { instance_double(Security::Configuration::SetGroupSecretPushProtectionService) }

  describe '#perform' do
    subject(:run_worker) do
      described_class.new.perform(group_id, true, user_id, excluded_projects_ids)
    end

    before do
      allow(set_group_spp_service).to receive(:execute)
      allow(Security::Configuration::SetGroupSecretPushProtectionService)
        .to receive(:new).and_return(set_group_spp_service)
    end

    context 'when group exists' do
      it 'calls the `Security::Configuration::SetGroupSecretPushProtectionService` for the group' do
        run_worker

        expect(Security::Configuration::SetGroupSecretPushProtectionService).to have_received(:new).with(
          { enable: true, subject: group, current_user: user, excluded_projects_ids: excluded_projects_ids }
        )
        expect(set_group_spp_service).to have_received(:execute)
      end
    end

    context 'when no such a group with group_id exists' do
      let_it_be(:group_id) { Time.now.to_i }

      it 'does not call SetGroupSecretPushProtectionService' do
        run_worker
        expect(Security::Configuration::SetGroupSecretPushProtectionService).not_to have_received(:new)
        expect(set_group_spp_service).not_to have_received(:execute)
      end
    end

    context 'when no such a user with user_id exists' do
      let_it_be(:user_id) { Time.now.to_i }

      it 'does not call SetGroupSecretPushProtectionService' do
        run_worker
        expect(Security::Configuration::SetGroupSecretPushProtectionService).not_to have_received(:new)
        expect(set_group_spp_service).not_to have_received(:execute)
      end
    end

    include_examples 'an idempotent worker' do
      let(:job_args) { [group.id, true, user_id, excluded_projects_ids] }
    end
  end
end
