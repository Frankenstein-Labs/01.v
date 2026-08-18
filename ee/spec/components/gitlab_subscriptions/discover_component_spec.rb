# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DiscoverComponent, :aggregate_failures, :saas, feature_category: :onboarding do
  let(:gitlab_subscription) do
    build_stubbed(:gitlab_subscription, :active_trial,
      trial_starts_on: Date.current - 20.days,
      trial_ends_on: Date.current + 10.days
    )
  end

  let(:namespace) { build_stubbed(:namespace, gitlab_subscription: gitlab_subscription) }

  let(:premium_plan) do
    Hashie::Mash.new(
      code: ::Plan::PREMIUM,
      id: 1,
      name: 'Premium'
    )
  end

  let(:plans_data) { [premium_plan] }
  let(:monthly_commitment_purchased) { 0 }

  before do
    allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
      allow(service).to receive(:execute).and_return(plans_data)
    end

    allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |service|
      allow(service).to receive(:execute)
        .and_return(ServiceResponse.success(payload: { total_credits: monthly_commitment_purchased }))
    end
  end

  it 'displays the main heading' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_content(s_('BillingPlans|Keep building with GitLab.'))
  end

  it 'displays the trial days remaining message' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_content(
      format(s_('BillingPlans|Your trial has %{days} days left.'), days: 10)
    )
  end

  it 'displays the tagline' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_content(
      s_('BillingPlans|Explore how GitLab Premium and GitLab Duo Agent Platform can help you ship faster.')
    )
  end

  it 'renders the expert contact component' do
    render_inline(described_class.new(namespace: namespace))
    expect(page).to have_selector('#js-premium-features-section')
  end

  describe 'trial days remaining display' do
    context 'when trial is not active' do
      before do
        allow(namespace).to receive(:trial_active?).and_return(false)
      end

      it 'displays 0 days remaining' do
        render_inline(described_class.new(namespace: namespace))
        expect(page).to have_content(
          format(s_('BillingPlans|Your trial has %{days} days left.'), days: 0)
        )
      end
    end

    context 'when trial is active' do
      it 'displays the correct number of days remaining' do
        render_inline(described_class.new(namespace: namespace))
        expect(page).to have_content(
          format(s_('BillingPlans|Your trial has %{days} days left.'), days: 10)
        )
      end
    end
  end

  describe 'DAP credits card data' do
    it 'passes data attributes on premium features section' do
      render_inline(described_class.new(namespace: namespace))
      element = page.find('#js-premium-features-section')
      data = Gitlab::Json.safe_parse(element['data-provide'])

      expect(data['purchaseCreditsPath']).to be_present
      expect(data['creditsDashboardPath']).to be_present
      expect(data['hasMonthlyCommit']).to be(false)
    end

    context 'when monthly commitment is purchased' do
      let(:monthly_commitment_purchased) { 100 }

      it 'passes the correct monthly commitment value' do
        render_inline(described_class.new(namespace: namespace))
        element = page.find('#js-premium-features-section')
        data = Gitlab::Json.safe_parse(element['data-provide'])

        expect(data['hasMonthlyCommit']).to be(true)
      end
    end

    context 'when credits_generalization_ui is enabled' do
      it 'passes creditsGeneralizationUi as true' do
        render_inline(described_class.new(namespace: namespace))
        element = page.find('#js-premium-features-section')
        data = Gitlab::Json.safe_parse(element['data-provide'])

        expect(data['creditsGeneralizationUi']).to be(true)
      end
    end

    context 'when credits_generalization_ui is disabled' do
      before do
        stub_feature_flags(credits_generalization_ui: false)
      end

      it 'passes creditsGeneralizationUi as false' do
        render_inline(described_class.new(namespace: namespace))
        element = page.find('#js-premium-features-section')
        data = Gitlab::Json.safe_parse(element['data-provide'])

        expect(data['creditsGeneralizationUi']).to be(false)
      end
    end

    context 'when FetchMonthlyCommitmentService raises an error' do
      let(:error) { StandardError.new('service unavailable') }

      before do
        allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |service|
          allow(service).to receive(:execute).and_raise(error)
        end
      end

      it 'falls back to hasMonthlyCommit false and tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error)

        render_inline(described_class.new(namespace: namespace))
        element = page.find('#js-premium-features-section')
        data = Gitlab::Json.safe_parse(element['data-provide'])

        expect(data['hasMonthlyCommit']).to be(false)
      end
    end
  end

  describe 'action buttons' do
    before do
      render_inline(described_class.new(namespace: namespace))
    end

    it 'renders upgrade button with correct text' do
      expect(page).to have_content(_('Upgrade'))
    end

    it 'renders upgrade button with correct tracking attributes' do
      attributes = {
        testid: 'upgrade-button',
        action: 'click_cta',
        label: 'upgrade'
      }
      expect(page).to have_tracking(attributes)
    end

    it 'renders explore plans button with correct text' do
      expect(page).to have_content(s_('BillingPlans|Explore plans'))
    end

    it 'renders explore plans button with correct tracking attributes' do
      attributes = {
        testid: 'explore-plans-button',
        action: 'click_cta',
        label: 'explore_paid_plans'
      }
      expect(page).to have_tracking(attributes)
    end
  end
end
