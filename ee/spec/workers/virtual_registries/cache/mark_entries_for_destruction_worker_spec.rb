# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cache::MarkEntriesForDestructionWorker, :aggregate_failures, feature_category: :virtual_registry do
  let(:worker) { described_class.new }

  subject(:perform) { worker.perform(upstream_gid) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it 'has an until_executed deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  shared_examples 'marking entries for destruction' do
    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [upstream.to_global_id.to_s] }
    end

    describe '#perform' do
      context 'when the upstream is found' do
        let(:upstream_gid) { upstream.to_global_id.to_s }

        before do
          create_list(cache_entry_factory, 3, upstream:) # 3 default
          create(cache_entry_factory, :pending_destruction, upstream:) # 1 pending destruction
          # rubocop:disable Rails/SaveBang -- this is a FactoryBot method
          create(cache_entry_factory) # 1 default in another upstream
          # rubocop:enable Rails/SaveBang
        end

        it 'marks default cache entries for destruction' do
          expect { perform }.to change { cache_entry_class.pending_destruction.size }.by(3)
        end
      end

      context 'for unsupported class' do
        let(:upstream_gid) { upstream.group.to_global_id.to_s }

        it 'does not mark any cache entries for destruction' do
          expect { perform }.not_to change { cache_entry_class.pending_destruction.size }

          is_expected.to be_nil
        end
      end

      context 'when the upstream is not found' do
        let(:upstream_gid) { "gid://gitlab/#{upstream_class_name}/#{non_existing_record_id}" }

        it 'logs the error and does not mark any cache entries for destruction' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(instance_of(ActiveRecord::RecordNotFound), gid: upstream_gid, worker: described_class.name)

          expect { perform }.not_to change { cache_entry_class.pending_destruction.size }

          is_expected.to be_nil
        end
      end

      context 'when the global ID references a non-existent class' do
        let(:upstream_gid) { "gid://gitlab/VirtualRegistries::Packages::Maven::NonExistent::Upstream/#{upstream.id}" }

        it 'logs the error and does not mark any cache entries for destruction' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(instance_of(NameError), gid: upstream_gid, worker: described_class.name)

          expect { perform }.not_to change { cache_entry_class.pending_destruction.size }

          is_expected.to be_nil
        end
      end
    end
  end

  context 'with a container upstream' do
    let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream) }
    let(:cache_entry_factory) { :virtual_registries_container_cache_remote_entry }
    let(:cache_entry_class) { ::VirtualRegistries::Container::Cache::Remote::Entry }
    let(:upstream_class_name) { 'VirtualRegistries::Container::Upstream' }

    it_behaves_like 'marking entries for destruction'
  end

  context 'with a maven upstream' do
    let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream) }
    let(:cache_entry_factory) { :virtual_registries_packages_maven_cache_remote_entry }
    let(:cache_entry_class) { ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry }
    let(:upstream_class_name) { 'VirtualRegistries::Packages::Maven::Upstream' }

    it_behaves_like 'marking entries for destruction'
  end

  context 'with a NPM upstream' do
    let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_npm_upstream) }
    let(:cache_entry_factory) { :virtual_registries_packages_npm_cache_remote_entry }
    let(:cache_entry_class) { ::VirtualRegistries::Packages::Npm::Cache::Remote::Entry }
    let(:upstream_class_name) { 'VirtualRegistries::Packages::Npm::Upstream' }

    it_behaves_like 'marking entries for destruction'
  end
end
