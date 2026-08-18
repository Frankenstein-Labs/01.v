# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Issuables::CustomFieldSelectOptionInputType, feature_category: :team_planning do
  it { expect(described_class.graphql_name).to eq('CustomFieldSelectOptionInput') }

  it { expect(described_class.arguments.keys).to contain_exactly('id', 'value') }
end
