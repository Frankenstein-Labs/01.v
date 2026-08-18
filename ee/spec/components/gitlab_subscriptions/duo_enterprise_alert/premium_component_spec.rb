# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoEnterpriseAlert::PremiumComponent, :saas_gitlab_com_subscriptions, :aggregate_failures, feature_category: :acquisition do
  let(:namespace) { build(:group, id: non_existing_record_id) }
  let(:user) { build(:user) }
  let(:eligible) { true }
  let(:new_title) { 'Get the most out of GitLab with Ultimate' }
  let(:old_title) { 'Get the most out of GitLab with Ultimate and GitLab Duo Enterprise' }

  subject(:component) do
    render_inline(described_class.new(namespace: namespace, user: user)) && page
  end

  before do
    build(:gitlab_subscription, :premium, namespace: namespace)
    allow(GitlabSubscriptions::Trials).to receive(:namespace_eligible?).with(namespace).and_return(eligible)
  end

  shared_examples 'has the body text' do
    it 'has the new text' do
      is_expected.to have_content(new_title)

      is_expected.to have_content(
        'Start an Ultimate trial and try out the full product offering from GitLab, including AI-native features.'
      )
    end
  end

  shared_examples 'has the primary action' do
    it 'has the action' do
      expected_link = new_trial_path(namespace_id: namespace.id)

      is_expected.to have_link('Start free trial', href: expected_link)

      expect(component.find(:link, href: expected_link))
        .to trigger_internal_events('click_duo_enterprise_trial_billing_page').on_click
        .with(additional_properties: { label: 'ultimate_and_duo_enterprise_trial' })
    end
  end

  context 'when gold plan' do
    before do
      build(:gitlab_subscription, :gold, namespace: namespace)
    end

    it { is_expected.not_to have_content(old_title) }
  end

  context 'when is not eligible' do
    let(:eligible) { false }

    it { is_expected.not_to have_content(old_title) }
  end

  it_behaves_like 'has the body text'
  it_behaves_like 'has the primary action'
end
