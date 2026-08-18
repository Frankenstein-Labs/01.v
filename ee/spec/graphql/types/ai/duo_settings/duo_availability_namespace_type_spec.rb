# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AdminDuoAvailabilityNamespace'], feature_category: :ai_abstraction_layer do
  it { expect(described_class.graphql_name).to eq('AdminDuoAvailabilityNamespace') }

  it 'exposes the expected fields' do
    expected_fields = %w[id name fullPath duoAvailability inheritedValue adminLocked lockedByAncestor]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
