# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::ProcessProjectTransferEventsWorker, feature_category: :security_testing_configuration do
  include ExclusiveLeaseHelpers

  let_it_be(:old_namespace) { create(:group) }
  let_it_be(:new_namespace) { create(:group) }

  let_it_be_with_reload(:project) { create(:project, namespace: old_namespace) }

  let_it_be(:scan_profile_in_old_namespace) { create(:security_scan_profile, namespace: old_namespace) }
  let_it_be(:scan_profile_in_new_namespace) { create(:security_scan_profile, namespace: new_namespace) }
  let_it_be(:scan_profile_in_other_namespace) { create(:security_scan_profile, namespace: create(:group)) }

  let_it_be(:association_to_old_namespace) do
    create(:security_scan_profile_project, scan_profile: scan_profile_in_old_namespace, project: project)
  end

  let_it_be(:association_to_new_namespace) do
    create(:security_scan_profile_project, scan_profile: scan_profile_in_new_namespace, project: project)
  end

  let_it_be(:association_to_other_namespace) do
    create(:security_scan_profile_project, scan_profile: scan_profile_in_other_namespace, project: project)
  end

  let(:worker) { described_class.new }
  let(:project_id) { project.id }
  let(:project_event) do
    ::Projects::ProjectTransferedEvent.new(data: {
      project_id: project_id,
      old_namespace_id: old_namespace.id,
      old_root_namespace_id: old_namespace.id,
      new_namespace_id: new_namespace.id,
      new_root_namespace_id: new_namespace.id
    })
  end

  subject(:handle_event) { worker.handle_event(project_event) }

  describe '#handle_event' do
    it 'uses in_lock for processing' do
      project.update!(namespace: new_namespace)
      lease_key = Security::ScanProfiles.update_lease_key(old_namespace.id)
      expect_to_obtain_exclusive_lease(lease_key)

      handle_event
    end

    context 'when exclusive lease cannot be obtained' do
      before do
        project.update!(namespace: new_namespace)
        lease_key = Security::ScanProfiles.update_lease_key(old_namespace.id)
        stub_exclusive_lease_taken(lease_key)
      end

      it 'raises FailedToObtainLockError' do
        expect { handle_event }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
      end
    end

    context 'when there is no project associated with the event' do
      let(:project_id) { non_existing_record_id }

      it 'does not delete any associations' do
        expect { handle_event }.not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when there is a project associated with the event' do
      before do
        project.update!(namespace: new_namespace)
      end

      context 'when old and new root namespace are the same' do
        let(:project_event) do
          ::Projects::ProjectTransferedEvent.new(data: {
            project_id: project_id,
            old_namespace_id: old_namespace.id,
            old_root_namespace_id: old_namespace.id,
            new_namespace_id: new_namespace.id,
            new_root_namespace_id: old_namespace.id
          })
        end

        it 'does not delete any associations' do
          expect { handle_event }.not_to change { Security::ScanProfileProject.count }
        end
      end

      context 'when project is transferred to a different root namespace' do
        it 'deletes associations to scan profiles not in the new root namespace' do
          expect { handle_event }.to change { Security::ScanProfileProject.count }.by(-2)

          expect(Security::ScanProfileProject.exists?(association_to_old_namespace.id)).to be_falsey
          expect(Security::ScanProfileProject.exists?(association_to_other_namespace.id)).to be_falsey
          expect(Security::ScanProfileProject.exists?(association_to_new_namespace.id)).to be_truthy
        end

        it 'only deletes associations for the transferred project' do
          other_project = create(:project, namespace: new_namespace)
          other_association = create(:security_scan_profile_project,
            scan_profile: scan_profile_in_old_namespace,
            project: other_project)

          expect { handle_event }.not_to change { other_association.reload.id }
        end
      end

      context 'when project is transferred to a user namespace' do
        let_it_be(:new_namespace) { create(:user_namespace) }

        it 'deletes all scan profile associations' do
          expect { handle_event }.to change { Security::ScanProfileProject.count }.by(-3)

          expect(Security::ScanProfileProject.exists?(association_to_old_namespace.id)).to be_falsey
          expect(Security::ScanProfileProject.exists?(association_to_new_namespace.id)).to be_falsey
          expect(Security::ScanProfileProject.exists?(association_to_other_namespace.id)).to be_falsey
        end
      end
    end
  end
end
