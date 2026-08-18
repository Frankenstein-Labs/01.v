# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::WorkItems::LinkWorkItemsTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:source_work_item) { create(:work_item, :issue, project: project, iid: 1) }
  let_it_be(:target_work_item) { create(:work_item, :issue, project: project, iid: 2) }

  let(:target_gid) { target_work_item.to_global_id.to_s }
  let(:params) do
    {
      project_id: project.id.to_s,
      work_item_iid: source_work_item.iid,
      work_items_ids: [target_gid]
    }
  end

  let(:tool) { described_class.new(current_user: user, params: params) }

  before_all do
    project.add_developer(user)
  end

  describe '#normalized_link_type (EE)' do
    context 'when link_type is blocks' do
      before do
        params[:link_type] = 'blocks'
      end

      context 'when blocked_work_items is licensed' do
        before do
          stub_licensed_features(blocked_work_items: true)
        end

        it 'maps to BLOCKS' do
          variables = tool.build_variables

          expect(variables[:input][:linkType]).to eq('BLOCKS')
        end
      end

      context 'when blocked_work_items is not licensed' do
        before do
          stub_licensed_features(blocked_work_items: false)
        end

        it 'raises ArgumentError with subscription tier message' do
          expect { tool.build_variables }
            .to raise_error(ArgumentError, 'Blocked work items are not available for the current subscription tier')
        end
      end
    end

    context 'when link_type is blocked_by' do
      before do
        params[:link_type] = 'blocked_by'
      end

      context 'when blocked_work_items is licensed' do
        before do
          stub_licensed_features(blocked_work_items: true)
        end

        it 'maps to BLOCKED_BY' do
          variables = tool.build_variables

          expect(variables[:input][:linkType]).to eq('BLOCKED_BY')
        end
      end

      context 'when blocked_work_items is not licensed' do
        before do
          stub_licensed_features(blocked_work_items: false)
        end

        it 'raises ArgumentError with subscription tier message' do
          expect { tool.build_variables }
            .to raise_error(ArgumentError, 'Blocked work items are not available for the current subscription tier')
        end
      end
    end

    context 'when link_type is invalid' do
      before do
        params[:link_type] = 'invalid_type'
      end

      it 'delegates to CE and raises ArgumentError' do
        expect { tool.build_variables }
          .to raise_error(ArgumentError, /Invalid link_type/)
      end
    end
  end

  describe 'integration with blocks link type' do
    before do
      stub_licensed_features(blocked_work_items: true)
    end

    let(:params) do
      {
        project_id: project.id.to_s,
        work_item_iid: source_work_item.iid,
        work_items_ids: [target_gid],
        link_type: 'blocks'
      }
    end

    it 'executes mutation with BLOCKS link type' do
      allow(GitlabSchema).to receive(:execute).and_call_original

      tool.execute

      expect(GitlabSchema).to have_received(:execute).with(
        anything,
        variables: hash_including(
          input: hash_including(linkType: 'BLOCKS')
        ),
        context: anything
      )
    end
  end
end
