# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::WorkItems::GetWorkItemNotesService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group, iid: 123) }
  let_it_be(:note) { create(:note, noteable: group_work_item, author: user, note: 'Test comment on epic') }

  let(:service) { described_class.new(name: 'get_workitem_notes') }
  let(:request) { instance_double(ActionDispatch::Request) }

  before_all do
    group.add_developer(user)
  end

  before do
    service.set_cred(current_user: user)
  end

  describe '#execute' do
    context 'with group work item (epic)' do
      let(:params) do
        {
          arguments: {
            group_id: group.id.to_s,
            work_item_iid: group_work_item.iid
          }
        }
      end

      it 'retrieves notes from epic' do
        stub_licensed_features(epics: true)

        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]['nodes']).to be_present
      end

      it 'instantiates tool with correct parameters for epic' do
        stub_licensed_features(epics: true)

        expect(Mcp::Tools::WorkItems::GetWorkItemNotesTool).to receive(:new).with(
          current_user: user,
          params: params[:arguments],
          version: '0.1.0'
        ).and_call_original

        service.execute(request: request, params: params)
      end
    end
  end
end
