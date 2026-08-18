# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Foundational flows cascading', feature_category: :ai_abstraction_layer do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:root_group) do
    create(:group, organization: organization).tap do |g|
      g.add_owner(user)
    end
  end

  let_it_be(:subgroup) do
    create(:group, parent: root_group, organization: organization)
  end

  let_it_be(:flow1) do
    create(:ai_catalog_item, :flow, :with_foundational_flow_reference, :public,
      organization: organization, name: 'flow1')
  end

  let_it_be(:flow2) do
    create(:ai_catalog_item, :flow, :with_foundational_flow_reference, :public,
      organization: organization, name: 'flow2')
  end

  before_all do
    root_group.namespace_settings.update!(duo_foundational_flows_enabled: true)
    root_group.sync_enabled_foundational_flows!([flow1.id, flow2.id])

    create(:ai_catalog_item_consumer, group: root_group, item: flow1)
    create(:ai_catalog_item_consumer, group: root_group, item: flow2)
  end

  before do
    allow(Ai::Catalog::Item).to receive(:foundational_flow_ids).and_return([flow1.id, flow2.id])
  end

  describe 'Issue 588795: Flows cascading to subgroups and new projects' do
    context 'when a new project is created in a subgroup' do
      it 'inherits foundational flows from root group' do
        project = create(:project, group: subgroup, creator: user)

        expect(project.duo_foundational_flows_enabled).to be true
        expect(project.enabled_flow_catalog_item_ids).to contain_exactly(flow1.id, flow2.id)
      end
    end

    context 'when checking subgroup flow inheritance' do
      it 'subgroup inherits enabled_flow_catalog_item_ids from root group' do
        expect(subgroup.namespace_settings.duo_foundational_flows_enabled).to be true
        expect(subgroup.enabled_flow_catalog_item_ids).to contain_exactly(flow1.id, flow2.id)
      end
    end
  end

  describe 'Issue 588761: Flows for imported/forked projects' do
    context 'when a project is imported (simulated via after_import)' do
      it 'syncs foundational flows after import completes' do
        project = create(:project, group: subgroup, creator: user)
        project.import_state&.destroy!
        create(:import_state, :started, project: project)

        Sidekiq::Testing.inline! do
          project.after_import
        end

        project.reload
        expect(project.enabled_flow_catalog_item_ids).to contain_exactly(flow1.id, flow2.id)
        expect(project.enabled_foundational_flow_records.pluck(:catalog_item_id)).to contain_exactly(flow1.id, flow2.id)
      end
    end

    context 'when a project is forked (simulated via after_import)' do
      it 'syncs foundational flows after fork completes' do
        forked_project = create(:project, group: subgroup, creator: user)
        forked_project.import_state&.destroy!
        create(:import_state, :started, project: forked_project)

        Sidekiq::Testing.inline! do
          forked_project.after_import
        end

        forked_project.reload
        expect(forked_project.enabled_flow_catalog_item_ids).to contain_exactly(flow1.id, flow2.id)
        expect(forked_project.enabled_foundational_flow_records.pluck(:catalog_item_id)).to contain_exactly(flow1.id,
          flow2.id)
      end
    end
  end

  describe 'Combined scenario: deep hierarchy with imports' do
    let_it_be(:deep_subgroup) { create(:group, parent: subgroup, organization: organization) }

    context 'when a project is created in a deeply nested subgroup' do
      it 'inherits flows from root through the hierarchy' do
        project = create(:project, group: deep_subgroup, creator: user)

        expect(project.duo_foundational_flows_enabled).to be true
        expect(project.enabled_flow_catalog_item_ids).to contain_exactly(flow1.id, flow2.id)
      end
    end

    context 'when a project is imported into a deeply nested subgroup' do
      it 'syncs flows after import' do
        project = create(:project, group: deep_subgroup, creator: user)
        project.import_state&.destroy!
        create(:import_state, :started, project: project)

        Sidekiq::Testing.inline! do
          project.after_import
        end

        project.reload
        expect(project.enabled_flow_catalog_item_ids).to contain_exactly(flow1.id, flow2.id)
      end
    end
  end
end
