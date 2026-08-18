# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::ProjectDetachService, feature_category: :security_testing_configuration do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project1) { create(:project, namespace: root_group) }
  let_it_be(:project2) { create(:project, namespace: root_group) }
  let_it_be(:project3) { create(:project, namespace: root_group) }
  let_it_be(:profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection)
  end

  let_it_be(:other_profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :sast, name: 'Other Profile')
  end

  subject(:execute_service) { described_class.execute(profile: profile, current_user: user, projects: projects) }

  shared_examples 'does not schedule the analyzer status update worker' do
    it 'does not schedule the analyzer status update worker' do
      expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker).not_to receive(:perform_async)

      execute_service
    end
  end

  shared_examples 'returns no errors' do
    it 'returns no errors' do
      result = execute_service

      expect(result[:errors]).to be_empty
    end
  end

  describe '.execute' do
    context 'when projects is empty' do
      let(:projects) { [] }

      it 'returns an error' do
        result = execute_service

        expect(result[:errors]).to include('At least one project must be provided')
      end
    end

    context 'when too many projects are provided' do
      let(:projects) { [project1, project2] }

      before do
        stub_const("#{described_class}::MAX_PROJECTS", 1)
      end

      it 'returns an error' do
        result = execute_service

        expect(result[:errors]).to include(
          "Cannot detach profile from more than #{described_class::MAX_PROJECTS} items at once."
        )
      end
    end

    context 'when projects have the profile attached' do
      let(:projects) { [project1, project2] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
        create(:security_scan_profile_project, scan_profile: profile, project: project2)
      end

      it 'detaches the profile from all projects' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(-2)

        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).not_to exist
        expect(Security::ScanProfileProject.by_project_id(project2).for_scan_profile(profile)).not_to exist
      end

      it 'marks profile statuses as not_configured while preserving last_scan_at' do
        last_scan = 1.day.ago

        [project1, project2].each do |proj|
          create(:scan_profile_project_status,
            project: proj,
            scan_profile: profile,
            status: :success,
            consecutive_failure_count: 0,
            consecutive_success_count: 5,
            last_scan_at: last_scan
          )
        end

        execute_service

        statuses = Security::ScanProfileProjectStatus.where(
          project_id: [project1.id, project2.id],
          security_scan_profile_id: profile.id
        ).index_by(&:project_id)

        expect(statuses.keys).to match_array([project1.id, project2.id])

        statuses.each_value do |status|
          expect(status).to have_attributes(
            status: 'not_configured',
            consecutive_failure_count: 0,
            consecutive_success_count: 0
          )
          expect(status.last_scan_at).to be_within(1.second).of(last_scan)
        end
      end

      it_behaves_like 'returns no errors'

      it 'schedules the analyzer status update worker' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker).to receive(:perform_async)
          .with(contain_exactly(project1.id, project2.id), profile.scan_type)

        execute_service
      end
    end

    context 'when some projects do not have the profile attached' do
      let(:projects) { [project1, project2] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
      end

      it 'detaches only from projects that have the profile' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(-1)

        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).not_to exist
      end

      it 'schedules the analyzer status update worker only for detached projects' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker).to receive(:perform_async)
          .with([project1.id], profile.scan_type)

        execute_service
      end

      it_behaves_like 'returns no errors'
    end

    context 'when no projects have the profile attached' do
      let(:projects) { [project1, project2] }

      it 'does not change any record' do
        expect { execute_service }.not_to change { Security::ScanProfileProject.count }
      end

      it_behaves_like 'returns no errors'
      it_behaves_like 'does not schedule the analyzer status update worker'
    end

    context 'when projects have other profiles attached' do
      let(:projects) { [project1] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
        create(:security_scan_profile_project, scan_profile: other_profile, project: project1)
      end

      it 'only detaches the specified profile' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(-1)

        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).not_to exist
        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(other_profile)).to exist
      end

      it 'schedules the analyzer status update worker only for detached projects' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker).to receive(:perform_async)
          .with([project1.id], profile.scan_type)

        execute_service
      end

      it_behaves_like 'returns no errors'
    end

    context 'when an error occurs' do
      let(:projects) { [project1] }

      before do
        allow(Security::ScanProfileProject).to receive(:by_project_id).and_raise(StandardError, 'Database error')
      end

      it 'raises the error in development/test environment' do
        expect { execute_service }.to raise_error(StandardError, 'Database error')
      end

      context 'when not in development environment' do
        before do
          allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception) do |e|
            Gitlab::ErrorTracking.track_exception(e)
          end
        end

        it 'returns an error result without raising' do
          result = execute_service

          expect(result[:errors]).to include('An error has occurred during profile detachment')
        end

        it 'tracks the exception' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(an_instance_of(StandardError))

          execute_service
        end
      end
    end

    context 'with audit events', :request_store do
      let(:projects) { [project1, project2] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
        create(:security_scan_profile_project, scan_profile: profile, project: project2)
      end

      it 'creates audit events for detached projects' do
        expect { execute_service }.to change { AuditEventReader.count }.by(2)
      end

      it 'creates audit events with correct attributes' do
        execute_service

        audit_event = AuditEventReader.last
        expect(audit_event.details).to include(
          event_name: 'security_scan_profile_detached_from_project',
          author_name: user.name,
          profile_id: profile.id,
          profile_name: profile.name,
          scan_type: profile.scan_type
        )
        expect(audit_event.details[:project_id]).to be_in([project1.id, project2.id])
        expect(audit_event.details[:project_path]).to be_in([project1.full_path, project2.full_path])
        expect(audit_event.details[:custom_message]).to start_with("Detached security scan profile '#{profile.name}'")
      end

      context 'when no projects have the profile attached' do
        before do
          Security::ScanProfileProject.where(scan_profile: profile).delete_all
        end

        it 'does not create audit events' do
          expect { execute_service }.not_to change { AuditEventReader.count }
        end
      end

      context 'when detached project IDs do not match provided projects' do
        before do
          Security::ScanProfileProject.where(scan_profile: profile).delete_all
          # Simulate a scenario where the delete returns IDs that don't match the provided projects
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:delete_and_return_project_ids).and_return([999_999])
          end
        end

        it 'does not create audit events' do
          expect { execute_service }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
