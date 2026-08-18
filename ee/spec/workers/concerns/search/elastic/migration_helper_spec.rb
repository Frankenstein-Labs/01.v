# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MigrationHelper, feature_category: :global_search do
  let(:index_name) { 'index_name' }
  let(:helper) { Search::Elastic::Helper.new }
  let(:migration_class) do
    Class.new do
      include ::Search::Elastic::MigrationHelper
    end
  end

  subject(:migration) { migration_class.new }

  before do
    allow(migration).to receive(:helper).and_return(helper)
  end

  describe '#get_number_of_shards' do
    let(:number_of_shards) { 10 }
    let(:settings) { { 'number_of_shards' => number_of_shards.to_s } }

    it 'uses get_settings' do
      expect(helper).to receive(:get_settings).with(index_name: index_name).and_return(settings)

      expect(migration.get_number_of_shards(index_name: index_name)).to eq(number_of_shards)
    end
  end

  describe '#get_max_slices' do
    using RSpec::Parameterized::TableSyntax

    before do
      allow(migration).to receive(:get_number_of_shards).with(index_name: index_name).and_return(number_of_shards)
    end

    where(:number_of_shards, :result) do
      nil | 2
      1   | 2
      2   | 2
      3   | 3
    end

    with_them do
      it 'returns correct max_slice' do
        expect(migration.get_max_slices(index_name: index_name)).to eq(result)
      end
    end
  end

  describe '#remove_standalone_index' do
    context 'when index exists' do
      before do
        allow(helper).to receive(:index_exists?).with(index_name: index_name).and_return(true)
      end

      it 'logs the removal' do
        expect(migration).to receive(:log).with('Removing standalone index', index_name: index_name)
        allow(helper).to receive(:delete_index)

        migration.remove_standalone_index(index_name: index_name)
      end

      it 'deletes the index' do
        allow(migration).to receive(:log)
        expect(helper).to receive(:delete_index).with(index_name: index_name)

        migration.remove_standalone_index(index_name: index_name)
      end

      it 'returns the result of delete_index' do
        allow(migration).to receive(:log)
        allow(helper).to receive(:delete_index).with(index_name: index_name).and_return(true)

        expect(migration.remove_standalone_index(index_name: index_name)).to be(true)
      end
    end

    context 'when index does not exist' do
      before do
        allow(helper).to receive(:index_exists?).with(index_name: index_name).and_return(false)
      end

      it 'does not log' do
        expect(migration).not_to receive(:log)

        migration.remove_standalone_index(index_name: index_name)
      end

      it 'does not delete the index' do
        expect(helper).not_to receive(:delete_index)

        migration.remove_standalone_index(index_name: index_name)
      end

      it 'returns false' do
        expect(migration.remove_standalone_index(index_name: index_name)).to be(false)
      end
    end
  end
end
