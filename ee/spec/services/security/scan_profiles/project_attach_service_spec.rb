# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::ProjectAttachService, feature_category: :security_testing_configuration do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project1) { create(:project, namespace: root_group) }
  let_it_be(:project2) { create(:project, namespace: root_group) }
  let_it_be(:project_at_limit) { create(:project, namespace: root_group) }
  let_it_be(:profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection, name: 'Test Profile')
  end

  let_it_be(:other_profile) { create(:security_scan_profile, namespace: root_group, scan_type: :sast) }
  let_it_be(:at_limit_association) do
    create(:security_scan_profile_project, project: project_at_limit, scan_profile: other_profile)
  end

  before do
    stub_const('Security::ScanProfileProject::MAX_PROFILES_PER_PROJECT', 1)
  end

  shared_examples 'returns empty errors' do
    it 'returns empty errors' do
      result = execute_service

      expect(result[:errors]).to be_empty
    end
  end

  shared_examples 'does not schedule the analyzer status update worker' do
    it 'does not schedule the analyzer status update worker' do
      expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker).not_to receive(:perform_async)

      execute_service
    end
  end

  describe '.execute' do
    subject(:execute_service) do
      described_class.execute(profile: profile, current_user: current_user, projects: projects)
    end

    let(:current_user) { user }

    context 'when no projects are provided' do
      let(:projects) { [] }

      it 'returns an error' do
        result = execute_service

        expect(result[:errors]).to include('At least one project must be provided')
      end

      it 'does not create any associations' do
        expect { execute_service }.not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when projects are provided' do
      let(:projects) { [project1, project2] }

      it 'creates associations for all projects' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(projects.count)
      end

      it 'creates correct associations' do
        execute_service

        expect(Security::ScanProfileProject.where(project: project1, scan_profile: profile)).to exist
        expect(Security::ScanProfileProject.where(project: project2, scan_profile: profile)).to exist
      end

      it 'initializes profile status records for attached projects' do
        execute_service

        statuses = Security::ScanProfileProjectStatus.where(
          project_id: [project1.id, project2.id],
          security_scan_profile_id: profile.id
        ).index_by(&:project_id)

        expect(statuses.keys).to match_array([project1.id, project2.id])

        statuses.each_value do |status|
          expect(status).to have_attributes(
            status: 'success',
            consecutive_failure_count: 0,
            consecutive_success_count: 0
          )
        end
      end

      it 'schedules the analyzer status update worker' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker).to receive(:perform_async)
          .with(contain_exactly(project1.id, project2.id), profile.scan_type)

        execute_service
      end

      it_behaves_like 'returns empty errors'
    end

    context 'when a project has reached the profile limit' do
      let(:projects) { [project1, project_at_limit] }

      it 'only attaches to the project under the limit' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(1)
        expect(Security::ScanProfileProject.where(project: project1, scan_profile: profile)).to exist
        expect(Security::ScanProfileProject.where(project: project_at_limit, scan_profile: profile)).not_to exist
      end

      it 'returns an error for the project at limit' do
        result = execute_service
        expect(result[:errors]).to include(
          match(/Project '#{project_at_limit.name}'.*#{project_at_limit.full_path}.*maximum limit/)
        )
      end

      it 'schedules the analyzer status update worker only for attached projects' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker).to receive(:perform_async)
          .with([project1.id], profile.scan_type)

        execute_service
      end
    end

    context "when a project's only attachment is to a soft-deleted profile" do
      let(:projects) { [project_at_limit] }

      before do
        ::Security::ScanProfile.find(other_profile.id).destroy!
      end

      it 'does not count the soft-deleted attachment toward the limit' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(1)
        expect(Security::ScanProfileProject.where(project: project_at_limit, scan_profile: profile)).to exist
      end

      it_behaves_like 'returns empty errors'
    end

    context 'when profile is already attached to a project' do
      let(:projects) { [project1] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
      end

      it 'does not create duplicate associations' do
        expect { execute_service }.not_to change { Security::ScanProfileProject.count }
      end

      it_behaves_like 'does not schedule the analyzer status update worker'
      it_behaves_like 'returns empty errors'
    end

    context 'when a project is at the limit and has the specific profile attached already' do
      let(:projects) { [project_at_limit] }

      before do
        create(:security_scan_profile_project, project: project_at_limit, scan_profile: profile)
      end

      it 'does not create a duplicate' do
        expect { execute_service }.not_to change { Security::ScanProfileProject.count }
      end

      it_behaves_like 'does not schedule the analyzer status update worker'
      it_behaves_like 'returns empty errors'
    end

    context 'when more than MAX_PROJECTS are provided' do
      let(:projects) { [project1, project2, project_at_limit] }

      before do
        stub_const("#{described_class}::MAX_PROJECTS", 2)
      end

      it 'returns an error' do
        result = execute_service
        expect(result[:errors]).to include('Cannot attach profile to more than 2 items at once.')
      end

      it_behaves_like 'does not schedule the analyzer status update worker'
    end

    context 'when an unexpected error occurs during insertion' do
      let(:projects) { [project1] }

      before do
        allow(Security::ScanProfileProject).to receive(:connection).and_raise(StandardError, 'DB connection failed')
      end

      it 'raises the error in development/test environment' do
        expect { execute_service }.to raise_error(StandardError, 'DB connection failed')
      end

      context 'when not in development environment' do
        before do
          allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception) do |e|
            Gitlab::ErrorTracking.track_exception(e)
          end
        end

        it 'returns an error result without raising' do
          result = execute_service

          expect(result[:errors]).to include('An error has occurred during profile attachment')
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

      it 'creates audit events for attached projects' do
        expect { execute_service }.to change { AuditEventReader.count }.by(2)
      end

      it 'creates audit events with correct attributes' do
        execute_service

        audit_event = AuditEventReader.last
        expect(audit_event.details).to include(
          event_name: 'security_scan_profile_attached_to_project',
          author_name: user.name,
          profile_id: profile.id,
          profile_name: profile.name,
          scan_type: profile.scan_type
        )
        expect(audit_event.details[:project_id]).to be_in([project1.id, project2.id])
        expect(audit_event.details[:project_path]).to be_in([project1.full_path, project2.full_path])
        expect(audit_event.details[:custom_message]).to start_with("Attached security scan profile '#{profile.name}'")
      end

      context 'when no projects are successfully attached' do
        let(:projects) { [project_at_limit] }

        it 'does not create audit events' do
          expect { execute_service }.not_to change { AuditEventReader.count }
        end
      end

      context 'when attached project IDs do not match provided projects' do
        let(:projects) { [project1] }

        before do
          # Simulate a scenario where the insert returns IDs that don't match the provided projects
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:insert_under_limit).and_return([999_999])
          end
        end

        it 'does not create audit events' do
          expect { execute_service }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
