# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Widget in Sidebar', :saas, :js, feature_category: :acquisition do
  include SubscriptionPortalHelpers
  include Features::TrialWidgetHelpers

  let_it_be(:user) { create(:user, :with_namespace, company: 'YMCA') }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:gitlab_subscription) do
    create(
      :gitlab_subscription,
      :ultimate_trial,
      namespace: group,
      start_date: Date.current,
      end_date: 60.days.from_now
    )
  end

  before do
    stub_saas_features(subscriptions_trials: true)
    sign_in(user)
  end

  it 'shows the correct days remaining on the first day of trial' do
    freeze_time do
      visit group_path(group)

      expect_widget_title_to_be('GitLab Ultimate Trial')
      expect_widget_to_have_content('60 days left in trial')
    end
  end

  it 'shows the correct trial type and days remaining' do
    travel_to(15.days.from_now) do
      visit group_path(group)
      expect(page).to have_content('Organize your work with projects and subgroups')

      expect_widget_title_to_be('GitLab Ultimate Trial')
      expect_widget_to_have_content('45 days left in trial')
    end

    travel_to(59.days.from_now) do
      visit group_path(group)

      expect_widget_title_to_be('GitLab Ultimate Trial')
      expect_widget_to_have_content('1 days left in trial')
    end
  end

  context 'when widget is expired' do
    let_it_be(:group_with_expired_trial) do
      create(
        :group_with_plan,
        plan: :free_plan,
        trial_starts_on: 31.days.ago,
        trial_ends_on: 1.day.ago,
        owners: user
      )
    end

    before do
      stub_billing_plans(group_with_expired_trial.id, 'free', [])
    end

    it 'shows upgrade after trial expiration' do
      freeze_time do
        visit group_path(group_with_expired_trial)

        expect_widget_title_to_be('Your trial of GitLab Ultimate has ended')
        expect_widget_to_have_content('Upgrade')
      end
    end

    it 'and allows dismissal on the first day after trial expiration' do
      freeze_time do
        visit group_path(group_with_expired_trial)

        expect_widget_title_to_be('Your trial of GitLab Ultimate has ended')
        expect_widget_to_have_content('Upgrade')

        dismiss_widget

        expect_widget_not_visible
        wait_for('callout dismissed') do
          Users::GroupCallout.where(
            user_id: user.id,
            group_id: group_with_expired_trial.id,
            feature_name: 'expired_trial_status_widget'
          ).exists?
        end

        page.refresh

        expect_widget_not_visible
      end
    end
  end
end
