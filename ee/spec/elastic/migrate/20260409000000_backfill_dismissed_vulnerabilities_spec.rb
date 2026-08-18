# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260409000000_backfill_dismissed_vulnerabilities.rb')

RSpec.describe BackfillDismissedVulnerabilities, :elastic, feature_category: :vulnerability_management do
  let(:version) { 20260409000000 }
  let(:migration) { described_class.new(version) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    set_elasticsearch_migration_to(version, including: false)
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(30.seconds)
      expect(migration.batch_size).to eq(30_000)
    end
  end

  describe '.migrate' do
    let_it_be(:dismissed_reads) { create_list(:vulnerability_read, 2, state: :dismissed) }
    let_it_be(:detected_read) { create(:vulnerability_read, state: :detected) }

    subject(:migrate) { migration.migrate }

    it_behaves_like 'it syncs vulnerabilities with ES', -> { dismissed_reads.map(&:id) }, :migrate
  end

  describe '.completed?' do
    context 'when there are dismissed vulnerability reads to process' do
      let_it_be(:dismissed_read) { create(:vulnerability_read, state: :dismissed) }

      it 'returns false' do
        expect(migration).not_to be_completed
      end
    end

    context 'when all dismissed vulnerability reads have been processed' do
      let_it_be(:dismissed_read) { create(:vulnerability_read, state: :dismissed) }

      before do
        migration.set_migration_state(current_id: dismissed_read.id)
      end

      it 'returns true' do
        expect(migration).to be_completed
      end
    end

    context 'when there are only detected vulnerability reads' do
      let_it_be(:detected_read) { create(:vulnerability_read, state: :detected) }

      it 'returns true' do
        expect(migration).to be_completed
      end
    end
  end
end
