# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Notifications::TargetedMessageType, feature_category: :acquisition do
  it 'has the expected fields' do
    expected_fields = %w[id target_type roles]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  specify { expect(described_class).to require_graphql_authorizations(:read_namespace) }
end
