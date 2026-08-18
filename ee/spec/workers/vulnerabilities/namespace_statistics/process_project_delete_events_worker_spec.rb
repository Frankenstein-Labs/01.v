# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::ProcessProjectDeleteEventsWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  describe '#handle_event' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:statistics) { create(:vulnerability_statistic, project: project) }

    let(:recalculate_service) { Vulnerabilities::NamespaceStatistics::RecalculateService }

    let(:event) do
      Projects::ProjectDeletedEvent.new(data: {
        project_id: project.id,
        namespace_id: namespace_id
      })
    end

    subject(:handle_event) { worker.handle_event(event) }

    before do
      allow(recalculate_service).to receive(:execute)
    end

    context 'when there is no group associated with the event' do
      let(:namespace_id) { non_existing_record_id }

      it 'does not call the delete statistics or service layer logic' do
        expect { handle_event }.not_to change { Vulnerabilities::Statistic.count }
        expect(recalculate_service).not_to have_received(:execute)
      end
    end

    context 'when there is a group and project_id associated with the event' do
      let(:namespace_id) { group.id }

      it 'deletes the statistics for the project' do
        expect { handle_event }.to change { Vulnerabilities::Statistic.count }.to(0)
      end

      it 'calls the recalculate service with the group' do
        handle_event

        expect(recalculate_service).to have_received(:execute).with(group)
      end

      it 'deletes statistics before calling the recalculate service' do
        statistic_relation = instance_double(ActiveRecord::Relation)

        expect(Vulnerabilities::Statistic).to receive(:by_projects).with(project.id)
           .and_return(statistic_relation).ordered
        expect(statistic_relation).to receive(:delete_all).ordered
        expect(recalculate_service).to receive(:execute).with(group).ordered

        handle_event
      end
    end
  end
end
