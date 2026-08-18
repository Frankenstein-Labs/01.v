# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/billings/index', :with_trial_types, :saas, :aggregate_failures, feature_category: :subscription_management do
  include RenderedHtml

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :free_plan) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:plans_data) { billing_plans_data.map { |plan| Hashie::Mash.new(plan) } }

  before do
    stub_signing_key
    allow(view).to receive(:current_user).and_return(user)
    assign(:group, group)
    assign(:plans_data, plans_data)
    assign(:monthly_commitment_purchased, 0)
  end

  context 'when the group is a subgroup' do
    let(:top_level_group) { build(:group) }

    before do
      assign(:top_level_group, top_level_group)
    end

    context 'for the unlimited members trial alert' do
      it 'does not set content_for :hide_explore_paid_plans_button' do
        render

        expect(view.content_for(:hide_explore_paid_plans_button).to_s).not_to eq('true')
      end
    end
  end

  context 'when the group is the top level' do
    context 'for the unlimited members trial alert' do
      it 'sets content_for :hide_explore_paid_plans_button to true' do
        render

        expect(view.content_for(:hide_explore_paid_plans_button).to_s).to eq('true')
      end
    end

    shared_examples 'without duo enterprise trial alert' do
      it 'does not render the component' do
        render

        expect(rendered).not_to have_css('[data-testid="duo-enterprise-trial-alert"]')
      end
    end

    shared_examples 'with duo enterprise trial alert' do
      it 'renders the component' do
        render

        expect(rendered).to have_css('[data-testid="duo-enterprise-trial-alert"]')
      end
    end

    context 'with free plan' do
      it 'renders the dap monthly credit billing page' do
        render

        expect(rendered).to have_selector('#js-free-trial-plan-billing-with-dap-monthly-commit')
      end

      it 'renders the trusted by section with company logos' do
        render

        expect(rendered).to have_text('Trusted by')

        expect(rendered).to have_css('img[alt="T-Mobile"][title="T-Mobile"]')
        expect(rendered).to have_css('img[alt="Goldman Sachs"][title="Goldman Sachs"]')
        expect(rendered).to have_css('img[alt="Airbus"][title="Airbus"]')
        expect(rendered).to have_css('img[alt="Lockheed Martin"][title="Lockheed Martin"]')
        expect(rendered).to have_css('img[alt="Carfax"][title="Carfax"]')
        expect(rendered).to have_css('img[alt="NVIDIA"][title="NVIDIA"]')
        expect(rendered).to have_css('img[alt="UBS"][title="UBS"]')
      end

      it 'applies correct CSS classes for dark mode support' do
        render

        ["T-Mobile", "Goldman Sachs", "Airbus", "Lockheed Martin", "NVIDIA", "UBS"].each do |name|
          expect(rendered).to have_css("img[alt='#{name}'].dark\\:gl-invert")
        end

        expect(rendered).to have_css('img[alt="Carfax"]')
        expect(rendered).not_to have_css('img[alt="Carfax"].dark\\:gl-invert')
      end

      it 'has tracking items set as expected' do
        render

        expect(rendered).to have_tracking(action: 'render', label: 'free')
      end
    end

    context 'with a trial plan' do
      let_it_be(:group) { create(:group) }
      let_it_be(:subscription) do
        create(:gitlab_subscription, :active_trial, namespace: group, hosted_plan: create(:ultimate_trial_plan))
      end

      it 'has tracking items set as expected' do
        render

        expect(rendered).to have_tracking(action: 'render', label: 'trial')
      end
    end

    context 'with a paid plan' do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }

      it 'renders the billing plans' do
        render

        expect(rendered).to render_template('_top_level_billing_plan_header')
        expect(rendered).to render_template('shared/billings/_billing_plans')
        expect(rendered).to have_selector('#js-billing-plans')
      end

      it 'has tracking items set as expected' do
        render

        expect(rendered).to have_tracking(action: 'render', label: 'paid')
      end

      it_behaves_like 'with duo enterprise trial alert'
    end

    context 'when purchasing a plan' do
      before do
        allow(view).to receive(:params).and_return(purchased_quantity: quantity)
        allow(view).to receive(:plan_title).and_return('Bronze')
      end

      let(:quantity) { '1' }

      it 'tracks purchase banner', :snowplow do
        render

        expect_snowplow_event(
          category: 'groups:billings',
          action: 'render',
          label: 'purchase_confirmation_alert_displayed',
          namespace: group,
          user: user
        )
      end

      context 'with a single user' do
        it 'displays the correct notification for 1 user' do
          render

          expect(rendered).to have_text('You\'ve successfully purchased the Bronze plan subscription for 1 user and ' \
                                    'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
                                    'refresh the page if your subscription details haven\'t displayed yet.')
        end
      end

      context 'with multiple users' do
        let(:quantity) { '2' }

        it 'displays the correct notification for 2 users' do
          render

          expect(rendered).to have_text('You\'ve successfully purchased the Bronze plan subscription for 2 users and ' \
                                    'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
                                    'refresh the page if your subscription details haven\'t displayed yet.')
        end
      end
    end
  end
end
