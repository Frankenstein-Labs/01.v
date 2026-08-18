# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::WorkItems::LinkWorkItemsService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:source_work_item) { create(:work_item, :issue, project: project, iid: 1) }
  let_it_be(:target_work_item) { create(:work_item, :issue, project: project, iid: 2) }

  let(:service) { described_class.new(name: 'link_work_items') }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:target_gid) { target_work_item.to_global_id.to_s }

  before_all do
    project.add_developer(user)
  end

  before do
    service.set_cred(current_user: user)
  end

  describe '#description' do
    it 'includes blocks and blocked_by in description' do
      expect(service.description).to include('relates_to, blocks, blocked_by')
    end
  end

  describe '#input_schema' do
    let(:properties) { service.input_schema[:properties] }

    it 'extends link_type enum with blocks and blocked_by' do
      expect(properties[:link_type][:enum]).to match_array(%w[relates_to blocks blocked_by])
    end

    it 'preserves all other CE schema properties unchanged' do
      expect(properties[:link_type][:default]).to eq('relates_to')
      expect(service.input_schema[:required]).to eq(['work_items_ids'])
    end
  end

  describe '#execute' do
    subject(:result) { service.execute(request: request, params: params) }

    context 'when link_type is blocks' do
      before do
        stub_licensed_features(blocked_work_items: true)
      end

      let(:params) do
        {
          arguments: {
            project_id: project.id.to_s,
            work_item_iid: source_work_item.iid,
            work_items_ids: [target_gid],
            link_type: 'blocks'
          }
        }
      end

      it 'links work items with blocks relationship' do
        expect(result[:isError]).to be(false)
      end
    end

    context 'when link_type is blocked_by' do
      before do
        stub_licensed_features(blocked_work_items: true)
      end

      let(:params) do
        {
          arguments: {
            project_id: project.id.to_s,
            work_item_iid: source_work_item.iid,
            work_items_ids: [target_gid],
            link_type: 'blocked_by'
          }
        }
      end

      it 'links work items with blocked_by relationship' do
        expect(result[:isError]).to be(false)
      end
    end

    context 'when link_type is blocks but feature is not licensed' do
      before do
        stub_licensed_features(blocked_work_items: false)
      end

      let(:params) do
        {
          arguments: {
            project_id: project.id.to_s,
            work_item_iid: source_work_item.iid,
            work_items_ids: [target_gid],
            link_type: 'blocks'
          }
        }
      end

      it 'returns an error about subscription tier' do
        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text])
          .to include('Blocked work items are not available for the current subscription tier')
      end
    end
  end
end
