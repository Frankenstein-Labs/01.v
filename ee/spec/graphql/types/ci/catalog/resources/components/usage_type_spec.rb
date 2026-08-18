# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::Catalog::Resources::Components::UsageType, feature_category: :continuous_integration do
  it 'has the expected fields' do
    expected_fields = [:name, :version, :last_used_date]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
