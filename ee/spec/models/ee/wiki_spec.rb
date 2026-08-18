# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wiki, feature_category: :wiki do
  describe '#use_separate_indices?', :elastic do
    it 'returns true' do
      expect(described_class.use_separate_indices?).to be true
    end
  end

  describe '#base_class' do
    it 'returns Wiki' do
      expect(described_class.base_class).to eq described_class
    end
  end
end
