# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::NamespaceIndexIntegrityWorker, feature_category: :global_search do
  include ExclusiveLeaseHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:projects) { create_list(:project, 3, :repository, namespace: group) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when namespace_id is not provided' do
      it 'does nothing' do
        expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_in)

        worker.perform(nil)
      end
    end

    context 'when namespace_id is provided', :elastic_delete_by_query do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      end

      it 'executes under an exclusive lease' do
        expect_to_obtain_exclusive_lease("#{described_class.name.underscore}/namespace/#{group.id}",
          timeout: described_class::LEASE_TIMEOUT)

        worker.perform(group.id)
      end

      it_behaves_like 'an idempotent worker' do
        let(:job_args) { [group.id] }

        it 'schedules ProjectIndexIntegrityWorker for each project with a delay' do
          stub_const("#{described_class.name}::PROJECT_DELAY_INTERVAL", 5)

          group.all_projects.each do |p|
            expect(::Search::ProjectIndexIntegrityWorker).to receive(:perform_in).with(
              within(5.seconds).of(5.seconds),
              p.id
            ).and_call_original
          end

          worker.perform(group.id)
        end
      end

      context 'when project.should_check_index_integrity? is false' do
        it 'does not schedule ProjectIndexIntegrityWorker for that project' do
          allow_next_found_instance_of(Project) do |p|
            allow(p).to receive(:should_check_index_integrity?).and_return(false)
          end

          expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_in)

          worker.perform(group.id)
        end
      end

      context 'when a namespace has sub-groups' do
        it 'does not schedule workers for child namespaces', :aggregate_failures do
          sg_1 = create(:group, parent: group)
          sg_2 = create(:group, parent: sg_1)
          create(:project, :repository, namespace: sg_1)
          create(:project, :repository, namespace: sg_2)

          # NamespaceEachBatch already yields all descendants in a single pass
          # So we should NOT schedule NamespaceIndexIntegrityWorker for child groups
          expect(described_class).not_to receive(:perform_in)

          # Verify projects are scheduled, including both root and descendant projects
          # Total: 3 root projects + 2 descendant projects = 5 projects
          expect(::Search::ProjectIndexIntegrityWorker).to receive(:perform_in).exactly(5).times

          worker.perform(group.id)
        end
      end

      context 'when namespace has many descendants' do
        it 'processes in batches and throttles if needed', :aggregate_failures do
          stub_const("#{described_class.name}::BATCH_SIZE", 2)
          stub_const("#{described_class.name}::MAX_SCHEDULED_PER_RUN", 3)

          sg_1 = create(:group, parent: group)
          create(:group, parent: sg_1)

          # Should process first batch, then throttle and reschedule with cursor in params hash
          expect(described_class).to receive(:perform_in).with(
            5.minutes,
            group.id,
            hash_including('cursor' => hash_including('current_id', 'depth'))
          ).once

          worker.perform(group.id)
        end

        it 'does not log "processing completed" when throttled' do
          stub_const("#{described_class.name}::BATCH_SIZE", 2)
          stub_const("#{described_class.name}::MAX_SCHEDULED_PER_RUN", 3)

          sg_1 = create(:group, parent: group)
          create(:group, parent: sg_1)

          allow(described_class).to receive(:perform_in)

          # Expect throttle warning but not completion message
          expect(worker.send(:logger)).to receive(:warn)
            .with(hash_including('message' => 'throttling namespace processing, rescheduling'))
            .and_call_original
          expect(worker.send(:logger)).not_to receive(:info)
            .with(hash_including('message' => 'namespace processing completed'))

          worker.perform(group.id)
        end

        it 'uses string keys for cursor parameters' do
          stub_const("#{described_class.name}::BATCH_SIZE", 2)
          stub_const("#{described_class.name}::MAX_SCHEDULED_PER_RUN", 3)

          sg_1 = create(:group, parent: group)
          create(:group, parent: sg_1)

          expect(described_class).to receive(:perform_in) do |_delay, _namespace_id, params|
            expect(params).to be_a(Hash)
            expect(params.keys).to all(be_a(String))
            expect(params['cursor']).to be_a(Hash)
            expect(params['cursor'].keys).to all(be_a(String))
          end

          worker.perform(group.id)
        end
      end

      context 'when processing with cursor' do
        it 'can resume from a saved cursor' do
          sg_1 = create(:group, parent: group)
          create(:project, :repository, namespace: sg_1)
          cursor = { current_id: sg_1.id, depth: [group.id, sg_1.id] }

          # Should continue processing from cursor position and schedule project workers
          expect(::Search::ProjectIndexIntegrityWorker).to receive(:perform_in).at_least(:once)

          worker.perform(group.id, { cursor: cursor })
        end

        it 'accepts cursor param containing valid native JSON types' do
          sg_1 = create(:group, parent: group)
          create(:project, :repository, namespace: sg_1)

          # Cursor params should be native JSON types (strings, numbers, arrays)
          cursor_param = {
            'current_id' => sg_1.id, # Integer (native JSON number)
            'depth' => [group.id, sg_1.id] # Array of integers (native JSON array)
          }

          expect { worker.perform(group.id, { 'cursor' => cursor_param }) }.not_to raise_error
        end
      end

      context 'when namespace is not found' do
        it 'does nothing' do
          expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_in)

          worker.perform(non_existing_record_id)
        end
      end

      context 'when namespace.use_elasticsearch? is false' do
        it 'does nothing' do
          allow_next_found_instance_of(Namespace) do |p|
            allow(p).to receive(:use_elasticsearch?).and_return(false)
          end

          expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_in)
          expect(described_class).not_to receive(:perform_in)

          worker.perform(group.id)
        end
      end
    end
  end
end
