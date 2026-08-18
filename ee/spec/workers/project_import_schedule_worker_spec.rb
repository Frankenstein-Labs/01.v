# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectImportScheduleWorker, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :public) }

  describe '#perform' do
    it_behaves_like 'an idempotent worker' do
      let!(:import_state) { create(:import_state, :none, project: project) }

      before do
        project.update!(mirror: true, mirror_user: project.owner)
      end

      let(:job_args) { [project.id] }

      before do
        allow(Gitlab::Mirror).to receive(:available_capacity).and_return(5)
        allow(Gitlab::Mirror).to receive(:untrack_scheduling).and_call_original

        allow(Project).to receive(:find_by_id).with(project.id).and_return(project)
        allow(project).to receive(:add_import_job)
      end

      it 'does nothing if the database is read-only' do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
        expect(ProjectImportState).not_to receive(:project_id).with(project_id: project.id)

        subject
      end

      it 'schedules an import for a project' do
        expect(project).to receive(:add_import_job)
        expect(import_state).to be_none

        subject

        expect(import_state).to be_scheduled
      end

      it 'tracks the status of the worker' do
        subject

        expect(Gitlab::Mirror).to have_received(:untrack_scheduling).with(project.id).at_least(:once)
      end
    end

    context 'project is not found' do
      it 'does not fail' do
        expect { subject.perform(-1) }.not_to raise_error
      end

      it 'logs the error' do
        expect(subject).to receive(:log_extra_metadata_on_done)
          .with(:mirroring_skipped, 'No import state found for -1').and_call_original

        subject.perform(-1)
      end
    end

    context 'project does not have import state' do
      it 'does not fail' do
        expect(project.import_state).to be_nil

        expect { subject.perform(project.id) }.not_to raise_error
      end

      it 'logs the error' do
        expect(subject).to receive(:log_extra_metadata_on_done)
          .with(:mirroring_skipped, "No import state found for #{project.id}").and_call_original

        subject.perform(project.id)
      end
    end
  end

  context 'when project does not support mirroring' do
    let_it_be_with_reload(:import_state) { create(:import_state, :finished, project: project) }

    before do
      stub_licensed_features(repository_mirrors: false)
      project.update!(mirror: true, mirror_user: project.owner)
    end

    it 'marks a project hard failed' do
      expect(import_state).to be_finished

      subject.perform(project.id)
      import_state.reload

      expect(import_state).to be_failed
      expect(import_state.last_error).to eq('Project mirroring is not supported')
    end

    it 'does not send a notification' do
      expect(NotificationService).not_to receive(:new)

      subject.perform(project.id)
    end

    it 'changes the capacity' do
      expect(Gitlab::Mirror).to receive(:increment_capacity).with(project.id)
      expect(Gitlab::Mirror).to receive(:decrement_capacity).with(project.id)

      subject.perform(project.id)
    end

    it 'logs the error' do
      expect(subject).to receive(:log_extra_metadata_on_done)
                           .with(:mirroring_skipped, 'Project does not support mirroring').and_call_original

      subject.perform(project.id)
    end
  end

  context 'when import_state is canceled' do
    context 'when project is a mirror' do
      let_it_be(:mirror_project, freeze: false) { create(:project, :public) }
      let_it_be_with_reload(:import_state) { create(:import_state, :canceled, :mirror, project: mirror_project) }

      before do
        stub_licensed_features(repository_mirrors: true)
      end

      it 'recovers from canceled state and schedules with all expected side effects' do
        expect(subject).to receive(:log_extra_metadata_on_done)
          .with(:import_state_recovered, 'Recovered mirror from canceled state')

        subject.perform(mirror_project.id)
        import_state.reload

        expect(import_state).to be_scheduled
        expect(import_state.last_error).to eq('Mirror recovering from canceled state')
        expect(import_state.jid).to be_present
      end
    end

    context 'when project is not a mirror' do
      let(:non_mirror_project) { project }
      let_it_be_with_reload(:import_state) { create(:import_state, :canceled, project: project) }

      before do
        allow(non_mirror_project.import_state).to receive(:schedule)
      end

      it 'does not recover and skips with logging' do
        expect(subject).to receive(:log_extra_metadata_on_done)
          .with(:mirroring_skipped, 'Import was canceled and cannot recover')

        subject.perform(non_mirror_project.id)
        import_state.reload

        expect(import_state).to be_canceled
        expect(non_mirror_project.import_state).not_to have_received(:schedule)
      end
    end
  end
end
