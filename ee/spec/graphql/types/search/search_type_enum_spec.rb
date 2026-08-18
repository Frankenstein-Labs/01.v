# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Search::SearchTypeEnum, feature_category: :global_search do
  it 'includes a value for each Search Type' do
    expect(described_class.values).to match(
      'BASIC' => have_attributes(value: 'basic'),
      'ADVANCED' => have_attributes(value: 'advanced'),
      'ZOEKT' => have_attributes(value: 'zoekt')
    )
  end
end
