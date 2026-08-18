# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::WorkItems::CreateWorkItemNoteTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group, iid: 123) }

  let(:params) { { group_id: group.id.to_s, work_item_iid: group_work_item.iid, body: 'Test comment' } }
  let(:tool) { described_class.new(current_user: user, params: params) }

  before_all do
    group.add_developer(user)
  end

  describe '#build_variables' do
    context 'with group work item (epic)' do
      let(:params) do
        {
          group_id: group.id.to_s,
          work_item_iid: group_work_item.iid,
          body: 'Test comment on epic'
        }
      end

      it 'resolves group work item' do
        stub_licensed_features(epics: true)

        variables = tool.build_variables

        expect(variables[:input][:noteableId]).to eq(group_work_item.to_global_id.to_s)
      end
    end
  end
end
