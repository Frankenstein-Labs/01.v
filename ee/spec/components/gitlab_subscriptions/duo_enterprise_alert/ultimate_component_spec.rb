# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoEnterpriseAlert::UltimateComponent, :with_trial_types, :saas_gitlab_com_subscriptions, :aggregate_failures, feature_category: :acquisition do
  let(:namespace) { build(:group, id: non_existing_record_id) }
  let(:user) { build(:user) }
  let(:title) { 'Introducing GitLab Duo Enterprise' }

  subject(:component) do
    render_inline(described_class.new(namespace: namespace, user: user)) && page
  end

  before do
    build(:gitlab_subscription, :ultimate, namespace: namespace)
  end

  context 'when gold plan' do
    before do
      build(:gitlab_subscription, :gold, namespace: namespace)
    end

    it { is_expected.not_to have_content(title) }
  end

  context 'when there is Duo Enterprise add-on' do
    before do
      allow(GitlabSubscriptions::DuoEnterprise)
        .to receive(:no_add_on_purchase_for_namespace?)
        .with(namespace)
        .and_return(false)
    end

    it { is_expected.not_to have_content(title) }
  end

  context 'when rendering' do
    it 'has the correct text' do
      is_expected.to have_content(title)

      is_expected.to have_content(
        'Start a GitLab Duo Enterprise trial to try all end-to-end AI ' \
          'capabilities from GitLab. You can try it for free for 60 days, ' \
          'no credit card required.'
      )
    end

    it 'has the primary action' do
      expected_link = new_trials_duo_enterprise_path(namespace_id: namespace.id)

      is_expected.to have_link(
        'Start a free GitLab Duo Enterprise Trial',
        href: expected_link
      )

      expect(component.find(:link, href: expected_link))
        .to trigger_internal_events('click_duo_enterprise_trial_billing_page').on_click
        .with(additional_properties: { label: 'duo_enterprise_trial' })
    end

    it 'has the hand raise lead selector' do
      is_expected.to have_selector('.js-hand-raise-lead-trigger')
    end
  end
end
