# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::GitlabDuo::GovernanceController, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  subject(:get_index) { get project_settings_gitlab_duo_governance_index_path(project) }

  before do
    stub_licensed_features(ai_features: true)
    group.namespace_settings.update!(duo_features_enabled: true)
    sign_in(user)
  end

  describe 'GET index' do
    before_all do
      group.add_owner(user)
    end

    context 'when licensed, flag enabled, and the user can read tool rules' do
      before do
        stub_feature_flags(gitlab_duo_governance_settings: true)
      end

      it 'renders index with 200 status code' do
        get_index

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('data-ai-audit-events-storage-enabled')
        expect(response.body).to include(group_settings_gitlab_duo_configuration_index_path(group))
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(gitlab_duo_governance_settings: false)
      end

      it 'renders 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when AI features are not licensed' do
      before do
        stub_licensed_features(ai_features: false)
        stub_feature_flags(gitlab_duo_governance_settings: true)
      end

      it 'renders 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user cannot read tool rules (not an owner)' do
      let_it_be(:maintainer) { create(:user) }

      before_all do
        project.add_maintainer(maintainer)
      end

      before do
        sign_in(maintainer)
        stub_feature_flags(gitlab_duo_governance_settings: true)
      end

      it 'renders 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the project belongs to a personal namespace' do
      let_it_be(:personal_project) { create(:project, :in_user_namespace) }

      before do
        sign_in(personal_project.first_owner)
        stub_feature_flags(gitlab_duo_governance_settings: true)
      end

      it 'renders 404' do
        get project_settings_gitlab_duo_governance_index_path(personal_project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
