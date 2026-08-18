# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Ingestion::Advisory::IngestionService, feature_category: :software_composition_analysis do
  describe '.execute', :freeze_time do
    using RSpec::Parameterized::TableSyntax

    subject(:execute) { described_class.execute(import_data) }

    let(:recent_advisories) { ds_advisories + cs_advisories }
    let(:old_advisories) { build_list(:pm_advisory_data_object, 5, published_date: Time.zone.now - 14.days - 1.second) }
    let(:import_data) { recent_advisories + old_advisories }

    let(:ds_advisories) do
      build_list(:pm_advisory_data_object, 5, source_xid: 'glad',
        published_date: Time.zone.now - 13.days)
    end

    let(:cs_advisories) do
      build_list(:pm_advisory_data_object, 5, source_xid: 'trivy-db',
        published_date: Time.zone.now - 13.days)
    end

    before do
      allow(Gitlab::AppJsonLogger).to receive(:info).and_call_original
    end

    it 'publishes only recently ingested advisories to the event store' do
      received_events = []
      allow(Gitlab::EventStore).to receive(:publish) do |event|
        received_events << event
      end

      execute

      received_advisory_ids = received_events.map { |event| event.data[:advisory_id] }
      received_advisories = PackageMetadata::Advisory.where(id: received_advisory_ids)
                                                     .pluck(:source_xid, :advisory_xid)
      expected = recent_advisories.map { |obj| [obj.source_xid, obj.advisory_xid] }

      expect(received_advisories).to match_array(expected)

      expect(Gitlab::AppJsonLogger).to have_received(:info)
        .with(message: 'Queued scan for advisory', source_xid: be_present, advisory_xid: be_present)
        .at_least(:once)
    end

    it 'uses package metadata application record transactions' do
      expect(PackageMetadata::ApplicationRecord).to receive(:transaction)
      execute
    end

    it 'adds new advisories and affected packages' do
      expect { execute }
        .to change { PackageMetadata::Advisory.count }.by(import_data.size)
                                                      .and change {
                                                        PackageMetadata::AffectedPackage.count
                                                      }.by(import_data.size)
    end

    context 'when error occurs' do
      let(:valid_advisory) do
        build(:pm_advisory_data_object, advisory_xid: 'valid-advisory',
          affected_packages: [build(:pm_affected_package_data_object,
            package_name: 'package-with-valid-advisory')])
      end

      let(:invalid_advisory) do
        build(:pm_advisory_data_object, identifiers: [{ key: 'invalid-json' }], advisory_xid: 'invalid-advisory',
          affected_packages: [build(:pm_affected_package_data_object,
            package_name: 'package-with-invalid-advisory')])
      end

      let(:import_data) { [invalid_advisory, valid_advisory] }

      context 'when an advisory fails json validation but the affected packages are valid' do
        it 'does not create DB records for the affected package belonging to the invalid advisory' do
          execute

          expect(PackageMetadata::AffectedPackage.where(package_name: 'package-with-invalid-advisory')).not_to exist
        end

        it 'only adds a single advisory and affected package to the DB' do
          expect { execute }
            .to change { PackageMetadata::Advisory.count }.from(0).to(1)
            .and change { PackageMetadata::AffectedPackage.count }.from(0).to(1)
        end

        it 'associates the affected package with the parent advisory' do
          execute

          advisory = PackageMetadata::Advisory.where(advisory_xid: valid_advisory.advisory_xid).first
          expect(advisory.affected_packages.first.package_name).to eql('package-with-valid-advisory')
        end
      end

      context 'when the error is unrecoverable' do
        it 'rolls back changes' do
          expect(PackageMetadata::Ingestion::Advisory::AdvisoryIngestionTask)
            .to receive(:execute).and_raise(StandardError)
          expect { execute }
          .to raise_error(StandardError)
          .and not_change(PackageMetadata::AffectedPackage, :count)
          .and not_change(PackageMetadata::Advisory, :count)
        end
      end
    end
  end
end
