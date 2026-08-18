# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetGroupValidityChecksWorker, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group_id) { group.id }
  let_it_be(:user_id) { user.id }

  let(:excluded_projects_ids) { [1, 2, 3] }
  let(:set_group_validity_checks_service) { instance_double(Security::Configuration::SetGroupValidityChecksService) }

  describe '#perform' do
    subject(:run_worker) do
      described_class.new.perform(group_id, true, user_id, excluded_projects_ids)
    end

    before do
      allow(set_group_validity_checks_service).to receive(:execute)
      allow(Security::Configuration::SetGroupValidityChecksService)
        .to receive(:new).and_return(set_group_validity_checks_service)
    end

    context 'when group exists' do
      it 'calls the `Security::Configuration::SetGroupValidityChecksService` for the group' do
        run_worker

        expect(Security::Configuration::SetGroupValidityChecksService).to have_received(:new).with(
          { enable: true, subject: group, current_user: user, excluded_projects_ids: excluded_projects_ids }
        )
        expect(set_group_validity_checks_service).to have_received(:execute)
      end
    end

    context 'when no such a group with group_id exists' do
      let_it_be(:group_id) { Time.now.to_i }

      it 'does not call SetGroupValidityChecksService' do
        run_worker
        expect(Security::Configuration::SetGroupValidityChecksService).not_to have_received(:new)
        expect(set_group_validity_checks_service).not_to have_received(:execute)
      end
    end

    context 'when no such a user with user_id exists' do
      let_it_be(:user_id) { Time.now.to_i }

      it 'does not call SetGroupValidityChecksService' do
        run_worker
        expect(Security::Configuration::SetGroupValidityChecksService).not_to have_received(:new)
        expect(set_group_validity_checks_service).not_to have_received(:execute)
      end
    end

    include_examples 'an idempotent worker' do
      let(:job_args) { [group.id, true, user_id, excluded_projects_ids] }
    end
  end
end
