# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Handlers::CopyDataHandler, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:target_namespace) { project.project_namespace }
  let(:target_work_item_type) { build(:work_item_system_defined_type) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { some: 'params' } }
  let(:overwritten_params) { { overwritten: 'params' } }

  subject(:copy_data_handler) do
    described_class.new(
      work_item: work_item,
      target_namespace: target_namespace,
      target_work_item_type: target_work_item_type,
      current_user: current_user,
      params: params,
      overwritten_params: overwritten_params
    )
  end

  describe '#execute' do
    let(:base_create_service) { instance_double(WorkItems::DataSync::BaseCreateService) }

    before do
      allow(WorkItems::DataSync::BaseCreateService).to receive(:new).and_return(base_create_service)
    end

    context 'when BaseCreateService raises an error' do
      it 'raises error' do
        allow(base_create_service).to receive(:execute).and_raise("Some error")
        expect(copy_data_handler).not_to receive(:maintaining_elasticsearch?)
        expect(copy_data_handler).not_to receive(:trigger_elastic_search_updates)

        expect { copy_data_handler.execute }.to raise_error("Some error")
      end
    end

    it 'calls BaseCreateService with correct parameters' do
      result = ServiceResponse.success(payload: { work_item: instance_double(WorkItem) })

      project = instance_double(Project)
      new_work_item = result[:work_item]

      expect(base_create_service).to receive(:execute).and_return(result)
      expect(copy_data_handler).to receive(:maintaining_elasticsearch?).and_call_original
      expect(copy_data_handler).to receive(:trigger_elastic_search_updates).with(new_work_item).and_call_original
      expect(new_work_item).to receive(:maintaining_elasticsearch?).and_return(true)
      expect(new_work_item).to receive(:project).and_return(project)
      expect(project).to receive(:maintaining_indexed_associations?).and_return(true)
      expect(new_work_item).to receive(:maintain_elasticsearch_update)
      expect(new_work_item).to receive(:maintain_elasticsearch_issue_notes_update)

      copy_data_handler.execute
    end
  end
end
