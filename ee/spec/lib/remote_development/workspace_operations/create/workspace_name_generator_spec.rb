# frozen_string_literal: true

require 'fast_spec_helper'
require 'ffaker'

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::WorkspaceNameGenerator, feature_category: :workspaces do
  let(:fruit) { 'apple' }
  let(:animal) { 'dog' }
  let(:color) { 'blue' }
  let(:expected_name) { 'apple-dog-blue' }

  context 'when generated name is valid and unique' do
    before do
      allow(FFaker::Food).to receive(:fruit).and_return(fruit)
      allow(FFaker::AnimalUS).to receive(:common_name).and_return(animal)
      allow(FFaker::Color).to receive(:name).and_return(color)
      stub_const("RemoteDevelopment::Workspace", Class.new)
      allow(RemoteDevelopment::Workspace).to receive_message_chain(:by_names, :exists?).and_return(false)
    end

    it 'returns a workspace name combining fruit, animal, and color' do
      expect(described_class.generate).to eq(expected_name)
    end

    it 'converts names to lowercase' do
      allow(FFaker::Food).to receive(:fruit).and_return('APPLE')
      allow(FFaker::AnimalUS).to receive(:common_name).and_return('DOG')
      allow(FFaker::Color).to receive(:name).and_return('BLUE')

      expect(described_class.generate).to eq(expected_name)
    end

    it 'parameterizes names to remove spaces' do
      allow(FFaker::Food).to receive(:fruit).and_return('Apple')
      allow(FFaker::AnimalUS).to receive(:common_name).and_return('Golden Retriever')
      allow(FFaker::Color).to receive(:name).and_return('Sky Blue')

      expect(described_class.generate).to eq('apple-goldenretriever-skyblue')
    end
  end

  context 'when generated name already exists' do
    before do
      stub_const("RemoteDevelopment::Workspace", Class.new)
    end

    it 'retries until finding a unique name' do
      stub_const("RemoteDevelopment::Workspace", Class.new)
      allow(RemoteDevelopment::Workspace).to receive_message_chain(:by_names, :exists?)
        .and_return(true, true, false)

      expect(FFaker::Food).to receive(:fruit).exactly(3).times.and_return(fruit)
      expect(FFaker::AnimalUS).to receive(:common_name).exactly(3).times.and_return(animal)
      expect(FFaker::Color).to receive(:name).exactly(3).times.and_return(color)

      expect(described_class.generate).to eq(expected_name)
    end
  end

  context 'when generated name is too long' do
    let(:long_fruit) { 'a' * 20 }
    let(:long_animal) { 'b' * 20 }
    let(:long_color) { 'c' * 20 }

    before do
      allow(FFaker::Food).to receive(:fruit).and_return(long_fruit)
      allow(FFaker::AnimalUS).to receive(:common_name).and_return(long_animal)
      allow(FFaker::Color).to receive(:name).and_return(long_color)
      stub_const("RemoteDevelopment::Workspace", Class.new)
      allow(RemoteDevelopment::Workspace).to receive_message_chain(:by_names, :exists?).and_return(false)
    end

    it 'retries when name exceeds maximum length' do
      allow(SecureRandom).to receive(:alphanumeric).with(5).and_return('xyz12')

      result = described_class.generate

      expect(result).to end_with('xyz12')
      expect(result.length).to eq(described_class::WORKSPACE_NAME_MAX_LENGTH)
    end
  end

  context 'when max retries is reached' do
    before do
      allow(FFaker::Food).to receive(:fruit).and_return(fruit)
      allow(FFaker::AnimalUS).to receive(:common_name).and_return(animal)
      allow(FFaker::Color).to receive(:name).and_return(color)

      stub_const("RemoteDevelopment::Workspace", Class.new)
      allow(RemoteDevelopment::Workspace).to receive_message_chain(:by_names, :exists?).and_return(true)

      allow(SecureRandom).to receive(:alphanumeric).with(5).and_return('abc12')
    end

    it 'falls back to truncated name with random string' do
      result = described_class.generate

      expect(result).to end_with('abc12')
    end

    it 'truncates the original name to make room for random string' do
      long_name = 'a' * 40
      allow(FFaker::Food).to receive(:fruit).and_return(long_name)
      allow(FFaker::AnimalUS).to receive(:common_name).and_return('')
      allow(FFaker::Color).to receive(:name).and_return('')

      result = described_class.generate
      expected_truncated_length = described_class::WORKSPACE_NAME_MAX_LENGTH - 1 -
        described_class::RANDOM_STRING_LENGTH

      expect(result[0...expected_truncated_length])
        .to eq(long_name.parameterize(separator: "")[0...expected_truncated_length])
      expect(result).to end_with('abc12')
    end
  end

  describe 'constants' do
    it 'has correct RANDOM_STRING_LENGTH' do
      expect(described_class::RANDOM_STRING_LENGTH).to eq(5)
    end

    it 'has correct WORKSPACE_NAME_MAX_LENGTH' do
      expect(described_class::WORKSPACE_NAME_MAX_LENGTH).to eq(34)
    end
  end
end
