# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::CleanOldNamespaceConnectionsService, feature_category: :security_testing_configuration do
  include ExclusiveLeaseHelpers

  describe '.execute' do
    let(:group_id) { 123 }
    let(:traverse_hierarchy) { true }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_class_method) do
      described_class.execute(group_id, traverse_hierarchy)
    end

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object with parameters and calls execute', :aggregate_failures do
      execute_class_method

      expect(described_class).to have_received(:new).with(group_id, traverse_hierarchy)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be(:root_namespace) { create(:group) }
    let_it_be(:other_root_namespace) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_namespace) }
    let_it_be(:subgroup) { create(:group, parent: group) }

    let_it_be(:project1) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: group) }
    let_it_be(:project3) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project, group: other_root_namespace) }

    let_it_be(:scan_profile_in_root) { create(:security_scan_profile, namespace: root_namespace) }
    let_it_be(:scan_profile_in_other_root) { create(:security_scan_profile, namespace: other_root_namespace) }

    let(:group_id) { group.id }
    let(:traverse_hierarchy) { true }

    subject(:execute) do
      described_class.execute(group_id, traverse_hierarchy)
    end

    context 'when group exists' do
      let_it_be(:connection1) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project1)
      end

      let_it_be(:connection2) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project2)
      end

      let_it_be(:connection3) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project3)
      end

      let_it_be(:connection_in_same_root) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_root, project: project1)
      end

      let_it_be(:other_connection) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: other_project)
      end

      it 'deletes project connections to profiles not in the same root namespace' do
        expect { execute }.to change { Security::ScanProfileProject.count }.by(-3)

        expect(Security::ScanProfileProject.exists?(connection1.id)).to be(false)
        expect(Security::ScanProfileProject.exists?(connection2.id)).to be(false)
        expect(Security::ScanProfileProject.exists?(connection3.id)).to be(false)
      end

      it 'keeps connections for profiles within same root namespace' do
        execute

        expect(Security::ScanProfileProject.exists?(connection_in_same_root.id)).to be(true)
      end

      it 'keeps connections for projects outside the group' do
        execute

        expect(Security::ScanProfileProject.exists?(other_connection.id)).to be(true)
      end
    end

    context 'when group projects has no connections to profiles outside root namespace' do
      let_it_be(:connection_in_same_root) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_root, project: project1)
      end

      it 'does not delete any connections' do
        expect { execute }.not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when group does not exist' do
      where(:group_id) { [nil, non_existing_record_id] }

      with_them do
        it 'does not delete any connections' do
          create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project1)

          expect { execute }.not_to change { Security::ScanProfileProject.count }
        end
      end
    end

    context 'when processing projects in batches' do
      let_it_be(:batch_test_group) { create(:group, parent: root_namespace) }
      let_it_be(:batch_project1) { create(:project, group: batch_test_group) }
      let_it_be(:batch_project2) { create(:project, group: batch_test_group) }

      let(:group_id) { batch_test_group.id }

      let_it_be(:batch_connection1) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: batch_project1)
      end

      let_it_be(:batch_connection2) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: batch_project2)
      end

      before do
        stub_const("#{described_class}::PROJECT_BATCH_SIZE", 1)
      end

      it 'deletes project connections to profiles not in the same root namespace' do
        expect { execute }.to change { Security::ScanProfileProject.count }.by(-2)
      end

      it 'processes projects in batches' do
        relation = Security::ScanProfileProject.all
        allow(Security::ScanProfileProject).to receive_message_chain(:by_project_id,
          :not_in_root_namespace).and_return(relation)
        allow(relation).to receive(:delete_all)

        execute

        expect(relation).to have_received(:delete_all).twice
      end
    end

    context 'when traverse_hierarchy is false' do
      let(:traverse_hierarchy) { false }

      let_it_be(:connection1) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project1)
      end

      let_it_be(:connection2) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project2)
      end

      let_it_be(:connection3) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project3)
      end

      it 'only processes the specific group, not descendants' do
        expect { execute }
          .to change { project1.security_scan_profiles.first }.from(scan_profile_in_other_root).to(nil)
          .and change { project2.security_scan_profiles.first }.from(scan_profile_in_other_root).to(nil)
          .and not_change { project3.security_scan_profiles.first }.from(scan_profile_in_other_root)
      end

      context 'when called for a subgroup' do
        let(:group_id) { subgroup.id }

        it 'only processes the subgroup, not its descendants' do
          expect { execute }
            .to change { project3.security_scan_profiles.first }.from(scan_profile_in_other_root).to(nil)
            .and not_change { project1.security_scan_profiles.first }.from(scan_profile_in_other_root)
            .and not_change { project2.security_scan_profiles.first }.from(scan_profile_in_other_root)
        end
      end
    end

    describe 'running the logic in lock' do
      let_it_be(:connection1) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project1)
      end

      let_it_be(:connection2) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project2)
      end

      let_it_be(:connection3) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project3)
      end

      context 'when the logic is running for the entire hierarchy' do
        it 'tries to obtain the lock without retries' do
          expect_next_instances_of(Gitlab::ExclusiveLeaseHelpers::SleepingLock, 2) do |instance|
            expect(instance).to receive(:obtain).with(1) # single try
          end

          execute
        end

        context 'when exclusive lease cannot be obtained' do
          context 'when group lock cannot be obtained' do
            before do
              stub_exclusive_lease_taken(Security::ScanProfiles.update_lease_key(group.id))
            end

            it 'schedules a retry worker for the namespace' do
              expect(Security::ScanProfiles::CleanOldNamespaceConnectionsWorker).to receive(:perform_in)
                .with(described_class::RETRY_DELAY, group.id, false)

              execute
            end

            it 'processes other namespaces successfully' do
              expect { execute }
                .to change { project3.security_scan_profiles.first }.from(scan_profile_in_other_root).to(nil)
                .and not_change { project1.security_scan_profiles.first }.from(scan_profile_in_other_root)
                .and not_change { project2.security_scan_profiles.first }.from(scan_profile_in_other_root)
            end
          end

          context 'when subgroup lock cannot be obtained' do
            before do
              stub_exclusive_lease_taken(Security::ScanProfiles.update_lease_key(subgroup.id))
            end

            it 'schedules a retry worker for the subgroup' do
              expect(Security::ScanProfiles::CleanOldNamespaceConnectionsWorker).to receive(:perform_in)
                .with(described_class::RETRY_DELAY, subgroup.id, false)

              execute
            end

            it 'processes other namespaces successfully' do
              expect { execute }
                .to change { project1.security_scan_profiles.first }.from(scan_profile_in_other_root).to(nil)
                .and change { project2.security_scan_profiles.first }.from(scan_profile_in_other_root).to(nil)
                .and not_change { project3.security_scan_profiles.first }.from(scan_profile_in_other_root)
            end
          end
        end
      end

      context 'when the logic is running for a specific group' do
        let(:traverse_hierarchy) { false }

        it 'tries to obtain the lock with the correct number of retries' do
          expect_next_instance_of(Gitlab::ExclusiveLeaseHelpers::SleepingLock) do |instance|
            expect(instance).to receive(:obtain).with(described_class::LEASE_RETRY_WITHOUT_TRAVERSAL + 1)
          end

          execute
        end

        context 'when exclusive lease cannot be obtained' do
          before do
            stub_const("#{described_class}::LEASE_RETRY_WITHOUT_TRAVERSAL", 0)
            stub_exclusive_lease_taken(Security::ScanProfiles.update_lease_key(group.id))
          end

          it 'propagates the error to the caller' do
            expect { execute }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
          end
        end
      end
    end
  end
end
