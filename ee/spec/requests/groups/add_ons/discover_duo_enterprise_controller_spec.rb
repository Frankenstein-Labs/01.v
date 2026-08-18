# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AddOns::DiscoverDuoEnterpriseController, :saas, feature_category: :onboarding do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  describe 'GET show' do
    subject(:get_show) { get group_add_ons_discover_duo_enterprise_path(group) }

    context 'when group does not have an active duo trial' do
      it 'renders not found' do
        group.add_developer(user)
        sign_in(user)

        get_show

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when group has an active duo trial' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial, namespace: group)
      end

      context 'when user can not admin group' do
        it 'renders not found' do
          group.add_developer(user)
          sign_in(user)

          get_show

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when user can admin group' do
        it 'renders ok' do
          group.add_owner(user)
          sign_in(user)

          get_show

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end
end
