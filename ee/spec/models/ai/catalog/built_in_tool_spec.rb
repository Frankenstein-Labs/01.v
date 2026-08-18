# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::BuiltInTool, feature_category: :workflow_catalog do
  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(ActiveRecord::FixedItemsModel::Model) }
    it { is_expected.to include(GlobalID::Identification) }
    it { is_expected.to include(Ai::Catalog::BuiltInToolDefinitions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:description) }
  end

  describe '.count' do
    it 'returns the correct count of tools' do
      expect(described_class.count).to eq(described_class::ITEMS.size)
    end
  end
end
