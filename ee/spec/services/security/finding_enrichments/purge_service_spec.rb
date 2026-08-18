# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::FindingEnrichments::PurgeService, :clean_gitlab_redis_shared_state,
  feature_category: :security_policy_management do
  describe 'class methods' do
    describe '.purge_stale_records' do
      let_it_be(:project) { create(:project) }
      let_it_be(:stale_enrichment) do
        create(:security_finding_enrichment, project: project,
          created_at: (Security::Scan.stale_after + 2.days).ago, vulnerability_id: nil)
      end

      let_it_be(:stale_enrichment_tuple_cache) do
        { "created_at" => Security::FindingEnrichment.connection.quote(stale_enrichment.created_at),
          "id" => stale_enrichment.id }
      end

      let_it_be(:fresh_enrichment) { create(:security_finding_enrichment, project: project) }

      let_it_be(:stale_enrichment_with_vulnerability) do
        create(:security_finding_enrichment, :with_vulnerability, project: project,
          created_at: (Security::Scan.stale_after + 2.days).ago)
      end

      subject(:purge_stale_records) { described_class.purge_stale_records }

      it 'deletes stale enrichments without vulnerability link' do
        expect { purge_stale_records }.to change {
          Security::FindingEnrichment.exists?(stale_enrichment.id)
        }.from(true).to(false).and not_change { Security::FindingEnrichment.exists?(fresh_enrichment.id) }
      end

      it 'does not delete stale enrichments with vulnerability link' do
        expect { purge_stale_records }.not_to change {
          Security::FindingEnrichment.exists?(stale_enrichment_with_vulnerability.id)
        }.from(true)
      end

      describe 'dead tuple optimisation' do
        let(:redis_key) { "CursorStore:#{described_class::LAST_PURGED_ENRICHMENT_TUPLE}" }

        def cached_tuple
          data_on_redis = Gitlab::Redis::SharedState.with { |redis| redis.get(redis_key) }

          ::Gitlab::Json.safe_parse(data_on_redis)
        end

        it 'caches a previous purged tuple' do
          expect { purge_stale_records }.to change {
            cached_tuple
          }.from(nil).to(stale_enrichment_tuple_cache)
        end

        context 'when a previous purged tuple is cached' do
          let_it_be(:second_stale_enrichment) do
            create(:security_finding_enrichment, project: project,
              created_at: (Security::Scan.stale_after + 1.day).ago)
          end

          before do
            described_class.redis_cursor.commit(stale_enrichment_tuple_cache)
          end

          it 'uses the cached tuple to scope the query and skip already checked values' do
            expect { purge_stale_records }.to change {
              Security::FindingEnrichment.exists?(second_stale_enrichment.id)
            }.from(true).to(false).and not_change { Security::FindingEnrichment.exists?(stale_enrichment.id) }
          end
        end
      end
    end
  end

  describe '#execute' do
    let(:project) { create(:project) }

    context 'when there are many stale enrichments' do
      before do
        stub_const("#{described_class}::MAX_STALE_ENRICHMENTS_SIZE", 2)
        stub_const("#{described_class}::ENRICHMENT_BATCH_SIZE", 1)

        create_list(:security_finding_enrichment, 3, project: project,
          created_at: (Security::Scan.stale_after + 2.days).ago)
      end

      it 'limits the number of deleted enrichments' do
        service = described_class.new(Security::FindingEnrichment.stale.ordered_by_created_at_and_id)

        expect { service.execute }.to change { Security::FindingEnrichment.count }.by(-2)
      end
    end
  end
end
