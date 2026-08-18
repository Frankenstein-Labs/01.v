# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Profiles > Billing', :js, feature_category: :subscription_management do
  include StubRequests
  include SubscriptionPortalHelpers

  let_it_be_with_reload(:namespace) { create(:namespace) }
  let_it_be_with_reload(:user) { create(:user, namespace: namespace) }

  def formatted_date(date)
    date.strftime("%B %-d, %Y")
  end

  def subscription_table
    '.subscription-table'
  end

  before do
    allow(Gitlab).to receive(:com?).and_return(true)
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)
    stub_subscription_management_data(namespace.id)
    allow_next_instance_of(Namespaces::TrialEligibleFinder) do |instance|
      allow(instance).to receive(:execute).and_return([])
    end

    sign_in(user)
  end

  context 'when CustomersDot is available' do
    let(:plan) { 'free' }

    before do
      stub_billing_plans(user.namespace.id, plan)
    end

    context 'with a free plan' do
      let!(:subscription) do
        create(:gitlab_subscription, namespace: user.namespace, hosted_plan: nil)
      end

      it 'displays the pricing information component' do
        visit profile_billings_path

        expect(page).to have_content('Billing')
        expect(page).to have_content('View subscription details and manage billing for your groups')
        expect(page).to have_selector('[data-testid="group-select"]')
      end

      it 'does not have search settings field' do
        visit profile_billings_path

        expect(page).not_to have_field(placeholder: SearchHelpers::INPUT_PLACEHOLDER)
      end

      context "without a group" do
        it 'displays empty state when no group is selected' do
          visit profile_billings_path

          expect(page).to have_selector('[data-testid="empty-state"]')
          expect(page).to have_content('To view subscription details and manage billing, select a group')
        end
      end

      context "with a maintained or owned group" do
        it 'displays group selection and pricing information' do
          group = create(:group)
          group.add_owner(user)

          stub_billing_plans(group.id, plan)

          visit profile_billings_path

          expect(page).to have_selector('[data-testid="group-select"]')
          expect(page).to have_content('View subscription details and manage billing')
        end
      end
    end
  end
end
