# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialsHelper, feature_category: :acquisition do
  using RSpec::Parameterized::TableSyntax
  include Devise::Test::ControllerHelpers

  describe '#show_tier_badge_for_new_trial?' do
    where(:trials_available?, :paid?, :private?, :eligible_for_trial?, :authorized, :result) do
      false | false | true | true | true | false
      true | true | true | true | true | false
      true | false | false | true | true | false
      true | false | true | false | true | false
      true | false | true | true | false | false
      true | false | true | true | true | true
    end

    with_them do
      let(:namespace) { build(:namespace) }
      let(:user) { build(:user) }

      before do
        stub_saas_features(subscriptions_trials: trials_available?)
        allow(namespace).to receive(:paid?).and_return(paid?)
        allow(namespace).to receive(:private?).and_return(private?)
        allow(namespace).to receive(:eligible_for_trial?).and_return(eligible_for_trial?)
        allow(helper).to receive(:can?).with(user, :read_billing, namespace).and_return(authorized)
      end

      subject { helper.show_tier_badge_for_new_trial?(namespace, user) }

      it { is_expected.to be(result) }
    end
  end

  describe '#glm_source' do
    let(:host) { ::Gitlab.config.gitlab.host }

    it 'return gitlab config host' do
      glm_source = helper.glm_source

      expect(glm_source).to eq(host)
    end
  end

  describe '#trial_duration', :with_trial_types do
    let(:trial_duration) { 30 }

    subject { helper.trial_duration }

    it { is_expected.to eq(trial_duration) }
  end
end
