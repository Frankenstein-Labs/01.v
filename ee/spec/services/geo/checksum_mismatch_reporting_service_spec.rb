# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ChecksumMismatchReportingService, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) do
    create(:geo_node, checksum_mismatch_report_threshold: 3, checksum_mismatch_self_heal_cooldown_minutes: 60)
  end

  subject(:service) { described_class.new(secondary) }

  before do
    stub_current_geo_node(secondary)
    allow(Gitlab::Geo).to receive(:repository_replicator_classes).and_return([Geo::ProjectRepositoryReplicator])
  end

  def stub_http_success
    allow(Gitlab::HTTP).to receive(:perform_request)
      .and_return(double(success?: true, parsed_response: { 'message' => 'OK' })) # rubocop:disable RSpec/VerifiedDoubles -- generic HTTP response double
  end

  describe '#execute' do
    context 'when there are no persistent checksum mismatches' do
      it 'does not perform a request and returns false' do
        expect(Gitlab::HTTP).not_to receive(:perform_request)

        expect(service.execute).to be(false)
      end
    end

    context 'when a registry has mismatched below the threshold' do
      before do
        create(:geo_project_repository_registry, :verification_failed, checksum_mismatch: true,
          verification_retry_count: 2)
      end

      it 'does not report it' do
        expect(Gitlab::HTTP).not_to receive(:perform_request)

        expect(service.execute).to be(false)
      end
    end

    context 'when a registry has persistently mismatched at or above the threshold' do
      let!(:registry) do
        create(:geo_project_repository_registry, :verification_failed,
          checksum_mismatch: true,
          verification_retry_count: 3,
          verification_checksum_mismatched: 'abc123')
      end

      it 'reports it to the primary' do
        stub_http_success

        expect(Gitlab::HTTP).to receive(:perform_request).with(
          Net::HTTP::Post,
          primary.checksum_mismatch_reports_url,
          hash_including(body: hash_including(
            geo_node_id: secondary.id,
            failures: [hash_including(
              error_type: 'checksum_mismatch',
              replicable_name: 'project_repository',
              replicable_id: registry.model_record_id,
              verification_retry_count: 3,
              context: { primary_checksum_at_mismatch: 'abc123' }
            )]
          ))
        )

        expect(service.execute).to be_truthy
      end

      it 'does not report the same registry again within the cooldown window' do
        stub_http_success

        service.execute

        expect(Gitlab::HTTP).not_to receive(:perform_request)

        expect(described_class.new(secondary).execute).to be(false)
      end

      it 'sets the dedup marker to expire after the cooldown window' do
        stub_http_success

        service.execute

        ttl = Gitlab::Redis::SharedState.with do |redis|
          redis.ttl("geo:checksum_mismatch_reported:project_repository:#{registry.model_record_id}")
        end

        expect(ttl).to be_within(5).of(60.minutes.to_i)
      end

      it 'reports the registry again once the dedup marker has expired' do
        stub_http_success

        service.execute

        Gitlab::Redis::SharedState.with do |redis|
          redis.del("geo:checksum_mismatch_reported:project_repository:#{registry.model_record_id}")
        end

        expect(Gitlab::HTTP).to receive(:perform_request).and_return(
          double(success?: true, parsed_response: { 'message' => 'OK' }) # rubocop:disable RSpec/VerifiedDoubles -- generic HTTP response double
        )

        expect(described_class.new(secondary).execute).to be_truthy
      end
    end
  end
end
