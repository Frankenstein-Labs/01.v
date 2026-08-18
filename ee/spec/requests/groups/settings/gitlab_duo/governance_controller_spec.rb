# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuo::GovernanceController, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  subject(:get_index) { get group_settings_gitlab_duo_governance_index_path(group) }

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
      it "renders index with 200 status code", :aggregate_failures do
        get_index

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('data-ai-audit-events-storage-enabled')
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
      end

      it 'renders 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user cannot read tool rules (not an owner)' do
      let_it_be(:reporter) { create(:user) }

      before_all do
        group.add_reporter(reporter)
      end

      before do
        sign_in(reporter)
      end

      it 'renders 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the group is a subgroup' do
      let_it_be_with_reload(:subgroup) { create(:group, parent: group) }

      subject(:get_index) { get group_settings_gitlab_duo_governance_index_path(subgroup) }

      before do
        subgroup.namespace_settings.update!(duo_features_enabled: true)
      end

      it 'renders 404, since the tool-rules GraphQL surface only resolves root namespaces' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
