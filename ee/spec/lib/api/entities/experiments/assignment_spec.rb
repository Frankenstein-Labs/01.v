# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Experiments::Assignment, feature_category: :acquisition do
  let(:assignment) do
    {
      experiment: 'null_hypothesis',
      variant: 'candidate',
      context_key: 'example_cache_key',
      cached: true
    }
  end

  subject(:entity) { described_class.new(assignment).as_json }

  it 'exposes the assignment fields' do
    expect(entity).to eq(
      experiment: 'null_hypothesis',
      variant: 'candidate',
      context_key: 'example_cache_key',
      cached: true
    )
  end
end
