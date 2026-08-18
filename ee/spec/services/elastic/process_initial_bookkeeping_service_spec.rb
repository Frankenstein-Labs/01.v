# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::ProcessInitialBookkeepingService, feature_category: :global_search do
  include EE::GeoHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue) }

  describe '.backfill_projects!' do
    context 'when project is maintaining indexed associations' do
      using RSpec::Parameterized::TableSyntax

      where(:geo, :commit_indexing_expected) do
        :disabled             | true
        :primary              | true
        :secondary            | false
        :org_migration_target | false
      end

      with_them do
        before do
          case geo
          when :disabled
            # no-op
          when :org_migration_target
            node = stub_org_migration_target_cell
            node.update!(selective_sync_type: 'organizations')
            node.organizations << project.organization
          else
            public_send(:"stub_#{geo}_node")
          end

          allow(project).to receive(:maintaining_indexed_associations?).and_return(true)
        end

        it 'indexes itself and initiates wiki reindexing, commits reindexing when indexing is excepted' do
          expect(described_class).to receive(:track!).with(project)
          expect(described_class).to receive(:maintain_indexed_associations)
            .with(project, Elastic::ProcessInitialBookkeepingService::INDEXED_PROJECT_ASSOCIATIONS)
          expect(ElasticWikiIndexerWorker).to receive(:perform_async)
            .with(project.id, project.class.name, { 'force' => true })

          if commit_indexing_expected
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async)
              .with(project.id, { 'force' => true })
          else
            expect(Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)
          end

          described_class.backfill_projects!(project)
        end
      end
    end

    it 'raises an exception if non project is provided' do
      expect { described_class.backfill_projects!(issue) }.to raise_error(ArgumentError)
    end

    it 'uses a separate queue' do
      expect { described_class.backfill_projects!(project) }
        .not_to change { Elastic::ProcessBookkeepingService.queue_size }
    end

    context 'when project is not maintaining indexed associations' do
      before do
        allow(project).to receive(:maintaining_indexed_associations?).and_return(false)
      end

      it 'indexes itself only' do
        expect(described_class).not_to receive(:maintain_indexed_associations)
        expect(Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)
        expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)

        described_class.backfill_projects!(project)
      end
    end
  end

  describe '#execute', :clean_gitlab_redis_shared_state do
    let(:refs) { [Search::Elastic::DocumentReference.build(project)] }

    it 'increments the custom indexing sli apdex' do
      described_class.track!(*refs)

      expect(Gitlab::Metrics::GlobalSearchIndexingSlis).to receive(:record_bytes_per_second_apdex)
        .with(
          throughput: a_kind_of(Numeric),
          target: Gitlab::Metrics::GlobalSearchIndexingSlis::INITIAL_INDEXED_BYTES_PER_SECOND_TARGET
        )

      described_class.new.execute
    end
  end
end
