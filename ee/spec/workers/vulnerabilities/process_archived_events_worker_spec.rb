# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ProcessArchivedEventsWorker, feature_category: :vulnerability_management, type: :job do
  let_it_be(:old_group) { create(:group) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :with_vulnerability, group: group) }
  let_it_be(:vulnerability_statistic) { create(:vulnerability_statistic, project: project) }
  let_it_be(:project_without_vulnerabilities) { create(:project, group: group) }

  let(:event) do
    ::Projects::ProjectArchivedEvent.new(data: {
      project_id: project.id,
      namespace_id: group.id,
      root_namespace_id: group.id
    })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  context 'when the associated project has vulnerabilities' do
    before do
      project.project_setting.update!(has_vulnerabilities: true)
    end

    it_behaves_like 'subscribes to event'

    it 'enqueues a vulnerability reads namespace id update job for the project id' do
      expect(Vulnerabilities::UpdateArchivedOfVulnerabilityReadsService).to receive(:execute).with(
        project.id
      )

      use_event
    end

    it 'enqueues a vulnerability statistics namespace id update job for the project id' do
      expect(Vulnerabilities::UpdateArchivedOfVulnerabilityStatisticsService).to receive(:execute).with(
        project.id
      )

      use_event
    end

    it 'calls the namespace statistics remove project update service' do
      expect(Group).to receive(:find_by_id).with(group.id).and_return(group)
      expect(Vulnerabilities::NamespaceStatistics::RecalculateService)
        .to receive(:execute).with(group)

      use_event
    end

    context 'when the group does not exist' do
      it 'does not call the namespace statistics remove project update service when no group is found' do
        expect(Group).to receive(:find_by_id).with(group.id).and_return(nil)
        expect(Vulnerabilities::NamespaceStatistics::RecalculateService).not_to receive(:execute)

        use_event
      end

      it 'still calls the vulnerability update services when no group is found' do
        expect(Group).to receive(:find_by_id).with(group.id).and_return(nil)
        expect(Vulnerabilities::UpdateArchivedOfVulnerabilityReadsService).to receive(:execute).with(project.id)
        expect(Vulnerabilities::UpdateArchivedOfVulnerabilityStatisticsService).to receive(:execute).with(project.id)

        use_event
      end
    end
  end

  context 'when the associated project does not have vulnerabilities' do
    let(:project) { project_without_vulnerabilities }

    context 'when a project transfered event is published', :sidekiq_inline do
      it 'does not enqueue any update jobs' do
        expect(Vulnerabilities::UpdateArchivedOfVulnerabilityReadsService).not_to receive(:execute)
        expect(Vulnerabilities::UpdateArchivedOfVulnerabilityStatisticsService).not_to receive(:execute)
        expect(Vulnerabilities::NamespaceStatistics::RecalculateService).not_to receive(:execute)

        use_event
      end
    end
  end
end
