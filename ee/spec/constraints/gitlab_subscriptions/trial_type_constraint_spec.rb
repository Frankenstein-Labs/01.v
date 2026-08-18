# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialTypeConstraint, feature_category: :acquisition do
  subject(:constraint) { described_class.new }

  describe '#matches?' do
    subject { constraint.matches?(request) }

    let(:request) { instance_double(ActionDispatch::Request) }

    it 'returns true when saas', :saas_subscriptions_trials do
      is_expected.to be_truthy
    end

    it 'returns false when self managed' do
      is_expected.to be_falsey
    end
  end
end
