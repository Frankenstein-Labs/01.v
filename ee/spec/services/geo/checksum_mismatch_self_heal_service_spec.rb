# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ChecksumMismatchSelfHealService, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary, checksum_mismatch_self_heal_cooldown_minutes: 60) }

  before do
    stub_current_geo_node(primary)
  end

  def failure_for(upload, retry_count: 3)
    {
      replicable_name: 'upload',
      replicable_id: upload.id,
      verification_retry_count: retry_count,
      context: { primary_checksum_at_mismatch: upload.verification_checksum }
    }
  end

  describe '#execute' do
    context 'when the record is verification_succeeded and the checksum still matches the reported one' do
      let!(:upload) { create(:upload, :verification_succeeded, verified_at: 2.hours.ago) }

      it 'marks it as verification_pending' do
        expect do
          described_class.new(geo_node_id: nil, failures: [failure_for(upload)]).execute
        end.to change { upload.reload.verification_state }.to(Upload.verification_state_value(:verification_pending))
      end

      it 'returns the number of healed records' do
        result = described_class.new(geo_node_id: nil, failures: [failure_for(upload)]).execute

        expect(result).to eq(1)
      end
    end

    context 'when the record was verified within the cooldown window' do
      let!(:upload) { create(:upload, :verification_succeeded, verified_at: 5.minutes.ago) }

      it 'does not mark it as verification_pending' do
        expect do
          described_class.new(geo_node_id: nil, failures: [failure_for(upload)]).execute
        end.not_to change { upload.reload.verification_state }
      end
    end

    context 'when the record is already verification_pending or verification_started' do
      let!(:upload) { create(:upload, :verification_pending) }

      it 'does not raise and leaves the state unchanged' do
        expect do
          described_class.new(geo_node_id: nil, failures: [failure_for(upload)]).execute
        end.not_to change { upload.reload.verification_state }
      end
    end

    context 'when the record is verification_failed' do
      let!(:upload) { create(:upload, :verification_failed, verified_at: 5.minutes.ago) }

      it 'marks it as verification_pending regardless of the checksum or cooldown window' do
        # verification_failed clears the record's own checksum, but the
        # checksum reported by the secondary (the primary's checksum at the
        # time of the mismatch) is never nil in the real reporting flow, so
        # this must not be compared against the record's (now-nil) checksum.
        expect do
          described_class.new(
            geo_node_id: nil,
            failures: [{
              replicable_name: 'upload',
              replicable_id: upload.id,
              verification_retry_count: 3,
              context: { primary_checksum_at_mismatch: 'checksum-the-secondary-saw' }
            }]
          ).execute
        end.to change { upload.reload.verification_state }.to(Upload.verification_state_value(:verification_pending))
      end
    end

    context "when the primary's checksum has already changed since the secondary's report" do
      let!(:upload) { create(:upload, :verification_succeeded, verified_at: 2.hours.ago) }

      it 'does not mark it as verification_pending' do
        stale_failure = failure_for(upload).merge(context: { primary_checksum_at_mismatch: 'stale-checksum' })

        expect do
          described_class.new(geo_node_id: nil, failures: [stale_failure]).execute
        end.not_to change { upload.reload.verification_state }
      end
    end

    context 'with an unknown replicable_name' do
      it 'does not raise' do
        failure = { replicable_name: 'not_a_replicable', replicable_id: 1, verification_retry_count: 3, context: {} }

        expect { described_class.new(geo_node_id: nil, failures: [failure]).execute }.not_to raise_error
      end
    end

    context 'when the current node is not the primary' do
      let!(:upload) { create(:upload, :verification_succeeded, verified_at: 2.hours.ago) }

      before do
        stub_current_geo_node(create(:geo_node))
      end

      it 'does not mark it as verification_pending' do
        expect do
          described_class.new(geo_node_id: nil, failures: [failure_for(upload)]).execute
        end.not_to change { upload.reload.verification_state }
      end
    end

    context 'when the feature flag is disabled' do
      let!(:upload) { create(:upload, :verification_succeeded, verified_at: 2.hours.ago) }

      before do
        stub_feature_flags(geo_self_heal_checksum_mismatch: false)
      end

      it 'does not mark it as verification_pending' do
        expect do
          described_class.new(geo_node_id: nil, failures: [failure_for(upload)]).execute
        end.not_to change { upload.reload.verification_state }
      end
    end
  end
end
