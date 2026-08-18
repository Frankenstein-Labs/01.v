# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::InInstanceSelfManagedTrialActivationConstraint, feature_category: :acquisition do
  subject(:constraint) { described_class.new }

  describe '#matches?' do
    subject { constraint.matches?(request) }

    let(:request) { instance_double(ActionDispatch::Request) }

    it 'returns true when the feature flag is enabled' do
      stub_feature_flags(in_instance_self_managed_trial_activation: true)

      is_expected.to be_truthy
    end

    it 'returns false when the feature flag is disabled' do
      stub_feature_flags(in_instance_self_managed_trial_activation: false)

      is_expected.to be_falsey
    end
  end
end
