# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggerPolicy, feature_category: :duo_agent_platform do
  let_it_be(:trigger) { create(:ai_flow_trigger) }

  subject(:policy) { described_class.new(nil, trigger) }

  it 'delegates to ProjectPolicy' do
    delegations = policy.delegated_policies

    expect(delegations.values[0]).to match(an_instance_of(::ProjectPolicy))
  end
end
