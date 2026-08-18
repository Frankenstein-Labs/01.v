# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MigrationCreateIndexHelper, feature_category: :global_search do
  let(:migration_class) do
    Class.new do
      include ::Search::Elastic::MigrationCreateIndexHelper

      def target_class
        WorkItem
      end
    end
  end

  subject(:migration) { migration_class.new }

  describe '#creates_standalone_index?' do
    it 'returns true' do
      expect(migration.creates_standalone_index?).to be(true)
    end
  end

  describe '#target_class' do
    it 'returns the configured class' do
      expect(migration.target_class).to eq(WorkItem)
    end

    context 'when not overridden' do
      let(:migration_class) do
        Class.new { include ::Search::Elastic::MigrationCreateIndexHelper }
      end

      it 'raises NotImplementedError' do
        expect { migration.target_class }.to raise_error(NotImplementedError)
      end
    end
  end
end
