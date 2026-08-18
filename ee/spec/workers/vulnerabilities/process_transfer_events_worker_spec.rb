# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ProcessTransferEventsWorker, feature_category: :vulnerability_management, type: :job do
  let_it_be(:old_group) { create(:group) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :with_vulnerability, group: group) }
  let_it_be(:vulnerability_statistic) { create(:vulnerability_statistic, :grade_f, project: project) }
  let_it_be(:other_project) { create(:project, :with_vulnerability, group: group) }
  let_it_be(:other_vulnerability_statistic) { create(:vulnerability_statistic, :grade_f, project: other_project) }
  let_it_be(:project_without_vulnerabilities) { create(:project, group: group) }

  let(:project_event) do
    ::Projects::ProjectTransferedEvent.new(data: {
      project_id: project.id,
      old_namespace_id: old_group.id,
      old_root_namespace_id: old_group.id,
      new_namespace_id: group.id,
      new_root_namespace_id: group.id
    })
  end

  let(:group_event) do
    ::Groups::GroupTransferedEvent.new(data: {
      group_id: group.id,
      old_root_namespace_id: old_group.id,
      new_root_namespace_id: group.id
    })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  context 'when the associated project has vulnerabilities' do
    context 'when a project transfered event is published', :sidekiq_inline do
      let(:event) { project_event }

      it_behaves_like 'subscribes to event'

      it 'enqueues a vulnerability reads and statistics traversal ids update job for the project id' do
        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to receive(:bulk_perform_async).with(
          [[project.id]]
        )
        expect(Vulnerabilities::UpdateTraversalIdsOfVulnerabilityStatisticWorker).to receive(:bulk_perform_async).with(
          [[project.id]]
        )

        use_event
      end
    end

    context 'when a group transfered event is published', :sidekiq_inline do
      let(:event) { group_event }

      it_behaves_like 'subscribes to event'

      it 'enqueues a vulnerability reads namespace id update job for each project id belonging to the namespace id' do
        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to receive(:bulk_perform_async).with(
          match_array([[project.id], [other_project.id]])
        )

        use_event
      end

      it 'enqueues a vulnerability stat traversal ids update job for each project id belonging in the group' do
        expect(Vulnerabilities::UpdateTraversalIdsOfVulnerabilityStatisticWorker).to receive(:bulk_perform_async).with(
          match_array([[project.id], [other_project.id]])
        )

        use_event
      end
    end
  end

  context 'when the associated project does not have vulnerabilities' do
    let(:project) { project_without_vulnerabilities }

    context 'when a project transfered event is published', :sidekiq_inline do
      let(:event) { project_event }

      it 'does not enqueue jobs to update traversal ids in vulnerability reads and statistics' do
        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).not_to receive(:bulk_perform_async)
        expect(Vulnerabilities::UpdateTraversalIdsOfVulnerabilityStatisticWorker).not_to receive(:bulk_perform_async)

        use_event
      end
    end
  end
end
