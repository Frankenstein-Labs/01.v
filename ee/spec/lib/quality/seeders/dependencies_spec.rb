# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Quality::Seeders::Dependencies, feature_category: :dependency_management do
  let_it_be(:admin) { create(:admin) }

  subject(:seed) { described_class.new }

  it 'creates a new group' do
    expect { seed }.to change { Group.count }.by(1)
  end

  describe '#seed!' do
    it 'creates expected number of dependencies' do
      expected_value = described_class::UNIQUE_COMPONENT_COUNT * described_class::PROJECT_COUNT * 2

      expect { seed.seed! }.to change { Sbom::Occurrence.count }.by(expected_value)
    end
  end
end
