# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PurgeScansService, feature_category: :vulnerability_management do
  describe 'class interface' do
    describe '.purge_stale_records', :clean_gitlab_redis_shared_state do
      let!(:stale_scan) { create(:security_scan, created_at: 92.days.ago) }
      let(:stale_scan_tuple_cache) do
        { "created_at" => Security::Scan.connection.quote(stale_scan.created_at), "id" => stale_scan.id }
      end

      let!(:fresh_scan) { create(:security_scan) }

      subject(:purge_stale_records) { described_class.purge_stale_records }

      it 'instantiates the service class with stale scans' do
        expect { purge_stale_records }.to change { stale_scan.reload.status }.to("purged")
                                      .and not_change { fresh_scan.reload.status }
      end

      describe 'dead tuple optimisation' do
        let(:redis_key) { "CursorStore:#{described_class::LAST_PURGED_SCAN_TUPLE}" }

        def cached_tuple
          data_on_redis = Gitlab::Redis::SharedState.with { |redis| redis.get(redis_key) }

          Gitlab::Json.parse(data_on_redis)
        end

        it 'caches a previous purged tuple' do
          expect { purge_stale_records }.to change {
            cached_tuple
          }.from(nil).to(stale_scan_tuple_cache)
        end

        context 'when a previous purged tuple is cached' do
          let!(:second_stale_scan) { create(:security_scan, created_at: 91.days.ago) }

          before do
            Gitlab::Redis::SharedState.with do |redis|
              redis.set(redis_key, stale_scan_tuple_cache.to_json)
            end
          end

          it 'uses the cached tuple to scope the query and skip already checked values' do
            expect { purge_stale_records }.to change { second_stale_scan.reload.status }.to("purged")
                                          .and not_change { stale_scan.reload.status }
          end
        end
      end
    end

    describe '.purge_by_build_ids' do
      let(:security_scans) { create_list(:security_scan, 2) }

      subject(:purge_by_build_ids) { described_class.purge_by_build_ids([security_scans.first.build_id]) }

      it 'instantiates the service class with scans by given build ids' do
        expect { purge_by_build_ids }.to change { security_scans.first.reload.status }.to("purged")
                                     .and not_change { security_scans.second.reload.status }
      end
    end
  end
end
