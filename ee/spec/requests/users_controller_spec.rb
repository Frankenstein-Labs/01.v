# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UsersController, feature_category: :user_profile do
  let_it_be(:user, freeze: false) { create(:user) }

  before do
    sign_in user
    stub_licensed_features(group_project_templates: true)
  end

  describe '#available_group_templates' do
    let_it_be(:group) { create(:group) }
    let_it_be(:template_subgroup) { create(:group, parent: group) }
    let_it_be(:template_project) { create(:project, group: template_subgroup) }

    before_all do
      group.update!(custom_project_templates_group_id: template_subgroup.id)
      group.add_maintainer(user)
    end

    it 'returns templates scoped to the specified group' do
      get user_available_group_templates_path(user.username, group_id: group.id)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include(template_project.name)
    end

    it 'avoids N+1 queries when adding more template projects' do
      control = ActiveRecord::QueryRecorder.new do
        get user_available_group_templates_path(user.username, group_id: group.id)
      end

      create(:project, group: template_subgroup)

      expect do
        get user_available_group_templates_path(user.username, group_id: group.id)
      end.not_to exceed_query_limit(control)
    end

    context 'when paginating' do
      let_it_be(:template_project2) { create(:project, group: template_subgroup) }

      before do
        allow(Kaminari.config).to receive(:default_per_page).and_return(1)
      end

      it 'shows the first page of the pagination' do
        get user_available_group_templates_path(user.username, group_id: group.id)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(template_project.name)
        expect(response.body).not_to include(template_project2.name)
      end
    end

    it 'returns no templates when group_id is not provided' do
      get user_available_group_templates_path(user.username)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).not_to include(template_project.name)
    end
  end
end
