# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::AutomaticTrialRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.product_interaction' do
    subject { described_class.product_interaction }

    it { is_expected.to eq('SaaS Trial - defaulted') }
  end

  describe '.show_company_form_footer?' do
    subject { described_class.show_company_form_footer? }

    it { is_expected.to be(true) }
  end

  describe '.show_company_form_side_column?' do
    it { is_expected.to be_show_company_form_side_column }
  end

  describe '.identity_verification_panel_image' do
    subject { described_class.identity_verification_panel_image }

    it { is_expected.to eq('subscription/pipeline') }
  end

  describe '.identity_verification_panel_heading' do
    subject { described_class.identity_verification_panel_heading }

    it { is_expected.to eq(s_('InProductMarketing|Ship software faster')) }
  end
end
