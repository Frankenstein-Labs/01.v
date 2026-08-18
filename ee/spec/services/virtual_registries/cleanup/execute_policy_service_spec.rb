# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::ExecutePolicyService, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group:) }

  let(:service) { described_class.new(policy) }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when policy is nil' do
      let(:policy) { nil }

      it { is_expected.to be_error }
    end

    context 'when policy exists' do
      context 'with no cache entries' do
        it 'returns success with zero counts' do
          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 0, deleted_size: 0 },
              container: { deleted_entries_count: 0, deleted_size: 0 }
            }
          )
        end
      end

      shared_examples 'cache entries requiring cleanup' do |entry_type, factory_name, expected_payload_key|
        let!(:old_entry1) do
          create(factory_name, group: group, size: 2048, downloaded_at: 35.days.ago)
        end

        let!(:old_entry2) do
          create(factory_name, group: group, size: 4096, downloaded_at: 40.days.ago)
        end

        let!(:recent_entry) do
          create(factory_name, group: group, size: 1024, downloaded_at: 10.days.ago)
        end

        before do
          allow(::VirtualRegistries::CreateAuditEventsService).to receive(:new).and_call_original
        end

        it 'marks old entries for destruction and returns correct counts, and creates audit events',
          :aggregate_failures do
          expect { execute }.to change {
            entry_type.for_group(group).pending_destruction.size
          }.by(2)

          expect_audit_events_for([old_entry1, old_entry2])

          is_expected.to be_success.and have_attributes(payload: expected_payload_key)
        end
      end

      context 'with maven cache entries requiring cleanup' do
        it_behaves_like 'cache entries requiring cleanup',
          ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry,
          :virtual_registries_packages_maven_cache_remote_entry,
          {
            maven: { deleted_entries_count: 2, deleted_size: 6144 },
            container: { deleted_entries_count: 0, deleted_size: 0 }
          }
      end

      context 'with container cache entries requiring cleanup' do
        it_behaves_like 'cache entries requiring cleanup',
          ::VirtualRegistries::Container::Cache::Remote::Entry,
          :virtual_registries_container_cache_remote_entry,
          {
            maven: { deleted_entries_count: 0, deleted_size: 0 },
            container: { deleted_entries_count: 2, deleted_size: 6144 }
          }
      end

      context 'with both maven and container cache entries requiring cleanup' do
        let!(:old_maven_entry1) do
          create(
            :virtual_registries_packages_maven_cache_remote_entry,
            group: group,
            size: 1024,
            downloaded_at: 35.days.ago
          )
        end

        let!(:old_maven_entry2) do
          create(
            :virtual_registries_packages_maven_cache_remote_entry,
            group: group,
            size: 2048,
            downloaded_at: 40.days.ago
          )
        end

        let_it_be_with_reload(:old_container_entry1) do
          create(
            :virtual_registries_container_cache_remote_entry,
            group: group,
            size: 2048,
            downloaded_at: 35.days.ago
          )
        end

        let_it_be_with_reload(:old_container_entry2) do
          create(
            :virtual_registries_container_cache_remote_entry,
            group: group,
            size: 4096,
            downloaded_at: 40.days.ago
          )
        end

        before do
          allow(::VirtualRegistries::CreateAuditEventsService).to receive(:new).and_call_original
        end

        it 'marks old entries for destruction and returns correct counts for both types, and creates audit events',
          :aggregate_failures do
          expect do
            execute
          end.to change {
            ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry.for_group(group).pending_destruction.size
          }.by(2).and change {
            ::VirtualRegistries::Container::Cache::Remote::Entry.for_group(group).pending_destruction.size
          }.by(2)

          expect_audit_events_for([old_maven_entry1, old_maven_entry2])
          expect_audit_events_for([old_container_entry1, old_container_entry2])

          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 2, deleted_size: 3072 },
              container: { deleted_entries_count: 2, deleted_size: 6144 }
            }
          )
        end
      end

      context 'with large number of entries' do
        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)

          create_list(
            :virtual_registries_packages_maven_cache_remote_entry, 5,
            group: group,
            size: 1024,
            downloaded_at: 35.days.ago
          )
        end

        it 'processes all batches', :aggregate_failures do
          expect { execute }.to change {
            ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry.for_group(group).pending_destruction.size
          }.by(5)

          is_expected.to be_success.and have_attributes(
            payload: {
              maven: { deleted_entries_count: 5, deleted_size: 5120 },
              container: { deleted_entries_count: 0, deleted_size: 0 }
            }
          )
        end
      end

      context 'when an error occurs' do
        before do
          allow(::VirtualRegistries::Packages::Maven::Cache::Remote::Entry).to receive(:default)
            .and_raise(StandardError, 'Database error')
        end

        it { is_expected.to be_error.and have_attributes(message: /Database error/) }
      end
    end

    def expect_audit_events_for(entries)
      expect(::VirtualRegistries::CreateAuditEventsService).to have_received(:new).once
        .with(entries: entries, event_name: "#{entries.first.model_name.param_key}_deleted")
    end
  end
end
