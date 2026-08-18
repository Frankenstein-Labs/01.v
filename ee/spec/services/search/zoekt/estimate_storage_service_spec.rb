# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::EstimateStorageService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }

  before do
    allow(logger).to receive(:info)
  end

  describe '.execute' do
    it 'instantiates and calls execute' do
      service = instance_double(described_class, execute: nil)
      expect(described_class).to receive(:new).with(logger: logger).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(logger: logger)
    end
  end

  describe '#execute' do
    context 'when no Zoekt namespaces are configured' do
      before do
        stub_application_setting(zoekt_default_number_of_replicas: 1)
        create(:namespace_root_storage_statistics, repository_size: 100.gigabytes)
      end

      it 'estimates from all namespace statistics' do
        # 100 GB x 3 (BUFFER_FACTOR) x 1 replica = 300 GiB provisioning
        expect(logger).to receive(:info).with(a_string_including('300 GiB')).at_least(:once)

        described_class.execute(logger: logger)
      end

      it 'logs a note that Zoekt is not yet configured' do
        expect(logger).to receive(:info).with(a_string_including('not yet configured')).at_least(:once)

        described_class.execute(logger: logger)
      end

      it 'logs the total git repository size' do
        expect(logger).to receive(:info).with(a_string_including('100 GiB')).at_least(:once)

        described_class.execute(logger: logger)
      end
    end

    context 'when Zoekt namespaces are configured' do
      let(:namespace) { create(:namespace) }
      let!(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }

      before do
        stub_application_setting(zoekt_default_number_of_replicas: 1)
        create(:namespace_root_storage_statistics, namespace: namespace, repository_size: 100.gigabytes)
      end

      it 'estimates from enabled namespaces only' do
        # 100 GB x 3 (BUFFER_FACTOR) x 1 replica = 300 GiB provisioning
        expect(logger).to receive(:info).with(a_string_including('300 GiB')).at_least(:once)

        described_class.execute(logger: logger)
      end

      it 'logs the enabled namespaces count' do
        expect(logger).to receive(:info).with(a_string_including('1 enabled namespace')).at_least(:once)

        described_class.execute(logger: logger)
      end

      it 'logs the replica count when all namespaces have the same replica count' do
        expect(logger).to receive(:info).with(a_string_including('1 (all namespaces)')).at_least(:once)

        described_class.execute(logger: logger)
      end

      context 'when namespaces have different replica counts' do
        let(:namespace2) { create(:namespace) }
        let!(:enabled_namespace2) do
          create(:zoekt_enabled_namespace, namespace: namespace2, search: true)
        end

        before do
          stub_application_setting(zoekt_default_number_of_replicas: 1)
          enabled_namespace2.update!(number_of_replicas_override: 2)
          create(:namespace_root_storage_statistics, namespace: namespace2, repository_size: 50.gigabytes)
        end

        it 'logs a per-replica-count breakdown' do
          expect(logger).to receive(:info).with(a_string_including('1 replica(s): 1 namespace')).at_least(:once)
          expect(logger).to receive(:info).with(a_string_including('2 replica(s): 1 namespace')).at_least(:once)

          described_class.execute(logger: logger)
        end
      end

      it 'logs practical usage estimate' do
        # 100 GB x 0.5 x 1 replica = 50 GiB practical
        expect(logger).to receive(:info).with(a_string_including('50 GiB')).at_least(:once)

        described_class.execute(logger: logger)
      end

      it 'shows reserved bytes when index exists' do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace,
          reserved_storage_bytes: 250.gigabytes)
        expect(logger).to receive(:info).with(a_string_including('reserved')).at_least(:once)
        described_class.execute(logger: logger)
      end

      context 'when namespace has no root storage statistics' do
        before do
          namespace.root_storage_statistics&.destroy!
        end

        it 'treats missing statistics as 0 bytes' do
          expect { described_class.execute(logger: logger) }.not_to raise_error
        end
      end
    end
  end
end
