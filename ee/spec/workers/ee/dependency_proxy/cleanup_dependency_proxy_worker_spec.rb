# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::CleanupDependencyProxyWorker, type: :worker, feature_category: :virtual_registry do
  describe '#perform' do
    subject(:worker_perform) { described_class.new.perform }

    context 'when there are records to be deleted' do
      it_behaves_like 'an idempotent worker' do
        it 'queues the cleanup jobs', :aggregate_failures do
          create(:virtual_registries_packages_maven_cache_entry, :pending_destruction)
          create(:virtual_registries_packages_maven_cache_remote_entry, :pending_destruction)
          create(:virtual_registries_container_cache_entry, :pending_destruction)
          create(:virtual_registries_container_cache_remote_entry, :pending_destruction)

          described_class::VREG_CACHE_ENTRY_CLASSES.each do |klass|
            expect(::VirtualRegistries::Cache::DestroyOrphanEntriesWorker)
              .to receive(:perform_with_capacity).with(klass.name)
          end

          worker_perform
        end
      end
    end

    context 'when there are no records to be deleted' do
      it_behaves_like 'an idempotent worker' do
        it 'does not queue the cleanup jobs', :aggregate_failures do
          expect(::VirtualRegistries::Cache::DestroyOrphanEntriesWorker)
            .not_to receive(:perform_with_capacity)

          worker_perform
        end
      end
    end
  end
end
