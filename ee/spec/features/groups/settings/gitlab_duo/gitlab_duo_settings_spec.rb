# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group > Settings > GitLab Duo', :js, feature_category: :seat_cost_management do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, owners: user) }

  before do
    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive_messages(credits_available?: true, usage_billing_forbidden?: false)
    end
  end

  describe 'code suggestions usage' do
    let(:add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

    context 'when saas', :saas, :js do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
        stub_licensed_features(code_suggestions: true)
        sign_in(user)

        visit group_settings_gitlab_duo_path(group)
      end

      it 'renders Duo configuration info card',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449030' do
        expect(page).to have_content('GitLab Duo Pro')
        expect(page).to have_selector('[data-testid="duo-configuration-settings-info-card"]')
      end

      context 'when paid duo tier is available' do
        let(:add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

        it 'renders Duo seat utilization info card',
          quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449030' do
          expect(page).to have_content('Seat utilization')
          expect(page).to have_selector('[data-testid="duo-seat-utilization-info-card"]')
        end
      end

      context 'when only Duo Core is available' do
        let(:add_on) { create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group) }

        it 'does not render Duo seat utilization info card' do
          expect(page).not_to have_content('Seat utilization')
          expect(page).not_to have_selector('[data-testid="duo-seat-utilization-info-card"]')
        end
      end
    end

    context 'when self-managed', :js do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
        stub_saas_features(gitlab_com_subscriptions: false)
        sign_in(user)

        visit group_settings_gitlab_duo_path(group)
      end

      ## Group > Settings > GitLab Duo does not exist on self-managed
      it 'renders 404' do
        expect(page).to have_content '404: Page not found'
      end
    end
  end
end
