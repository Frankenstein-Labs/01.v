# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::AttachService, feature_category: :security_testing_configuration do
  include ExclusiveLeaseHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }
  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:project1) { create(:project, namespace: root_group) }
  let_it_be_with_reload(:project2) { create(:project, namespace: subgroup) }
  let_it_be_with_reload(:project3) { create(:project, namespace: nested_subgroup) }

  let!(:scan_profile) do # Recreate to avoid association state leak between tests
    create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection)
  end

  let(:group) { root_group }
  let(:traverse_hierarchy) { true }
  let(:service) { described_class.new(group, scan_profile, current_user: user, traverse_hierarchy: traverse_hierarchy) }

  describe '.execute' do
    let(:mock_instance) { instance_double(described_class, execute: true) }

    before do
      allow(described_class).to receive(:new).and_return(mock_instance)
    end

    it 'instantiates a new instance and delegates the call to it' do
      described_class.execute(root_group, scan_profile, current_user: user, traverse_hierarchy: false)

      expect(described_class).to have_received(:new).with(root_group, scan_profile, current_user: user,
        traverse_hierarchy: false)
      expect(mock_instance).to have_received(:execute)
    end
  end

  describe '#execute' do
    it 'attaches the scan profile to all projects in the group hierarchy' do
      expect { service.execute }.to change { project1.security_scan_profiles.first }.from(nil).to(scan_profile)
       .and change { project2.security_scan_profiles.first }.from(nil).to(scan_profile)
       .and change { project3.security_scan_profiles.first }.from(nil).to(scan_profile)
    end

    it 'returns a success response' do
      result = service.execute

      expect(result[:status]).to eq(:success)
    end

    context 'when called for a subgroup' do
      let(:group) { subgroup }

      it 'attaches the scan profile to projects in the subgroup and its descendants' do
        expect { service.execute }.to change { project2.security_scan_profiles.first }.from(nil).to(scan_profile)
          .and change { project3.security_scan_profiles.first }.from(nil).to(scan_profile)
          .and not_change { project1.security_scan_profiles.first }.from(nil)
      end
    end

    context 'when the profile is already attached to some projects' do
      before do
        create(:security_scan_profile_project, project: project1, scan_profile: scan_profile)
      end

      it 'is idempotent and does not create duplicate records' do
        expect { service.execute }.to change { Security::ScanProfileProject.count }.by(2)

        # Running again should not create duplicates
        expect { service.execute }.not_to change { Security::ScanProfileProject.count }
        expect(project1.security_scan_profiles.count).to eq(1)
      end
    end

    context 'when scan profile belongs to a different root namespace' do
      let_it_be(:other_root_group) { create(:group) }
      let_it_be(:other_scan_profile) do
        create(:security_scan_profile, namespace: other_root_group, scan_type: :secret_detection)
      end

      let(:scan_profile) { other_scan_profile }

      it 'returns an error response' do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('Scan profile does not belong to group hierarchy')
      end

      it 'does not create any records' do
        expect { service.execute }.not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when the group has no projects' do
      let_it_be(:empty_group) { create(:group, parent: root_group) }
      let(:group) { empty_group }

      it 'returns a success response' do
        result = service.execute

        expect(result[:status]).to eq(:success)
      end

      it 'does not create any records' do
        expect { service.execute }.not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'with audit events', :request_store do
      it 'creates audit events for attached projects' do
        expect { service.execute }.to change { AuditEventReader.count }.by(3)
      end

      it 'creates audit events with correct attributes' do
        service.execute

        audit_event = AuditEventReader.last
        expect(audit_event.details).to include(
          event_name: 'security_scan_profile_attached_to_project',
          author_name: user.name,
          profile_id: scan_profile.id,
          profile_name: scan_profile.name,
          scan_type: scan_profile.scan_type
        )
        expect(audit_event.details[:project_id]).to be_in([project1.id, project2.id, project3.id])
        expect(audit_event.details[:project_path]).to be_in(
          [project1.full_path, project2.full_path, project3.full_path]
        )
        expect(audit_event.details[:custom_message]).to start_with(
          "Attached security scan profile '#{scan_profile.name}'"
        )
      end

      context 'when no projects are attached' do
        before do
          # Attach all projects first so nothing new gets attached
          create(:security_scan_profile_project, project: project1, scan_profile: scan_profile)
          create(:security_scan_profile_project, project: project2, scan_profile: scan_profile)
          create(:security_scan_profile_project, project: project3, scan_profile: scan_profile)
        end

        it 'does not create audit events' do
          expect { service.execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'when an error occurs during attachment' do
      let(:error) { StandardError.new }

      before do
        allow_next_instance_of(Gitlab::Database::NamespaceEachBatch) do |instance|
          allow(instance).to receive(:each_batch).and_raise(error)
        end
      end

      it 'propagates the error to the caller' do
        expect { service.execute }.to raise_error(error)
      end
    end

    context 'when ProjectAttachService returns errors' do
      before do
        allow(Security::ScanProfiles::ProjectAttachService).to receive(:execute)
          .and_return({ errors: ['Project has reached limit'] })
      end

      it 'returns an error response with collected errors' do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('Project has reached limit')
      end

      it 'does not create audit events for failed attachments' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when projects have reached the profile limit' do
      let_it_be(:another_profile) { create(:security_scan_profile, namespace: root_group, scan_type: :sast) }

      before do
        stub_const('Security::ScanProfileProject::MAX_PROFILES_PER_PROJECT', 1)
        create(:security_scan_profile_project, project: project1, scan_profile: another_profile)
        create(:security_scan_profile_project, project: project2, scan_profile: another_profile)
        create(:security_scan_profile_project, project: project3, scan_profile: another_profile)
      end

      it 'does not attach the scan profile to projects at the limit' do
        expect { service.execute }.not_to change { Security::ScanProfileProject.count }

        expect(project1.security_scan_profiles).to contain_exactly(another_profile)
        expect(project2.security_scan_profiles).to contain_exactly(another_profile)
        expect(project3.security_scan_profiles).to contain_exactly(another_profile)
      end

      it 'returns an error response when all projects are at the limit' do
        # The service returns error because all projects failed to attach
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to be_an(Array)
        expect(result[:message].size).to eq(3) # All 3 projects at limit
      end

      context 'when some projects are at the limit and others are not' do
        let_it_be(:project4) { create(:project, namespace: subgroup) }

        it 'only attaches to projects under the limit' do
          expect { service.execute }.to change { Security::ScanProfileProject.count }.by(1)

          expect(project4.security_scan_profiles.first).to eq(scan_profile)
          expect(project1.security_scan_profiles).to contain_exactly(another_profile)
        end
      end
    end

    context 'when traverse_hierarchy is false' do
      let(:traverse_hierarchy) { false }

      it 'only processes the specific group, not descendants' do
        expect { service.execute }.to change { project1.security_scan_profiles.first }.from(nil).to(scan_profile)
         .and not_change { project2.security_scan_profiles.first }.from(nil)
         .and not_change { project3.security_scan_profiles.first }.from(nil)
      end

      context 'when called for a subgroup' do
        let(:group) { subgroup }

        it 'only processes the subgroup, not its descendants' do
          expect { service.execute }.to change { project2.security_scan_profiles.first }.from(nil).to(scan_profile)
            .and not_change { project1.security_scan_profiles.first }.from(nil)
            .and not_change { project3.security_scan_profiles.first }.from(nil)
        end
      end
    end

    describe 'running the logic in lock' do
      context 'when the logic is running for the entire hierarchy' do
        it 'tries to obtain the lock just once for each namespace' do
          expect_next_instances_of(Gitlab::ExclusiveLeaseHelpers::SleepingLock, 3) do |instance|
            expect(instance).to receive(:obtain).with(described_class::LEASE_RETRY_WITH_TRAVERSAL + 1)
          end

          service.execute
        end

        context 'when exclusive lease cannot be obtained' do
          before do
            stub_exclusive_lease_taken("#{Security::ScanProfiles.update_lease_key(root_group.id)}:profile:#{scan_profile.id}")
          end

          it 'schedules a retry worker for the namespace' do
            expect(Security::ScanProfiles::AttachWorker).to receive(:perform_in)
              .with(described_class::RETRY_DELAY, root_group.id, scan_profile.id, user.id, nil, false)

            service.execute
          end

          it 'processes other groups successfully' do
            expect { service.execute }.to change { Security::ScanProfileProject.count }.by(2)

            # Root group project should not be processed
            expect(project1.security_scan_profiles.first).to be_nil

            # Subgroup and nested group projects should be processed
            expect(project2.security_scan_profiles.first).to eq(scan_profile)
            expect(project3.security_scan_profiles.first).to eq(scan_profile)
          end
        end

        context 'when exclusive lease is taken for a different profile on the same namespace' do
          let!(:other_profile) { create(:security_scan_profile, namespace: root_group, scan_type: :sast) }

          before do
            stub_exclusive_lease_taken("#{Security::ScanProfiles.update_lease_key(root_group.id)}:profile:#{other_profile.id}")
          end

          it 'does not block the current profile from being attached' do
            expect { service.execute }.to change { Security::ScanProfileProject.count }.by(3)

            expect(project1.security_scan_profiles.first).to eq(scan_profile)
            expect(project2.security_scan_profiles.first).to eq(scan_profile)
            expect(project3.security_scan_profiles.first).to eq(scan_profile)
          end
        end
      end

      context 'when the logic is running for a specific group' do
        let(:traverse_hierarchy) { false }

        it 'tries to obtain the lock with the correct number of retries' do
          expect_next_instance_of(Gitlab::ExclusiveLeaseHelpers::SleepingLock) do |instance|
            expect(instance).to receive(:obtain).with(described_class::LEASE_RETRY_WITHOUT_TRAVERSAL + 1)
          end

          service.execute
        end

        context 'when exclusive lease cannot be obtained' do
          before do
            stub_const("#{described_class}::LEASE_RETRY_WITHOUT_TRAVERSAL", 0)

            stub_exclusive_lease_taken("#{Security::ScanProfiles.update_lease_key(root_group.id)}:profile:#{scan_profile.id}")
          end

          it 'propagates the error to the caller' do
            expect { service.execute }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
          end
        end
      end
    end
  end
end
