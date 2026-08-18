# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::OpenWorkItemsCountService, :use_clean_rails_memory_store_caching,
  feature_category: :team_planning do
  let_it_be(:group)   { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:user)    { create(:user) }

  subject(:service) { described_class.new(project, user) }

  before_all do
    project.add_planner(user)
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  describe '#count' do
    let_it_be(:work_item)   { create(:work_item, :opened, project: project) }
    let_it_be(:test_case)   { create(:work_item, :test_case, :opened, project: project) }
    let_it_be(:requirement) { create(:work_item, :requirement, :opened, project: project) }

    it 'excludes test_case and requirement work items, counting only filterable types' do
      expect(service.count).to eq(1) # only the issue-type work_item
    end

    context 'when a custom work item type is disabled via type visibility' do
      let_it_be(:custom_type) do
        create(:work_item_custom_type, :with_organization, name: 'Story', organization: group.organization)
      end

      before do
        create(:work_item, project: project, work_item_type: custom_type)

        create(:work_item_settings, :for_organization,
          organization: group.organization,
          customizable_type_visibility: true
        )
        create(:work_item_type_visibility,
          namespace: project.project_namespace,
          work_item_type_id: custom_type.id,
          enabled: false
        )
      end

      it 'counts all filterable items excluding the disabled custom type' do
        expect(service.count).to eq(1)
      end
    end
  end

  describe '#relation_for_count' do
    it 'delegates to .query then excludes non-filterable types' do
      allow(described_class).to receive(:query).and_call_original

      expect(described_class).to receive(:query).with(project, public_only: false)

      service.count
    end

    context 'when there are no non-filterable types' do
      before do
        allow(service).to receive(:non_filterable_type_ids).and_return([])
      end

      it 'returns the base query without type filtering' do
        expect(service.relation_for_count).to be_a(ActiveRecord::Relation)
      end
    end
  end
end
