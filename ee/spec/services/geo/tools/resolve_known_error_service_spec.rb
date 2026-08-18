# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Tools::ResolveKnownErrorService, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:known_error) { Geo::Tools::KnownErrors.find('url_blocked') }
  let!(:registry) do
    create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: Host cannot be resolved')
  end

  before do
    stub_secondary_node
  end

  describe '#execute' do
    context 'when not runnable on the current site' do
      before do
        stub_primary_node
      end

      it 'skips without acting', :aggregate_failures do
        response = described_class.new(known_error).execute

        expect(response).to be_error
        expect(response.reason).to eq(:not_runnable_on_site)
      end
    end

    context 'with a dry run (default)' do
      it 'reports the count and changes nothing', :aggregate_failures do
        response = described_class.new(known_error).execute

        expect(response).to be_success
        expect(response.payload).to include(count: 1, dry_run: true)
        expect(registry.reload).to be_failed
      end

      it 'does not enqueue a resync' do
        expect(Geo::BulkRegistryResyncService).not_to receive(:new)

        described_class.new(known_error).execute
      end

      it 'states the exact count when the resolution counted the whole set' do
        response = described_class.new(known_error).execute

        expect(response.message).to include('Dry run: 1 records would be affected.')
      end

      context 'when the resolution capped its count' do
        before do
          allow(known_error).to receive(:count_capped?).and_return(true)
        end

        # Otherwise an operator reads the cap as the whole blast radius.
        it 'marks the count as a floor in the message but not in the payload', :aggregate_failures do
          response = described_class.new(known_error).execute

          expect(response.message).to include('Dry run: 1+ records would be affected.')
          expect(response.payload).to include(count: 1)
        end
      end
    end

    context 'when runnable but nothing matches' do
      before do
        registry.update!(last_sync_failure: 'an unrelated failure')
      end

      it 'reports zero affected and changes nothing', :aggregate_failures do
        response = described_class.new(known_error).execute

        expect(response).to be_success
        expect(response.payload).to include(count: 0)
      end
    end

    context 'with a real run' do
      it 'delegates the matched registries to the bulk resync service', :aggregate_failures do
        expect(Geo::BulkRegistryResyncService)
          .to receive(:new)
          .with('Geo::PackageFileRegistry', ids: a_collection_including(registry.id))
          .and_call_original

        response = described_class.new(known_error, dry_run: false).execute

        expect(response).to be_success
        expect(response.payload).to include(count: 1, dry_run: false)
      end
    end
  end
end
