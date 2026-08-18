# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Get started concerns', :js, :saas, :aggregate_failures, feature_category: :onboarding do
  include Features::InviteMembersModalHelpers
  include SubscriptionPortalHelpers

  context 'for Getting started page' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    context 'for overall rendering' do
      before_all do
        create(:onboarding_progress, namespace: namespace)
      end

      it 'renders sections correctly' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        within_testid('get-started-sections') do
          expect(page).to have_content('Quick start')
          expect(page).to have_content('Follow these steps to get familiar with the GitLab workflow.')
          expect(page).to have_content('Set up your code')
          expect(page).to have_content('Configure a project')
          expect(page).to have_content('Plan and execute work together')
          expect(page).to have_content('Secure your deployment')
        end
      end

      it 'invites a user and completes the invite action' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        find_by_testid('section-header-1').click

        user_name_to_invite = create(:user).name

        within_testid('get-started-sections') do
          find_link('Invite your colleagues').click
        end

        stub_signing_key
        stub_reconciliation_request(true)
        stub_subscription_request_seat_usage(false)

        invite_with_opened_modal(user_name_to_invite)

        within_testid('get-started-page') do
          expect(page).to have_content('Your team is growing')
        end
      end

      it 'does not have the seat assignment link' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        find_by_testid('section-header-1').click

        within_testid('get-started-sections') do
          expect(page).not_to have_content('Assign a GitLab Duo seat')
        end
      end
    end
  end
end
