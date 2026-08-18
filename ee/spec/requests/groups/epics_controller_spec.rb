# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::EpicsController, feature_category: :portfolio_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  describe 'GET #index' do
    subject(:get_index) { get group_epics_path(group) }

    context 'when epics are not licensed' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns not_found' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when redirecting to work items' do
      let(:work_items_path) { group_work_items_path(group) }

      it 'redirects with the numeric epic type id' do
        epic_type = WorkItems::TypesFramework::Provider.new(group).find_by_base_type(:epic)

        get_index

        expect(response).to redirect_to("#{work_items_path}?type%5B%5D=#{epic_type.id}")
      end

      it 'strips existing type params and preserves other params' do
        get group_epics_path(group, 'type[]' => 'old', state: 'closed')

        epic_type = WorkItems::TypesFramework::Provider.new(group).find_by_base_type(:epic)

        expect(response).to redirect_to("#{work_items_path}?state=closed&type%5B%5D=#{epic_type.id}")
      end
    end
  end

  describe 'GET #new' do
    subject(:get_new) { get new_group_epic_path(group) }

    it 'redirects to new work item' do
      get_new

      expect(response).to redirect_to(group_work_item_new_url(group))
    end

    context 'when license is not available' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns not found' do
        get_new

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    context 'for work item epics' do
      it 'redirects to work item page' do
        get group_epic_path(group, epic)

        expect(response).to redirect_to(group_work_item_path(group, epic.work_item))
      end

      it 'renders json when requesting json response' do
        get group_epic_path(group, epic, format: :json)

        expect(response).to have_gitlab_http_status(:success)
        expect(response.media_type).to eq('application/json')
      end
    end
  end
end
