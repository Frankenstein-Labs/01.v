# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::WorkItems::GetWorkItemTypesTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: root_group) }
  let_it_be(:custom_type) { create(:work_item_custom_type, namespace: root_group, name: 'Custom Feature') }

  let(:params) { { group_id: root_group.id.to_s } }
  let(:tool) { described_class.new(current_user: user, params: params) }

  before_all do
    project.add_developer(user)
    root_group.add_developer(user)
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
    stub_saas_features(namespace_scoped_work_item_types: true)
  end

  describe 'integration with custom work item types' do
    it 'includes the custom work item type created on the root group in the response' do
      result = tool.execute

      expect(result[:isError]).to be(false)
      type_names = result[:structuredContent]['workItemTypes'].pluck('name')
      expect(type_names).to include(custom_type.name)
    end

    context 'when identified by project_id under the same root group' do
      let(:params) { { project_id: project.id.to_s } }

      it 'still resolves the custom work item type inherited from the root group' do
        result = tool.execute

        expect(result[:isError]).to be(false)
        type_names = result[:structuredContent]['workItemTypes'].pluck('name')
        expect(type_names).to include(custom_type.name)
      end
    end
  end
end
