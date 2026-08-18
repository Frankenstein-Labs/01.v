# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Issues, :aggregate_failures, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }

  describe 'POST /projects/:id/issues' do
    context 'when an issue is added under an epic with max children limit reached' do
      let(:group) { create(:group) }
      let(:group_project) { create(:project, :public, namespace: group) }
      let(:epic) { create(:epic, group: group) }
      let(:expected_error) do
        _('You cannot add any more issues. This epic already has maximum number of child issues & epics.')
      end

      before do
        group.add_owner(user)
        stub_licensed_features(epics: true)
        stub_const("EE::Epic::MAX_CHILDREN_COUNT", 2)
      end

      it 'returns 422' do
        create_list(:epic, 2, parent: epic)

        post api("/projects/#{group_project.id}/issues", user),
          params: { title: 'new issue', epic_id: epic.id }

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq(expected_error)
      end
    end
  end
end
