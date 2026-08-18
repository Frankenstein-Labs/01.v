# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::RescheduleWorker, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  subject(:perform) { described_class.new.perform(project.id) }

  it 'runs the scheduler with skip_dismissed_branches: true' do
    expect(DependencyManagement::SecurityUpdate::SchedulerService)
      .to receive(:execute).with(project: project, skip_dismissed_branches: true)

    perform
  end

  context 'when the project does not exist' do
    it 'does nothing' do
      expect(DependencyManagement::SecurityUpdate::SchedulerService).not_to receive(:execute)

      described_class.new.perform(non_existing_record_id)
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [project.id] }

    it 'invokes the scheduler' do
      expect(DependencyManagement::SecurityUpdate::SchedulerService)
        .to receive(:execute).with(project: project, skip_dismissed_branches: true).at_least(:once)

      perform
    end
  end
end
