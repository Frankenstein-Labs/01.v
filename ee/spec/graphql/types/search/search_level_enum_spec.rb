# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Search::SearchLevelEnum, feature_category: :global_search do
  it 'includes a value for each Search Level' do
    expect(described_class.values).to match(
      'PROJECT' => have_attributes(value: 'project'),
      'GROUP' => have_attributes(value: 'group'),
      'GLOBAL' => have_attributes(value: 'global')
    )
  end
end
