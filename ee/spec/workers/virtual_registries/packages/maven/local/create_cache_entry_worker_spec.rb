# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker, feature_category: :virtual_registry do
  let_it_be(:relative_path) { '/maven/package-name.pom' }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_local_upstream) }
  let_it_be(:package_file) { create(:package_file, :xml, project: upstream.local_project) }

  let(:worker) { described_class.new }
  let(:package_file_id) { package_file.id }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [upstream.id, package_file_id, relative_path] }
  end

  it 'has an until_executed deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#perform' do
    let(:upstream_id) { upstream.id }
    let(:package_file_id) { package_file.id }

    shared_examples 'not creating a cache entry' do
      it { expect { perform }.not_to change { ::VirtualRegistries::Packages::Maven::Cache::Local::Entry.count } }
    end

    subject(:perform) { worker.perform(upstream_id, package_file_id, relative_path) }

    context 'when upstream and package file exists' do
      it 'creates the cache entry' do
        expect { perform }.to change { ::VirtualRegistries::Packages::Maven::Cache::Local::Entry.count }.by(1)

        entry = ::VirtualRegistries::Packages::Maven::Cache::Local::Entry.last
        expect(entry).to have_attributes(
          group_id: upstream.group_id,
          upstream_id: upstream.id,
          relative_path: relative_path,
          package_file_id: package_file.id
        )
      end

      context 'when a related cache entry exists' do
        let_it_be(:other_package_file) { create(:package_file, :pom) }
        let_it_be_with_reload(:existing_cache_entry) do
          create(
            :virtual_registries_packages_maven_cache_local_entry,
            group_id: upstream.group_id,
            upstream_id: upstream.id,
            relative_path: relative_path,
            package_file_id: other_package_file.id
          )
        end

        it 'updates it' do
          expect { perform }.not_to change { ::VirtualRegistries::Packages::Maven::Cache::Local::Entry.count }

          expect(existing_cache_entry).to have_attributes(
            group_id: upstream.group_id,
            upstream_id: upstream.id,
            relative_path: relative_path,
            package_file_id: package_file.id
          )
        end
      end
    end

    context 'when the relative_path is invalid' do
      let(:relative_path) { '/invalid path with spaces' }

      it 'logs the validation error and does not create a cache entry' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception)
          .with(instance_of(ActiveRecord::RecordInvalid), upstream_id:, package_file_id:, relative_path:)

        expect { perform }.not_to change { ::VirtualRegistries::Packages::Maven::Cache::Local::Entry.count }
      end
    end

    context 'when package file does not exist' do
      let(:package_file_id) { non_existing_record_id }

      it_behaves_like 'not creating a cache entry'
    end

    context 'when upstream does not exist' do
      let(:upstream_id) { non_existing_record_id }

      it_behaves_like 'not creating a cache entry'
    end
  end
end
