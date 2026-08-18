# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::DetachService, feature_category: :security_testing_configuration do
  include ExclusiveLeaseHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }
  let_it_be(:user) { create(:user) }

  let_it_be(:project1) { create(:project, namespace: root_group) }
  let_it_be(:project2) { create(:project, namespace: subgroup) }
  let_it_be(:project3) { create(:project, namespace: nested_subgroup) }

  let_it_be(:scan_profile) do
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

      expect(described_class).to have_received(:new)
        .with(root_group, scan_profile, current_user: user, traverse_hierarchy: false)
      expect(mock_instance).to have_received(:execute)
    end
  end

  describe '#execute' do
    let!(:association1) { create(:security_scan_profile_project, project: project1, scan_profile: scan_profile) }
    let!(:association2) { create(:security_scan_profile_project, project: project2, scan_profile: scan_profile) }
    let!(:association3) { create(:security_scan_profile_project, project: project3, scan_profile: scan_profile) }

    it 'detaches the scan profile from all projects in the group hierarchy' do
      expect { service.execute }
        .to change { Security::ScanProfileProject.count }.by(-3)

      expect(Security::ScanProfileProject.exists?(association1.id)).to be_falsey
      expect(Security::ScanProfileProject.exists?(association2.id)).to be_falsey
      expect(Security::ScanProfileProject.exists?(association3.id)).to be_falsey
    end

    it 'returns a success response' do
      result = service.execute

      expect(result[:status]).to eq(:success)
    end

    context 'when called for a subgroup' do
      let(:group) { subgroup }

      it 'detaches the scan profile from projects in the subgroup and its descendants' do
        expect { service.execute }
          .to change { Security::ScanProfileProject.count }.by(-2)

        expect(Security::ScanProfileProject.exists?(association1.id)).to be_truthy
        expect(Security::ScanProfileProject.exists?(association2.id)).to be_falsey
        expect(Security::ScanProfileProject.exists?(association3.id)).to be_falsey
      end
    end

    context 'when the profile is not attached to some projects' do
      before do
        Security::ScanProfileProject.where(project: project1, security_scan_profile_id: scan_profile.id).delete_all
      end

      it 'is idempotent and only removes existing records' do
        expect { service.execute }
          .to change { Security::ScanProfileProject.count }.by(-2)

        # Running again should not raise errors
        expect { service.execute }
          .not_to change { Security::ScanProfileProject.count }

        expect(Security::ScanProfileProject.where(project: project1, security_scan_profile_id: scan_profile.id).count)
          .to eq(0)
      end

      it 'handles projects with no associations gracefully' do
        Security::ScanProfileProject.where(security_scan_profile_id: scan_profile.id).delete_all

        expect { service.execute }.not_to raise_error
        expect(service.execute[:status]).to eq(:success)
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

        expect(result).to eq(
          status: :error,
          message: 'Scan profile does not belong to group hierarchy'
        )
      end

      it 'does not delete any records' do
        expect { service.execute }
          .not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when the group has no projects' do
      let_it_be(:empty_group) { create(:group, parent: root_group) }
      let(:group) { empty_group }

      it 'returns a success response' do
        result = service.execute

        expect(result[:status]).to eq(:success)
      end

      it 'does not delete any records' do
        expect { service.execute }
          .not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'with audit events', :request_store do
      it 'creates audit events for detached projects' do
        expect { service.execute }.to change { AuditEventReader.count }.by(3)
      end

      it 'creates audit events with correct attributes' do
        service.execute

        audit_event = AuditEventReader.last
        expect(audit_event.details).to include(
          event_name: 'security_scan_profile_detached_from_project',
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
          "Detached security scan profile '#{scan_profile.name}'"
        )
      end

      context 'when no projects are detached' do
        before do
          # Remove all associations so nothing gets detached
          Security::ScanProfileProject.where(scan_profile: scan_profile).delete_all
        end

        it 'does not create audit events' do
          expect { service.execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'when an error occurs during detachment' do
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

    context 'when ProjectDetachService returns errors' do
      before do
        allow(Security::ScanProfiles::ProjectDetachService).to receive(:execute)
          .and_return({ errors: ['Project has reached limit'] })
      end

      it 'returns an error response with collected errors' do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('Project has reached limit')
      end

      it 'does not create audit events for failed detachments' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when traverse_hierarchy is false' do
      let(:traverse_hierarchy) { false }

      it 'only processes the specific group, not descendants' do
        expect { service.execute }
          .to change { Security::ScanProfileProject.count }.by(-1) # only project1

        expect(Security::ScanProfileProject.exists?(association1.id)).to be_falsey
        expect(Security::ScanProfileProject.exists?(association2.id)).to be_truthy
        expect(Security::ScanProfileProject.exists?(association3.id)).to be_truthy
      end

      context 'when called for a subgroup' do
        let(:group) { subgroup }

        it 'only processes the subgroup, not its descendants' do
          expect { service.execute }
            .to change { Security::ScanProfileProject.count }.by(-1) # only project2

          expect(Security::ScanProfileProject.exists?(association1.id)).to be_truthy
          expect(Security::ScanProfileProject.exists?(association2.id)).to be_falsey
          expect(Security::ScanProfileProject.exists?(association3.id)).to be_truthy
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
            expect(Security::ScanProfiles::DetachWorker).to receive(:perform_in)
              .with(described_class::RETRY_DELAY, root_group.id, scan_profile.id, user.id, nil, false)

            service.execute
          end

          it 'processes other groups successfully' do
            expect { service.execute }
              .to change { Security::ScanProfileProject.count }.by(-2)

            # Root group project should not be processed
            #
            expect(Security::ScanProfileProject.exists?(association1.id)).to be_truthy

            # Subgroup and nested group projects should be processed
            #
            expect(Security::ScanProfileProject.exists?(association2.id)).to be_falsey
            expect(Security::ScanProfileProject.exists?(association3.id)).to be_falsey
          end
        end

        context 'when exclusive lease is taken for a different profile on the same namespace' do
          let!(:other_profile) { create(:security_scan_profile, namespace: root_group, scan_type: :sast) }

          before do
            stub_exclusive_lease_taken("#{Security::ScanProfiles.update_lease_key(root_group.id)}:profile:#{other_profile.id}")
          end

          it 'does not block the current profile from being detached' do
            expect { service.execute }
              .to change { Security::ScanProfileProject.count }.by(-3)

            expect(Security::ScanProfileProject.exists?(association1.id)).to be_falsey
            expect(Security::ScanProfileProject.exists?(association2.id)).to be_falsey
            expect(Security::ScanProfileProject.exists?(association3.id)).to be_falsey
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
