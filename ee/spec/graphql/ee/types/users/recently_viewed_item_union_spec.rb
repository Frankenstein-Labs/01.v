# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Users::RecentlyViewedItemUnion, feature_category: :notifications do
  it 'includes Epic type in EE' do
    expect(described_class.possible_types).to include(Types::EpicType)
  end

  it 'resolves Epic to EpicType' do
    expect(described_class.resolve_type(build(:epic), {})).to eq(Types::EpicType)
  end
end
