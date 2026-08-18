# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ProcessGroupArchivedEventsWorker, feature_category: :vulnerability_management, type: :job do
  let_it_be(:group) { create(:group) }
  let_it_be(:project_1) { create(:project, :with_vulnerability, group: group) }
  let_it_be(:project_2) { create(:project, :with_vulnerability, group: group) }

  let(:event) do
    ::Namespaces::Groups::GroupArchivedEvent.new(data: {
      group_id: group.id,
      root_namespace_id: group.id - 1
    })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  it 'schedules Vulnerability Reads update workers for each project in the group' do
    project_ids = []
    context_projects = []
    expect(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker)
      .to receive(:bulk_perform_async_with_contexts) do |projects, arguments_proc:, context_proc:|
        project_ids += [projects.sort.map(&arguments_proc)]
        context_projects += [projects.sort.map(&context_proc)]
      end

    use_event

    expect(project_ids).to contain_exactly([project_1.id, project_2.id])
    expect(context_projects).to contain_exactly([{ project: project_1 }, { project: project_2 }])
  end

  it 'schedules Vulnerability Statistics update workers for each project in the group' do
    project_ids = []
    context_projects = []
    expect(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityStatisticsWorker)
      .to receive(:bulk_perform_async_with_contexts) do |projects, arguments_proc:, context_proc:|
        project_ids += [projects.sort.map(&arguments_proc)]
        context_projects += [projects.sort.map(&context_proc)]
      end

    use_event

    expect(project_ids).to contain_exactly([project_1.id, project_2.id])
    expect(context_projects).to contain_exactly([{ project: project_1 }, { project: project_2 }])
  end

  it 'schedules Namespace Statistics recalculation worker for the group' do
    expect(Vulnerabilities::NamespaceStatistics::RecalculateNamespaceStatisticsWorker)
      .to receive(:perform_in)
      .with(6.hours, group.id)

    use_event
  end
end
