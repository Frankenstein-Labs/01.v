# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PolicyActor, feature_category: :shared do
  let(:policy_actor_test_class) do
    Class.new do
      include PolicyActor
    end
  end

  before do
    stub_const('PolicyActorTestClass', policy_actor_test_class)
  end

  describe '#security_policy_bot?' do
    subject { PolicyActorTestClass.new.security_policy_bot? }

    it { is_expected.to be(false) }
  end
end
