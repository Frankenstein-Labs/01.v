# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuo::ModelSelectionController, type: :request, feature_category: :ai_abstraction_layer do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:developer) { create(:user) }

  let(:group_param) { group }

  subject(:get_index) { get group_settings_gitlab_duo_model_selection_index_path(group_param) }

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
    sign_in(owner)
  end

  before_all do
    group.add_owner(owner)
    group.add_developer(developer)
    group.namespace_settings.update!(duo_features_enabled: true)
  end

  describe 'GET index' do
    shared_examples 'returns not found' do
      it 'renders 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the instance is not SAAS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it_behaves_like 'returns not found'
    end

    context 'when the group is not a root level group' do
      let(:group_param) { sub_group }

      it_behaves_like 'returns not found'
    end

    context 'when the user is not a group owner' do
      before do
        sign_in(developer)
      end

      it_behaves_like 'returns not found'
    end

    context 'when the group does not have duo features enabled' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false)
      end

      it_behaves_like 'returns not found'
    end

    context 'when the instance is SAAS' do
      context 'when the group is a root level group' do
        context 'when the user is a group owner' do
          context 'when the group has duo features enabled', :saas_gitlab_com_subscriptions do
            before do
              create(:gitlab_subscription, :ultimate, namespace: group)
            end

            it 'renders the index page' do
              get_index

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to render_template(:index)
            end
          end
        end
      end
    end
  end
end
