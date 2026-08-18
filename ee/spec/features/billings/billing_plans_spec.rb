# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Billing plan pages', :with_trial_types, :feature, :saas, :js, feature_category: :subscription_management do
  include Features::HandRaiseLeadHelpers
  include Features::BillingPlansHelpers

  let(:user) { create(:user, first_name: 'James', last_name: 'Bond', company: 'ACME') }
  let(:current_organization) { user.organization }
  let(:auditor) { create(:auditor, first_name: 'James', last_name: 'Bond', company: 'ACME') }
  let(:free_plan) { create(:free_plan) }
  let(:bronze_plan) { create(:bronze_plan) }
  let(:premium_plan) { create(:premium_plan) }
  let(:ultimate_plan) { create(:ultimate_plan) }

  let(:plans_data) { billing_plans_data }

  before do
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)
    sign_in(user)
  end

  shared_examples 'does not display the billing plans' do
    it 'does not display the plans' do
      expect(page).not_to have_selector("[data-testid='billing-plans']")
    end
  end

  shared_examples 'subscription table with management buttons' do
    before do
      visit page_path
    end

    it 'displays subscription table' do
      expect(page).to have_link('Add seats')
      expect(page).to have_link('Manage')
      expect(page).to have_link('Renew')
    end
  end

  shared_examples 'subscription table without management buttons' do
    before do
      visit page_path
    end

    it 'displays subscription table' do
      expect(page).not_to have_link('Manage')
      expect(page).not_to have_link('Add seats')
      expect(page).not_to have_link('Renew')
    end
  end

  shared_examples 'plan with subscription table' do
    before do
      visit page_path
    end

    it 'displays subscription table' do
      expect(page).to have_selector('.js-subscription-table')
    end
  end

  context 'users profile billing page' do
    let(:page_path) { profile_billings_path }

    context 'with no owned groups' do
      let(:plan) { free_plan }
      let(:namespace) { user.namespace }

      before do
        stub_billing_plans(nil)
        stub_billing_plans(namespace.id, plan.name, plans_data.to_json)
        stub_subscription_management_data(namespace.id)
        stub_temporary_extension_data(namespace.id)
        visit page_path
      end

      it 'displays empty state when user has no owned groups' do
        expect(page).to have_content('Billing')
        expect(page).to have_content('View subscription details and manage billing for your groups')
        expect(page).to have_selector('[data-testid="group-select"]')
        expect(page).to have_selector('[data-testid="empty-state"]')
        expect(page).to have_content('To view subscription details and manage billing, select a group')
        expect(page).to have_link('group', href: dashboard_groups_path)
      end

      it_behaves_like 'does not display the billing plans'
    end

    context 'when CustomersDot is unavailable' do
      let(:plan) { ultimate_plan }
      let(:namespace) { user.namespace }
      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan) }

      before do
        stub_billing_plans(namespace.id, plan.name, raise_error: 'Connection refused')
      end

      it 'renders an error page' do
        visit page_path

        expect(page).to have_content("Subscription service outage")
      end
    end
  end

  context 'group billing page' do
    let(:namespace) { create(:group) }
    let!(:project) { create(:project, group: namespace) }

    before do
      namespace.add_owner(user)
      # post_create_member_hook creates a subscription due to a license check.
      # We delete it here so that subscription creation in the tests below do not violate the unique constraint
      namespace.gitlab_subscription.destroy!
      stub_billing_plans(nil)
      stub_billing_plans(namespace.id, plan.name, plans_data.to_json)
      stub_subscription_management_data(namespace.id)
      stub_temporary_extension_data(namespace.id)
    end

    context 'when a group is the top-level group' do
      let(:page_path) { group_billings_path(namespace) }

      context 'on ultimate' do
        let(:plan) { ultimate_plan }

        let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

        it 'displays plan header' do
          visit page_path

          within('.billing-plan-header') do
            expect(page).to have_content("#{namespace.name} is currently using the Ultimate Plan")

            expect(page).to have_css('.billing-plan-logo .gl-avatar-identicon')
          end
        end

        it_behaves_like 'does not display the billing plans'
        it_behaves_like 'plan with subscription table'
        it_behaves_like 'subscription table with management buttons'
      end

      context 'on bronze' do
        let(:plan) { bronze_plan }

        let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

        before do
          visit page_path
        end

        it 'displays plan header' do
          within('.billing-plan-header') do
            expect(page).to have_content("#{namespace.name} is currently using the Bronze Plan")

            expect(page).to have_css('.billing-plan-logo .gl-avatar-identicon')
          end
        end

        it 'does display the billing plans table' do
          expect(page).to have_selector("[data-testid='billing-plans']")
        end

        context 'when submitting hand raise lead' do
          it 'displays the in-app hand raise lead' do
            within_testid('plan-card-premium') do
              click_button 'Contact sales'
            end

            expect_fill_in_and_submit_hand_raise_lead(user, namespace, glm_content: 'billing-group')
          end
        end

        it_behaves_like 'plan with subscription table'
      end

      context 'on free' do
        let(:plan) { free_plan }

        before do
          stub_subscription_monthly_commitment_request
        end

        it 'submits hand raise lead form' do
          visit page_path

          click_button 'Talk to an expert'

          expect_fill_in_and_submit_hand_raise_lead(user, namespace, glm_content: 'billing-group')
        end
      end

      context 'with auditor user' do
        let(:plan) { ultimate_plan }
        let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

        before do
          stub_licensed_features(auditor_user: true)

          sign_in(auditor)
        end

        it_behaves_like 'does not display the billing plans'
        it_behaves_like 'plan with subscription table'
        it_behaves_like 'subscription table without management buttons'
      end
    end

    context 'when a group is the subgroup' do
      let(:namespace) { create(:group_with_plan) }
      let(:plan) { namespace.actual_plan }
      let(:subgroup) { create(:group, parent: namespace) }

      before do
        stub_billing_plans(nil)
        stub_billing_plans(namespace.id, plan.name, plans_data.to_json)
        stub_subscription_management_data(namespace.id)
        stub_temporary_extension_data(namespace.id)
      end

      it 'shows the subgroup page context for billing', :aggregate_failures do
        visit group_billings_path(subgroup)

        expect(page).to have_text('is currently using the')
        expect(page).to have_text('This group uses the plan associated with its parent group')
        expect(page).to have_link('Manage plan')
        expect(page).not_to have_selector("[data-testid='billing-plans']")
      end
    end

    context 'seat refresh button' do
      let_it_be(:developer) { create(:user) }
      let_it_be(:guest) { create(:user) }

      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 1) }

      let(:plan) { ultimate_plan }

      before do
        namespace.add_developer(developer)
        namespace.add_guest(guest)

        visit group_billings_path(namespace)
      end

      it 'updates seat counts on click' do
        expect(seats_in_subscription).to eq '1'
        expect(seats_currently_in_use).to eq '0'
        expect(max_seats_used).to eq '0'
        expect(seats_owed).to eq '0'

        click_button 'Refresh Seats'
        wait_for_requests

        expect(seats_in_subscription).to eq '1'
        expect(seats_currently_in_use).to eq '2'
        expect(max_seats_used).to eq '2'
        expect(seats_owed).to eq '1'
      end

      def seats_in_subscription
        find_by_testid('seats-in-subscription').text
      end

      def seats_currently_in_use
        find_by_testid('seats-currently-in-use').text
      end

      def max_seats_used
        find_by_testid('max-seats-used').text
      end

      def seats_owed
        find_by_testid('seats-owed').text
      end
    end
  end
end
