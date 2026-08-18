# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::FormErrorsComponent, :aggregate_failures, feature_category: :acquisition do
  let(:errors) { ['First error', 'Second error'] }
  let(:reason) { :generic_trial_error }

  subject { render_inline(described_class.new(errors: errors, reason: reason)) && page }

  it { is_expected.to have_content(_("We're sorry, your trial could not be created")) }
  it { is_expected.to have_link('GitLab Support', href: Gitlab::Saas.customer_support_url) }

  it 'displays the error message and a support message' do
    is_expected.to have_content("Please reach out to GitLab Support for assistance: First error and Second error.")
  end

  context 'without specific errors' do
    let(:errors) { [] }

    it 'displays only a support message' do
      is_expected.to have_content("Please reach out to GitLab Support for assistance.")
    end
  end

  context 'when reason is not generic' do
    let(:errors) { ['First error', 'Second error'] }
    let(:reason) { nil }

    it { is_expected.to have_content(_("We're sorry, your trial could not be created")) }
    it { is_expected.not_to have_link('GitLab Support') }

    it 'displays the error message only' do
      is_expected.to have_content('First error and Second error')
    end
  end
end
