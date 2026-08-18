# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/active_context/migrate/20260521000000_set_default_chunk_strategy.rb')

RSpec.describe SetDefaultChunkStrategy, feature_category: :global_search do
  let(:version) { 20260521000000 }
  let(:migration_class) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let_it_be(:collection) do
    create(:ai_active_context_collection, :code_collection, chunk_strategy: nil, chunk_strategy_size: nil)
  end

  subject(:migrate) { migration_class.new.migrate! }

  it 'sets chunk_strategy on the collection' do
    expect { migrate }.to change {
      collection.reload.chunk_strategy
    }.from(nil).to('code_bytes')
  end

  it 'sets chunk_strategy_size on the collection' do
    expect { migrate }.to change {
      collection.reload.chunk_strategy_size
    }.from(nil).to(1000)
  end

  context 'when chunk_strategy is already set' do
    before do
      collection.update_columns(
        options: collection.options.merge('chunk_strategy' => 'code_bytes', 'chunk_strategy_size' => 1000)
      )
    end

    it 'does not change chunk_strategy' do
      expect { migrate }.not_to change { collection.reload.chunk_strategy }
    end
  end

  describe '#skip?' do
    it 'checks the presence of the self-hosted AIGW url' do
      migration = migration_class.new

      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
      expect(migration.skip?).to be(false)

      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(true)
      expect(migration.skip?).to be(true)
    end
  end
end
