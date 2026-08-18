# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::Widgets::VerificationStatusInputType, feature_category: :requirements_management do
  it { expect(described_class.graphql_name).to eq('VerificationStatusInput') }

  it { expect(described_class.arguments.keys).to match_array(%w[verificationStatus]) }
end
