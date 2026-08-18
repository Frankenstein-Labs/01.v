# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::WorkItems::BaseTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group, iid: 123) }

  let(:params) { {} }

  # Create a concrete test implementation since BaseTool is abstract
  let(:test_tool_class) do
    Class.new(described_class) do
      register_version '1.0.0', {
        operation_name: 'testOperation',
        graphql_operation: 'mutation { test }'
      }

      def build_variables
        { input: {} }
      end

      # Expose protected methods for testing
      def test_resolve_work_item_id
        resolve_work_item_id
      end
    end
  end

  let(:tool) { test_tool_class.new(current_user: user, params: params) }

  before_all do
    group.add_developer(user)
  end

  describe '#resolve_work_item_id' do
    context 'when group_id and work_item_iid are provided (epic)' do
      let(:params) { { group_id: group.id.to_s, work_item_iid: group_work_item.iid } }

      it 'resolves work item from params and returns global ID' do
        stub_licensed_features(epics: true)

        result = tool.test_resolve_work_item_id

        expect(result).to eq(group_work_item.to_global_id.to_s)
      end
    end
  end
end
