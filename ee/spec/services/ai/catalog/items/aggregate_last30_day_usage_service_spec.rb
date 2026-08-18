# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Items::AggregateLast30DayUsageService, feature_category: :workflow_catalog do
  let(:service) { described_class.new }

  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:item) { create(:ai_catalog_item) }
    let_it_be_with_refind(:item_version) { create(:ai_catalog_item_version, item: item) }

    it 'returns a success response' do
      response = service.execute

      expect(response).to be_success
      expect(response.message).to eq('Usage counts updated for AI catalog items')
    end

    context 'when updating usage counts' do
      let_it_be_with_reload(:other_item) { create(:ai_catalog_item) }
      let_it_be_with_reload(:other_version) { create(:ai_catalog_item_version, item: other_item) }
      let_it_be(:other_project) { create(:project) }

      before do
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: project, created_at: 5.days.ago)
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: project, created_at: 2.days.ago)
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: other_project,
          created_at: 1.day.ago)
        create(:duo_workflows_workflow, ai_catalog_item_version: other_version, project: project,
          created_at: 10.days.ago)
        create(:duo_workflows_workflow, ai_catalog_item_version: nil, project: project, created_at: 3.days.ago)
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: nil,
          namespace_id: project.namespace_id, created_at: 3.days.ago)

        service.execute
      end

      it 'updates item usage counts' do
        expect(item.reload.last_30_day_usage_count).to eq(2)
        expect(other_item.reload.last_30_day_usage_count).to eq(1)
      end
    end

    context 'when filtering by date' do
      let_it_be(:project) { create(:project) }

      before do
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: project,
          created_at: 29.days.ago)
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: project,
          created_at: 31.days.ago)

        service.execute
      end

      it 'only counts usage from the last 30 days' do
        expect(item.reload.last_30_day_usage_count).to eq(1)
      end
    end

    context 'when item has no workflows' do
      let_it_be(:unused_item) { create(:ai_catalog_item) }

      it 'sets the usage count to zero' do
        service.execute

        expect(unused_item.reload.last_30_day_usage_count).to eq(0)
      end
    end

    context 'when item is deleted' do
      let_it_be_with_reload(:deleted_item) { create(:ai_catalog_item, deleted_at: 1.day.ago, project: project) }
      let_it_be_with_refind(:item_version) { create(:ai_catalog_item_version, item: deleted_item) }

      it 'does not update usage' do
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: project, created_at: 1.day.ago)

        service.execute

        expect(deleted_item.reload.last_30_day_usage_count_updated_at).to eq(Date.new(1970, 1, 1))
      end
    end

    context 'when workflow record is not associated with a project' do
      let_it_be_with_reload(:item) { create(:ai_catalog_item, project: project) }
      let_it_be_with_refind(:item_version) { create(:ai_catalog_flow_version) }

      it 'does not count usage' do
        create(:duo_workflows_workflow, ai_catalog_item_version: item_version, project: nil,
          namespace: create(:namespace), created_at: 1.day.ago)

        service.execute

        expect(item.reload.last_30_day_usage_count).to eq(0)
      end
    end
  end
end
