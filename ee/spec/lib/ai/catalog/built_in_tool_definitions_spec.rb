# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::BuiltInToolDefinitions, feature_category: :workflow_catalog do
  let(:dummy_class) do
    Class.new do
      include Ai::Catalog::BuiltInToolDefinitions
    end
  end

  describe 'module inclusion' do
    it 'extends ActiveSupport::Concern' do
      expect(described_class).to be_a(ActiveSupport::Concern)
    end

    it 'can be included in other classes' do
      expect { dummy_class.new }.not_to raise_error
    end
  end

  describe 'ITEMS constant' do
    let(:items) { described_class::ITEMS }

    it 'is an array' do
      expect(items).to be_an(Array)
    end

    it 'is not empty' do
      expect(items).not_to be_empty
    end

    describe 'item structure' do
      it 'has required keys for each item' do
        expect(items).to all(include(:id, :name, :title, :description))
      end

      it 'has unique IDs' do
        ids = items.pluck(:id)
        expect(ids.uniq.size).to eq(ids.size)
      end

      it 'has unique names' do
        names = items.pluck(:name)
        expect(names.uniq.size).to eq(names.size)
      end

      it 'has sequential IDs starting from 1' do
        ids = items.pluck(:id).sort
        expect(ids).to eq((1..items.size).to_a)
      end
    end

    describe 'data validation' do
      it 'has non-empty strings for all required fields' do
        items.each do |item|
          expect(item[:id]).to be_a(Integer).and be_present
          expect(item[:name]).to be_a(String).and be_present
          expect(item[:title]).to be_a(String).and be_present
          expect(item[:description]).to be_a(String).and be_present
        end
      end

      it 'has positive integer IDs' do
        items.each do |item|
          expect(item[:id]).to be_a(Integer).and be_positive
        end
      end
    end
  end
end
