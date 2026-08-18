# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::WorkItemsMenu, feature_category: :navigation do
  let(:project) { build_stubbed(:project) }
  let(:user) { project.first_owner }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

  describe 'Iterations Feature Library metadata' do
    let_it_be(:user) { create(:user, :with_namespace) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:iterations_item) do
      described_class.new(context).renderable_items.find { |e| e.item_id == :iterations }
    end

    context 'when iterations is licensed' do
      before do
        stub_licensed_features(iterations: true)
      end

      before_all do
        group.add_owner(user)
      end

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = iterations_item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end
  end

  describe 'Jira issue list Feature Library metadata' do
    let_it_be(:project) { create(:project, has_external_issue_tracker: true) }
    let_it_be(:jira_integration) do
      create(:jira_integration, project: project, project_key: 'GL', issues_enabled: true)
    end

    let(:context) do
      Sidebars::Projects::Context.new(current_user: user, container: project, jira_issues_integration: true)
    end

    subject(:jira_issue_list_item) do
      described_class.new(context).renderable_items.find { |e| e.item_id == :jira_issue_list }
    end

    before do
      stub_licensed_features(jira_issues_integration: true)
    end

    it 'carries a description so it is discoverable in the Feature Library', :aggregate_failures do
      serialized = jira_issue_list_item.serialize_for_super_sidebar

      expect(serialized[:description]).to eq('Manage Jira issues')
      expect(serialized[:library_icon]).to eq('work-items')
    end
  end
end
