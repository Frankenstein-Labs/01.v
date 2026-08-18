# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::UnassignPolicyConfigurationsForExpiredNamespaceWorker, feature_category: :security_policy_management do
  subject(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:subproject) { create(:project, group: subgroup) }
    let_it_be(:project_without_config) { create(:project, group: group) }

    let_it_be(:admin_bot) { create(:user, :admin_bot, organization: organization) }

    let_it_be(:group_policy_config) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: group)
    end

    let_it_be(:subgroup_policy_config) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: subgroup)
    end

    let_it_be(:project_policy_config) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let_it_be(:subproject_policy_config) do
      create(:security_orchestration_policy_configuration, project: subproject)
    end

    let_it_be(:other_policy_config) do
      create(:security_orchestration_policy_configuration, :namespace)
    end

    let(:unassign_service) { instance_double(Security::Orchestration::UnassignService) }

    before do
      allow(Security::Orchestration::UnassignService).to receive(:new).and_return(unassign_service)
      allow(unassign_service).to receive(:execute)
    end

    context 'when namespace does not exist' do
      it 'does not call UnassignService' do
        worker.perform(non_existing_record_id)

        expect(Security::Orchestration::UnassignService).not_to have_received(:new)
      end
    end

    context 'when namespace exists' do
      it 'calls UnassignService for each policy configuration in the namespace hierarchy' do
        [group, subgroup, project, subproject].each do |container|
          expect(Security::Orchestration::UnassignService).to receive(:new).with(
            container: container, current_user: admin_bot
          ).and_return(unassign_service)
        end

        expect(unassign_service).to receive(:execute).with(delete_bot: true, skip_csp: false).exactly(4).times

        worker.perform(group.id)
      end

      it 'does not call UnassignService for configurations outside the namespace hierarchy' do
        [other_policy_config.namespace, project_without_config].each do |container|
          expect(Security::Orchestration::UnassignService).not_to receive(:new).with(
            container: container, current_user: anything
          )
        end

        worker.perform(group.id)
      end

      it 'logs the start and end of namespace unassignment' do
        expect(::Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            class: described_class.name,
            message: "Starting policy configurations unassignment for expired namespace subscription",
            namespace_id: group.id
          )
        ).once

        expect(::Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            class: described_class.name,
            message: "Completed policy configurations unassignment for expired namespace subscription",
            namespace_id: group.id,
            configurations_count: 4
          )
        ).once

        worker.perform(group.id)
      end
    end
  end
end
