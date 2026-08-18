# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ReverifyContainerRepositoriesService, :geo, feature_category: :geo_replication do
  let(:cutoff) { 2.days.ago.change(usec: 0) }
  let(:service) { described_class.new(verified_after: cutoff) }

  let!(:verified_before_cutoff) do
    create(:geo_container_repository_state, :verification_succeeded, verified_at: cutoff - 1.day)
  end

  let!(:verified_at_cutoff) do
    create(:geo_container_repository_state, :verification_succeeded, verified_at: cutoff)
  end

  let!(:verified_after_cutoff) do
    create(:geo_container_repository_state, :verification_succeeded, verified_at: cutoff + 1.day)
  end

  let!(:pending_after_cutoff) do
    create(:geo_container_repository_state, verified_at: cutoff + 1.day)
  end

  before do
    stub_container_registry_config(enabled: true)
  end

  describe '#execute' do
    it 'only marks non-pending records verified at or after the cutoff as pending', :aggregate_failures do
      service.execute

      expect(verified_before_cutoff.reload).to be_verification_succeeded
      expect(verified_at_cutoff.reload).to be_verification_pending
      expect(verified_after_cutoff.reload).to be_verification_pending
    end

    it 'returns a success response with the updated count' do
      result = service.execute

      expect(result).to be_success
      expect(result.payload[:count]).to eq(2)
      expect(result.message).to eq('Marked 2 container repositories for reverification.')
    end

    context 'with multiple batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it 'updates all matching records across batches' do
        expect(service.execute.payload[:count]).to eq(2)
      end
    end

    context 'when no records match' do
      let(:service) { described_class.new(verified_after: 1.day.from_now) }

      it 'updates nothing and reports a zero count', :aggregate_failures do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:count]).to eq(0)
        expect(verified_before_cutoff.reload).to be_verification_succeeded
      end
    end
  end

  describe '#dry_run' do
    it 'returns the count of records execute would update without updating anything', :aggregate_failures do
      result = service.dry_run

      expect(result).to be_success
      expect(result.payload[:count]).to eq(2)
      expect(result.message).to eq('DRY RUN: 2 container repositories would be marked for reverification.')

      expect(verified_at_cutoff.reload).to be_verification_succeeded
      expect(verified_after_cutoff.reload).to be_verification_succeeded
    end

    context 'with multiple batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it 'counts all matching records across batches' do
        expect(service.dry_run.payload[:count]).to eq(2)
      end
    end
  end
end
