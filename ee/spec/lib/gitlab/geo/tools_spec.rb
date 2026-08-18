# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::Tools, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  before do
    stub_secondary_node
  end

  describe '.cleanup_check' do
    context 'when a known error is detected' do
      before do
        create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: Host cannot be resolved')
      end

      it 'lists the detected error with its count and a resolve hint' do
        expect { described_class.cleanup_check }.to output(
          a_string_including('Geo Cleanup Check -- Secondary Site')
            .and(a_string_including('Download URL blocked (warning)'))
            .and(a_string_including("1 records matching 'URL is blocked'"))
            .and(a_string_including('geo:tools:resolve[url_blocked]'))
            .and(a_string_including('Add DRY_RUN=false'))
        ).to_stdout
      end

      it 'checks only the given error when one is passed' do
        known_error = Geo::Tools::KnownErrors.find('duplicate_registries')

        expect { described_class.cleanup_check(known_error) }.to output(
          a_string_including("Scanning for 'duplicate_registries'")
            .and(a_string_including('No known issues detected.'))
        ).to_stdout
      end
    end

    context 'when a detected error has no match_pattern (structural check)' do
      before do
        package_file = create(:package_file)
        create(:geo_package_file_registry, :synced, package_file: package_file)
        create(:geo_package_file_registry, :failed, package_file: package_file)
      end

      it 'describes the count as a structural check rather than a blank pattern match' do
        expect { described_class.cleanup_check }.to output(
          a_string_including('Duplicate registries (warning)')
            .and(a_string_including('1 records affected (structural check)'))
            .and(a_string_including('geo:tools:resolve[duplicate_registries]'))
        ).to_stdout
      end
    end

    context 'when a primary-side error is detected' do
      before do
        # The outer before stubs a secondary, and stub_current_geo_node alone does not undo
        # the Gitlab::Geo.primary? stub.
        stub_primary_node
        stub_current_geo_node(create(:geo_node, :primary))

        upload = create(:upload, :verification_failed,
          verification_failure: 'File is not checksummable - file does not exist at: /var/opt/x.png')
        # The resolution only reports records that have failed verification repeatedly; the
        # factory leaves the count NULL.
        upload.upload_state.update!(
          verification_retry_count: Geo::Tools::Resolutions::DestroyReplicablesWithMissingFiles::DEFAULT_MIN_RETRY_COUNT
        )
        FileUtils.rm_f(upload.absolute_path)
      end

      it 'lists the missing file error with its count and a resolve hint' do
        expect { described_class.cleanup_check }.to output(
          a_string_including('Geo Cleanup Check -- Primary Site')
            .and(a_string_including('File is missing on the primary (warning)'))
            .and(a_string_including("1 records matching 'File is not checksummable - file does not exist at:'"))
            .and(a_string_including('geo:tools:resolve[file_missing_on_primary]'))
        ).to_stdout
      end
    end

    context 'when nothing is detected' do
      it 'reports no known issues' do
        expect { described_class.cleanup_check }.to output(
          a_string_including('No known issues detected.')
        ).to_stdout
      end
    end
  end

  describe '.resolve' do
    let(:known_error) { Geo::Tools::KnownErrors.find('url_blocked') }

    let!(:registry) do
      create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: Host cannot be resolved')
    end

    context 'with a dry run (default)' do
      it 'prints the dry-run header and a sample without acting' do
        expect(Geo::BulkRegistryResyncService).not_to receive(:new)

        expect { described_class.resolve(known_error) }.to output(
          a_string_including('Resolving Geo error: Download URL blocked (dry run mode ON)')
            .and(a_string_including('Sample of affected records'))
            .and(a_string_including('Dry run: 1 records would be affected'))
        ).to_stdout

        expect(registry.reload).to be_failed
      end

      it 'returns the service response' do
        expect(described_class.resolve(known_error)).to be_success
      end
    end

    context 'with a real run' do
      it 'prints the OFF header, delegates to the bulk resync service, and prints the summary' do
        expect(Geo::BulkRegistryResyncService)
          .to receive(:new)
          .with('Geo::PackageFileRegistry', ids: a_collection_including(registry.id))
          .and_call_original

        expect { described_class.resolve(known_error, dry_run: false) }.to output(
          a_string_including('Resolving Geo error: Download URL blocked (dry run mode OFF)')
            .and(a_string_including('Reset 1 failed registries to pending for resync.'))
        ).to_stdout
      end
    end
  end
end
