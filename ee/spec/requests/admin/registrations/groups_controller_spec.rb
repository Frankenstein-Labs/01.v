# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Registrations::GroupsController, feature_category: :onboarding do
  let_it_be(:admin) { create(:admin) }

  describe 'GET /admin/registrations/groups/new' do
    subject(:get_new) { get new_admin_registrations_group_path }

    context 'when on SaaS' do
      before do
        stub_saas_features(subscriptions_trials: true)
        sign_in(admin)
      end

      it 'returns not found', :enable_admin_mode do
        get_new

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when not on SaaS' do
      before do
        stub_saas_features(subscriptions_trials: false)
        sign_in(admin)
      end

      it 'returns ok', :enable_admin_mode do
        get_new

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
