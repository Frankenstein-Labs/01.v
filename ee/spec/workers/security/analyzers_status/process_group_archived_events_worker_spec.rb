# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::ProcessGroupArchivedEventsWorker, feature_category: :security_asset_inventories, type: :job do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project_1) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }
  let_it_be(:project_3) { create(:project, group: subgroup) }

  let(:worker) { described_class.new }
  let(:event) do
    ::Namespaces::Groups::GroupArchivedEvent.new(data: {
      group_id: group.id,
      root_namespace_id: group.id
    })
  end

  describe '#handle_event' do
    subject(:handle_event) { worker.handle_event(event) }

    it 'schedules UpdateArchivedAnalyzerStatusWorker for each project in the group and subgroups' do
      project_ids = []
      context_projects = []

      expect(Security::AnalyzersStatus::UpdateArchivedAnalyzerStatusWorker)
        .to receive(:bulk_perform_async_with_contexts).at_least(:once) do |projects, arguments_proc:, context_proc:|
          project_ids += projects.map(&arguments_proc)
          context_projects += projects.map(&context_proc)
        end

      handle_event

      expect(project_ids).to contain_exactly(project_1.id, project_2.id, project_3.id)
      expect(context_projects).to contain_exactly(
        { project: project_1 },
        { project: project_2 },
        { project: project_3 }
      )
    end

    it 'schedules RecalculateWorker with delay based on 3 projects' do
      expect(Security::AnalyzerNamespaceStatuses::RecalculateWorker)
        .to receive(:perform_in) do |delay, namespace_id|
          expect(delay).to be_within(1.minute).of(5.minutes)
          expect(namespace_id).to eq(group.id)
        end

      handle_event
    end

    context 'with 1000 projects' do
      before do
        allow(Security::AnalyzersStatus::UpdateArchivedAnalyzerStatusWorker)
          .to receive(:bulk_perform_async_with_contexts)

        allow_next_instance_of(Gitlab::Database::NamespaceEachBatch) do |instance|
          allow(instance).to receive(:each_batch).and_yield([group.id], nil)
        end

        allow(Project).to receive_message_chain(:in_namespace, :each_batch) do |&block|
          10.times do # Simulate 10 batches of 100 projects each to reach 1000 total
            batch = instance_double(ActiveRecord::Relation, size: 100)
            block.call(batch)
          end
        end
      end

      it 'schedules RecalculateWorker with delay based on 1000 projects' do
        expect(Security::AnalyzerNamespaceStatuses::RecalculateWorker)
          .to receive(:perform_in) do |delay, namespace_id|
          expect(delay).to be_within(1.minute).of(22.minutes)
          expect(namespace_id).to eq(group.id)
        end

        handle_event
      end
    end
  end
end
