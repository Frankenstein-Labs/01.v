# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers to define tables
RSpec.describe Gitlab::BackgroundMigration::FixIncompleteInstanceExternalAuditDestinationsV2, feature_category: :audit_events do
  let(:connection) { ApplicationRecord.connection }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:legacy_table) { table(:audit_events_instance_external_audit_event_destinations) }
  let(:streaming_table) { table(:audit_events_instance_external_streaming_destinations) }
  let(:event_type_filters_table) { table(:audit_events_streaming_instance_event_type_filters) }
  let(:instance_event_type_filters_table) { table(:audit_events_instance_streaming_event_type_filters) }
  let(:namespace_filters_table) { table(:audit_events_streaming_http_instance_namespace_filters) }
  let(:instance_namespace_filters_table) { table(:audit_events_streaming_instance_namespace_filters) }
  let(:headers_table) { table(:instance_audit_events_streaming_headers) }

  let(:encryption_key) { 'a' * 32 }

  let(:organization) { organizations_table.create!(name: 'test-org', path: 'test-org') }
  let!(:namespace) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'test-group',
      path: 'test-group',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let!(:project) { create_project('test-project', namespace) }

  let!(:unmigrated_destination) do
    legacy_table.create!(
      name: "Unmigrated Destination",
      destination_url: "https://example.com/unmigrated",
      encrypted_verification_token: 'a' * 32,
      encrypted_verification_token_iv: 'a' * 12,
      stream_destination_id: nil,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  let!(:complex_destination) do
    legacy_table.create!(
      name: "Complex Destination",
      destination_url: "https://example.com/complex",
      encrypted_verification_token: 'b' * 32,
      encrypted_verification_token_iv: 'b' * 12,
      stream_destination_id: nil,
      created_at: 4.days.ago,
      updated_at: 3.days.ago
    )
  end

  let!(:partially_migrated_destination) do
    dest = legacy_table.create!(
      name: "Partially Migrated Destination",
      destination_url: "https://example.com/partial",
      encrypted_verification_token: 'c' * 32,
      encrypted_verification_token_iv: 'c' * 12,
      created_at: 5.days.ago,
      updated_at: 4.days.ago
    )

    stream_dest = streaming_table.create!(
      name: dest.name,
      category: 0,
      config: {
        'url' => dest.destination_url,
        'headers' => {
          'X-Gitlab-Event-Streaming-Token' => {
            'value' => 'decrypted-token',
            'active' => true
          }
        }
      },
      encrypted_secret_token: 'encrypted-secret-1',
      encrypted_secret_token_iv: 'a' * 12,
      legacy_destination_ref: dest.id,
      created_at: dest.created_at,
      updated_at: dest.updated_at
    )

    dest.update!(stream_destination_id: stream_dest.id)
    dest
  end

  let!(:broken_encryption_destination) do
    legacy_table.create!(
      name: "Broken Encryption Destination",
      destination_url: "https://example.com/broken",
      encrypted_verification_token: 'short',
      encrypted_verification_token_iv: 'invalid-iv-data',
      stream_destination_id: nil,
      created_at: 6.days.ago,
      updated_at: 6.days.ago
    )
  end

  let!(:complex_destination_headers) do
    [
      { key: 'X-Custom-Header-1', value: 'value-1', active: true },
      { key: 'X-Custom-Header-2', value: 'value-2', active: false }
    ].map do |header|
      headers_table.create!(
        instance_external_audit_event_destination_id: complex_destination.id,
        key: header[:key],
        value: header[:value],
        active: header[:active],
        created_at: 3.days.ago,
        updated_at: 3.days.ago
      )
    end
  end

  let!(:complex_destination_event_filters) do
    %w[user_created group_created project_created].map do |event_type|
      event_type_filters_table.create!(
        instance_external_audit_event_destination_id: complex_destination.id,
        audit_event_type: event_type,
        created_at: 3.days.ago,
        updated_at: 3.days.ago
      )
    end
  end

  let!(:complex_destination_namespace_filter) do
    namespace_filters_table.create!(
      audit_events_instance_external_audit_event_destination_id: complex_destination.id,
      namespace_id: namespace.id,
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
  end

  let!(:missing_event_filter) do
    event_type_filters_table.create!(
      instance_external_audit_event_destination_id: partially_migrated_destination.id,
      audit_event_type: 'user_updated',
      created_at: 4.days.ago,
      updated_at: 4.days.ago
    )
  end

  let!(:existing_event_filter) do
    instance_event_type_filters_table.create!(
      external_streaming_destination_id: partially_migrated_destination.stream_destination_id,
      audit_event_type: 'group_created',
      created_at: 4.days.ago,
      updated_at: 4.days.ago
    )
  end

  let!(:missing_header) do
    headers_table.create!(
      instance_external_audit_event_destination_id: partially_migrated_destination.id,
      key: 'X-Missing-Header',
      value: 'missing-value',
      active: true,
      created_at: 4.days.ago,
      updated_at: 4.days.ago
    )
  end

  let(:migration) do
    described_class.new(
      start_id: legacy_table.minimum(:id),
      end_id: legacy_table.maximum(:id),
      batch_table: :audit_events_instance_external_audit_event_destinations,
      batch_column: :id,
      sub_batch_size: 5,
      pause_ms: 0,
      connection: connection
    )
  end

  def create_project(name, group)
    project_namespace = namespaces_table.create!(
      name: name,
      path: name,
      type: 'Project',
      organization_id: group.organization_id
    )

    table(:projects).create!(
      organization_id: group.organization_id,
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      name: name,
      path: name
    )
  end

  before(:context) do
    encryption_key = 'a' * 32

    described_class::InstanceStreamingDestination.class_eval do
      define_method(:db_key_base_32) do
        encryption_key
      end
    end

    described_class::InstanceExternalAuditEventDestination.class_eval do
      define_method(:db_key_base_32) do
        encryption_key
      end
    end
  end

  before do
    allow(SecureRandom).to receive(:base58).with(18).and_return("newly-generated-token")
  end

  it_behaves_like 'encrypted attribute', :verification_token, :db_key_base_32 do
    let(:record) { described_class::InstanceExternalAuditEventDestination.new }
  end

  it_behaves_like 'encrypted attribute', :secret_token, :db_key_base_32 do
    let(:record) { described_class::InstanceStreamingDestination.new }
  end

  describe '#perform' do
    it 'creates streaming destinations for all unmigrated records including broken encryption' do
      expect { migration.perform }.to change { streaming_table.count }.by(3)

      unmigrated_destination.reload
      complex_destination.reload
      broken_encryption_destination.reload

      expect(unmigrated_destination.stream_destination_id).to be_present
      expect(complex_destination.stream_destination_id).to be_present
      expect(broken_encryption_destination.stream_destination_id).to be_present
    end

    it 'generates new tokens for destinations with broken encryption' do
      broken_migration = described_class.new(
        start_id: broken_encryption_destination.id,
        end_id: broken_encryption_destination.id,
        batch_table: :audit_events_instance_external_audit_event_destinations,
        batch_column: :id,
        sub_batch_size: 1,
        pause_ms: 0,
        connection: connection
      )

      expect { broken_migration.perform }.to change { streaming_table.count }.by(1)

      broken_encryption_destination.reload
      expect(broken_encryption_destination.stream_destination_id).to be_present

      stream_dest = streaming_table.find(broken_encryption_destination.stream_destination_id)
      expect(stream_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
        .to eq('newly-generated-token')
    end

    it 'properly migrates config from legacy destination' do
      migration.perform

      unmigrated_destination.reload
      stream_dest = streaming_table.find(unmigrated_destination.stream_destination_id)

      expect(stream_dest.name).to eq(unmigrated_destination.name)
      expect(stream_dest.category).to eq(0)
      expect(stream_dest.config['url']).to eq(unmigrated_destination.destination_url)
      expect(stream_dest.config['headers']).to include('X-Gitlab-Event-Streaming-Token')
    end

    it 'migrates custom headers correctly' do
      migration.perform

      complex_destination.reload
      stream_dest = streaming_table.find(complex_destination.stream_destination_id)

      headers = stream_dest.config['headers']
      expect(headers.keys).to include('X-Custom-Header-1', 'X-Custom-Header-2')
      expect(headers['X-Custom-Header-1']['value']).to eq('value-1')
      expect(headers['X-Custom-Header-1']['active']).to be true
      expect(headers['X-Custom-Header-2']['value']).to eq('value-2')
      expect(headers['X-Custom-Header-2']['active']).to be false
    end

    it 'migrates event type filters correctly' do
      expect { migration.perform }.to change { instance_event_type_filters_table.count }.by(4)

      complex_destination.reload
      filters = instance_event_type_filters_table.where(
        external_streaming_destination_id: complex_destination.stream_destination_id
      )

      expect(filters.count).to eq(3)
      expect(filters.pluck(:audit_event_type)).to match_array(%w[user_created group_created project_created])
    end

    it 'migrates namespace filters correctly' do
      expect { migration.perform }.to change { instance_namespace_filters_table.count }.by(1)

      complex_destination.reload

      complex_filters = instance_namespace_filters_table.where(
        external_streaming_destination_id: complex_destination.stream_destination_id
      )
      expect(complex_filters.count).to eq(1)
      expect(complex_filters.first.namespace_id).to eq(namespace.id)
    end

    it 'syncs missing data for partially migrated destinations' do
      migration.perform

      partially_migrated_destination.reload
      stream_dest = streaming_table.find(partially_migrated_destination.stream_destination_id)

      headers = stream_dest.config['headers']
      expect(headers).to include('X-Missing-Header')
      expect(headers['X-Missing-Header']['value']).to eq('missing-value')
      expect(headers['X-Missing-Header']['active']).to be true

      filters = instance_event_type_filters_table.where(
        external_streaming_destination_id: partially_migrated_destination.stream_destination_id
      )
      expect(filters.pluck(:audit_event_type)).to include('user_updated', 'group_created')
    end

    it 'correctly handles validation cases when decrypting verification tokens' do
      test_migration = described_class.new(
        start_id: 1,
        end_id: 10,
        batch_table: :audit_events_instance_external_audit_event_destinations,
        batch_column: :id,
        sub_batch_size: 5,
        pause_ms: 0,
        connection: connection
      )

      valid_dest = legacy_table.create!(
        name: "Valid Encryption Destination",
        destination_url: "https://example.com/valid",
        encrypted_verification_token: 'x' * 32,
        encrypted_verification_token_iv: 'b' * 12,
        stream_destination_id: nil
      )

      empty_dest = legacy_table.create!(
        name: "Empty Encryption Destination",
        destination_url: "https://example.com/empty",
        encrypted_verification_token: '',
        encrypted_verification_token_iv: 'c' * 12,
        stream_destination_id: nil
      )

      invalid_dest = legacy_table.create!(
        name: "Invalid Data Destination",
        destination_url: "https://example.com/invalid",
        encrypted_verification_token: 'y' * 32,
        encrypted_verification_token_iv: 'd' * 12,
        stream_destination_id: nil
      )

      allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt)
        .with(valid_dest.encrypted_verification_token, nonce: valid_dest.encrypted_verification_token_iv)
        .and_return("decrypted-test-token")

      allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt)
        .with(invalid_dest.encrypted_verification_token, nonce: invalid_dest.encrypted_verification_token_iv)
        .and_raise(TypeError, "no implicit conversion of nil into String")

      expect(test_migration.send(:decrypt_verification_token, valid_dest)).to eq("decrypted-test-token")
      expect(test_migration.send(:decrypt_verification_token, empty_dest)).to be_nil
      expect(test_migration.send(:decrypt_verification_token, invalid_dest)).to be_nil
    end

    it 'generates new tokens for destinations with empty token data' do
      empty_token_dest = legacy_table.create!(
        name: "Empty Token Destination",
        destination_url: "https://example.com/empty-token",
        encrypted_verification_token: '',
        encrypted_verification_token_iv: 'e' * 12,
        stream_destination_id: nil
      )

      migration_for_empty = described_class.new(
        start_id: empty_token_dest.id,
        end_id: empty_token_dest.id,
        batch_table: :audit_events_instance_external_audit_event_destinations,
        batch_column: :id,
        sub_batch_size: 1,
        pause_ms: 0,
        connection: connection
      )

      expect { migration_for_empty.perform }.to change { streaming_table.count }.by(1)

      empty_token_dest.reload
      expect(empty_token_dest.stream_destination_id).to be_present

      stream_dest = streaming_table.find(empty_token_dest.stream_destination_id)
      expect(stream_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
        .to eq('newly-generated-token')
    end

    it 'validates token bytesize before attempting decryption' do
      short_token_dest = legacy_table.create!(
        name: "Short Token Destination",
        destination_url: "https://example.com/short",
        encrypted_verification_token: 'x' * 10,
        encrypted_verification_token_iv: 'iv-short',
        stream_destination_id: nil
      )

      test_migration = described_class.new(
        start_id: short_token_dest.id,
        end_id: short_token_dest.id,
        batch_table: :audit_events_instance_external_audit_event_destinations,
        batch_column: :id,
        sub_batch_size: 1,
        pause_ms: 0,
        connection: connection
      )

      expect(::Gitlab::CryptoHelper).not_to receive(:aes256_gcm_decrypt)

      test_migration.perform

      short_token_dest.reload
      expect(short_token_dest.stream_destination_id).to be_present

      stream_dest = streaming_table.find(short_token_dest.stream_destination_id)
      expect(stream_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
        .to eq('newly-generated-token')
    end

    context 'with error handling' do
      it 'tracks exceptions and continues processing other destinations' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception).at_least(:once)

        allow_next_instance_of(described_class::InstanceStreamingDestination) do |instance|
          allow(instance).to receive(:save!).and_raise(StandardError, "Simulated failure").once
        end

        expect { migration.perform }.not_to raise_error
      end
    end

    context 'with duplicate destination names' do
      let!(:existing_streaming_dest) do
        streaming_table.create!(
          name: "Duplicate Name",
          category: 0,
          config: {
            'url' => 'https://example.com/existing',
            'headers' => {
              'X-Gitlab-Event-Streaming-Token' => {
                'value' => 'existing-token',
                'active' => true
              }
            }
          },
          encrypted_secret_token: 'existing-token-encrypted',
          encrypted_secret_token_iv: 'existing-iv',
          created_at: 5.days.ago,
          updated_at: 4.days.ago
        )
      end

      let!(:duplicate_legacy_destination) do
        legacy_table.create!(
          name: "Duplicate Name",
          destination_url: "https://example.com/duplicate",
          encrypted_verification_token: 'dup' * 10,
          encrypted_verification_token_iv: 'duplicate-iv',
          stream_destination_id: nil,
          created_at: 2.days.ago,
          updated_at: 1.day.ago
        )
      end

      let(:migration) do
        described_class.new(
          start_id: duplicate_legacy_destination.id,
          end_id: duplicate_legacy_destination.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )
      end

      it 'reuses existing streaming destination with same name and category' do
        expect { migration.perform }.not_to change { streaming_table.count }

        duplicate_legacy_destination.reload
        expect(duplicate_legacy_destination.stream_destination_id).to eq(existing_streaming_dest.id)
      end

      it 'migrates filters to existing streaming destination' do
        event_type_filters_table.create!(
          instance_external_audit_event_destination_id: duplicate_legacy_destination.id,
          audit_event_type: 'user_updated',
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        )

        expect { migration.perform }.to change {
          instance_event_type_filters_table.where(external_streaming_destination_id: existing_streaming_dest.id).count
        }.by(1)

        migrated_filters = instance_event_type_filters_table
          .where(external_streaming_destination_id: existing_streaming_dest.id)
        expect(migrated_filters.pluck(:audit_event_type)).to include('user_updated')
      end
    end

    context 'with missing token in partially migrated destination' do
      let!(:no_token_dest) do
        dest = legacy_table.create!(
          name: "No Token Destination",
          destination_url: "https://example.com/no-token",
          encrypted_verification_token: 'no-token' * 4,
          encrypted_verification_token_iv: 'no-token-iv',
          created_at: 7.days.ago,
          updated_at: 7.days.ago
        )

        stream_dest = streaming_table.create!(
          name: dest.name,
          category: 0,
          config: {
            'url' => dest.destination_url,
            'headers' => {}
          },
          encrypted_secret_token: 'encrypted-secret-no-token',
          encrypted_secret_token_iv: 'no-token-iv',
          legacy_destination_ref: dest.id,
          created_at: dest.created_at,
          updated_at: dest.updated_at
        )

        dest.update!(stream_destination_id: stream_dest.id)
        dest
      end

      it 'adds missing token to headers during sync' do
        allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt)
          .with('no-token' * 4, nonce: 'no-token-iv')
          .and_return("recovered-token")

        headers_table.create!(
          instance_external_audit_event_destination_id: no_token_dest.id,
          key: 'X-Custom-Header',
          value: 'custom-value',
          active: true,
          created_at: 7.days.ago,
          updated_at: 7.days.ago
        )

        no_token_migration = described_class.new(
          start_id: no_token_dest.id,
          end_id: no_token_dest.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 1,
          pause_ms: 0,
          connection: connection
        )

        no_token_migration.perform

        no_token_dest.reload
        stream_dest = streaming_table.find(no_token_dest.stream_destination_id)

        headers = stream_dest.config['headers']
        expect(headers['X-Gitlab-Event-Streaming-Token']).to be_present
        expect(headers['X-Gitlab-Event-Streaming-Token']['value']).to eq('recovered-token')
        expect(headers['X-Gitlab-Event-Streaming-Token']['active']).to be true
        expect(headers['X-Custom-Header']).to be_present
      end
    end

    context 'with unique constraint violations' do
      it 'handles duplicate event type filters gracefully using insert_all unique_by' do
        duplicate_filter_dest = legacy_table.create!(
          name: "Duplicate Filter Destination",
          destination_url: "https://example.com/dup-filter",
          encrypted_verification_token: 'dup-filter' * 4,
          encrypted_verification_token_iv: 'dup-filter-iv',
          stream_destination_id: nil
        )

        event_type_filters_table.create!(
          instance_external_audit_event_destination_id: duplicate_filter_dest.id,
          audit_event_type: 'user_created',
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        )

        dup_migration = described_class.new(
          start_id: duplicate_filter_dest.id,
          end_id: duplicate_filter_dest.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 1,
          pause_ms: 0,
          connection: connection
        )

        expect { dup_migration.perform }.not_to raise_error

        duplicate_filter_dest.reload
        stream_dest = streaming_table.find(duplicate_filter_dest.stream_destination_id)

        filters = instance_event_type_filters_table.where(
          external_streaming_destination_id: stream_dest.id
        )
        expect(filters.count).to eq(1)
        expect(filters.first.audit_event_type).to eq('user_created')
      end

      it 'handles inserting filters when one already exists using insert_all unique_by' do
        mixed_filter_dest = legacy_table.create!(
          name: "Mixed Filter Destination",
          destination_url: "https://example.com/mixed",
          encrypted_verification_token: 'mixed' * 8,
          encrypted_verification_token_iv: 'mixed-iv',
          stream_destination_id: nil
        )

        %w[user_created group_created project_created].each do |event_type|
          event_type_filters_table.create!(
            instance_external_audit_event_destination_id: mixed_filter_dest.id,
            audit_event_type: event_type,
            created_at: 1.day.ago,
            updated_at: 1.day.ago
          )
        end

        mixed_migration = described_class.new(
          start_id: mixed_filter_dest.id,
          end_id: mixed_filter_dest.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 1,
          pause_ms: 0,
          connection: connection
        )

        mixed_migration.perform

        mixed_filter_dest.reload
        stream_dest = streaming_table.find(mixed_filter_dest.stream_destination_id)

        event_type_filters_table.create!(
          instance_external_audit_event_destination_id: mixed_filter_dest.id,
          audit_event_type: 'repository_created',
          created_at: 30.minutes.ago,
          updated_at: 30.minutes.ago
        )

        sync_migration = described_class.new(
          start_id: mixed_filter_dest.id,
          end_id: mixed_filter_dest.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 1,
          pause_ms: 0,
          connection: connection
        )

        expect { sync_migration.perform }.to change {
          instance_event_type_filters_table.where(external_streaming_destination_id: stream_dest.id).count
        }.by(1)

        filters = instance_event_type_filters_table.where(
          external_streaming_destination_id: stream_dest.id
        )
        expect(filters.pluck(:audit_event_type)).to match_array(
          %w[user_created group_created project_created repository_created]
        )
      end

      it 'handles duplicate namespace filters gracefully using insert_all unique_by' do
        duplicate_ns_dest = legacy_table.create!(
          name: "Duplicate NS Filter Destination",
          destination_url: "https://example.com/dup-ns",
          encrypted_verification_token: 'dup-ns' * 5,
          encrypted_verification_token_iv: 'dup-ns-iv',
          stream_destination_id: nil
        )

        namespace_filters_table.create!(
          audit_events_instance_external_audit_event_destination_id: duplicate_ns_dest.id,
          namespace_id: namespace.id,
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        )

        dup_ns_migration = described_class.new(
          start_id: duplicate_ns_dest.id,
          end_id: duplicate_ns_dest.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 1,
          pause_ms: 0,
          connection: connection
        )

        expect { dup_ns_migration.perform }.not_to raise_error

        duplicate_ns_dest.reload
        stream_dest = streaming_table.find(duplicate_ns_dest.stream_destination_id)

        filters = instance_namespace_filters_table.where(
          external_streaming_destination_id: stream_dest.id
        )
        expect(filters.count).to eq(1)
        expect(filters.first.namespace_id).to eq(namespace.id)
      end

      it 'handles inserting namespace filters when one already exists using insert_all unique_by' do
        namespace2 = namespaces_table.create!(
          organization_id: organization.id,
          name: 'test-group-2',
          path: 'test-group-2',
          type: 'Group'
        )
        namespace2.update!(traversal_ids: [namespace2.id])

        mixed_ns_dest1 = legacy_table.create!(
          name: "Mixed NS Filter Destination 1",
          destination_url: "https://example.com/mixed-ns-1",
          encrypted_verification_token: 'mixed-ns-1' * 5,
          encrypted_verification_token_iv: 'mixed-ns-iv-1',
          stream_destination_id: nil
        )

        namespace_filters_table.create!(
          audit_events_instance_external_audit_event_destination_id: mixed_ns_dest1.id,
          namespace_id: namespace.id,
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        )

        mixed_ns_dest2 = legacy_table.create!(
          name: "Mixed NS Filter Destination 2",
          destination_url: "https://example.com/mixed-ns-2",
          encrypted_verification_token: 'mixed-ns-2' * 5,
          encrypted_verification_token_iv: 'mixed-ns-iv-2',
          stream_destination_id: nil
        )

        namespace_filters_table.create!(
          audit_events_instance_external_audit_event_destination_id: mixed_ns_dest2.id,
          namespace_id: namespace2.id,
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        )

        mixed_ns_migration = described_class.new(
          start_id: [mixed_ns_dest1.id, mixed_ns_dest2.id].min,
          end_id: [mixed_ns_dest1.id, mixed_ns_dest2.id].max,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )

        expect { mixed_ns_migration.perform }.to change {
          instance_namespace_filters_table.count
        }.by(2)

        mixed_ns_dest1.reload
        mixed_ns_dest2.reload

        filters1 = instance_namespace_filters_table.where(
          external_streaming_destination_id: mixed_ns_dest1.stream_destination_id
        )
        expect(filters1.count).to eq(1)
        expect(filters1.first.namespace_id).to eq(namespace.id)

        filters2 = instance_namespace_filters_table.where(
          external_streaming_destination_id: mixed_ns_dest2.stream_destination_id
        )
        expect(filters2.count).to eq(1)
        expect(filters2.first.namespace_id).to eq(namespace2.id)
      end
    end

    context 'with different encryption errors' do
      let(:error_migration) do
        described_class.new(
          start_id: [unmigrated_destination.id, complex_destination.id, broken_encryption_destination.id].min,
          end_id: [unmigrated_destination.id, complex_destination.id, broken_encryption_destination.id].max,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )
      end

      it 'handles TypeError and generates new token' do
        allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt).and_raise(TypeError)

        expect { error_migration.perform }.to change { streaming_table.count }.by(3)

        unmigrated_destination.reload
        stream_dest = streaming_table.find(unmigrated_destination.stream_destination_id)
        expect(stream_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
          .to eq('newly-generated-token')
      end

      it 'handles ArgumentError and generates new token' do
        allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt).and_raise(ArgumentError)

        expect { error_migration.perform }.to change { streaming_table.count }.by(3)

        unmigrated_destination.reload
        stream_dest = streaming_table.find(unmigrated_destination.stream_destination_id)
        expect(stream_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
          .to eq('newly-generated-token')
      end

      it 'handles OpenSSL::Cipher::CipherError and generates new token' do
        allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt)
          .and_raise(OpenSSL::Cipher::CipherError)

        expect { error_migration.perform }.to change { streaming_table.count }.by(3)

        unmigrated_destination.reload
        stream_dest = streaming_table.find(unmigrated_destination.stream_destination_id)
        expect(stream_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
          .to eq('newly-generated-token')
      end

      it 'handles StandardError and generates new token' do
        allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt)
          .and_raise(StandardError, "Unexpected error")

        expect { error_migration.perform }.to change { streaming_table.count }.by(3)

        unmigrated_destination.reload
        stream_dest = streaming_table.find(unmigrated_destination.stream_destination_id)
        expect(stream_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
          .to eq('newly-generated-token')
      end
    end

    context 'with sub-batching' do
      let!(:additional_destinations) do
        (1..6).map do |i|
          legacy_table.create!(
            name: "Batch Destination #{i}",
            destination_url: "https://example.com/batch-#{i}",
            encrypted_verification_token: "batch-#{i}" * 6,
            encrypted_verification_token_iv: "batch-iv-#{i}",
            stream_destination_id: nil
          )
        end
      end

      it 'processes records in sub-batches' do
        sub_batch_migration = described_class.new(
          start_id: additional_destinations.map(&:id).min,
          end_id: additional_destinations.map(&:id).max,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 2,
          pause_ms: 0,
          connection: connection
        )

        expect { sub_batch_migration.perform }.to change { streaming_table.count }.by(6)

        additional_destinations.each do |dest|
          dest.reload
          expect(dest.stream_destination_id).to be_present
        end
      end
    end

    context 'with namespace filter synchronization' do
      let!(:namespace2) do
        namespaces_table.create!(
          organization_id: organization.id,
          name: 'test-group-2',
          path: 'test-group-2',
          type: 'Group'
        ).tap { |ns| ns.update!(traversal_ids: [ns.id]) }
      end

      let!(:namespace3) do
        namespaces_table.create!(
          organization_id: organization.id,
          name: 'test-group-3',
          path: 'test-group-3',
          type: 'Group'
        ).tap { |ns| ns.update!(traversal_ids: [ns.id]) }
      end

      let!(:sync_ns_destination_1) do
        dest = legacy_table.create!(
          name: "Namespace Sync Destination 1",
          destination_url: "https://example.com/ns-sync-1",
          encrypted_verification_token: 'ns-sync-1' * 5,
          encrypted_verification_token_iv: 'ns-sync-iv-1',
          created_at: 3.days.ago,
          updated_at: 2.days.ago
        )

        stream_dest = streaming_table.create!(
          name: dest.name,
          category: 0,
          config: {
            'url' => dest.destination_url,
            'headers' => {
              'X-Gitlab-Event-Streaming-Token' => {
                'value' => 'ns-sync-token-1',
                'active' => true
              }
            }
          },
          encrypted_secret_token: 'ns-sync-secret-1',
          encrypted_secret_token_iv: 'ns-sync-iv-1',
          legacy_destination_ref: dest.id,
          created_at: dest.created_at,
          updated_at: dest.updated_at
        )

        dest.update!(stream_destination_id: stream_dest.id)

        namespace_filters_table.create!(
          audit_events_instance_external_audit_event_destination_id: dest.id,
          namespace_id: namespace.id,
          created_at: 3.days.ago,
          updated_at: 3.days.ago
        )

        instance_namespace_filters_table.create!(
          external_streaming_destination_id: stream_dest.id,
          namespace_id: namespace.id,
          created_at: 3.days.ago,
          updated_at: 3.days.ago
        )

        dest
      end

      let!(:sync_ns_destination_2) do
        dest = legacy_table.create!(
          name: "Namespace Sync Destination 2",
          destination_url: "https://example.com/ns-sync-2",
          encrypted_verification_token: 'ns-sync-2' * 5,
          encrypted_verification_token_iv: 'ns-sync-iv-2',
          created_at: 3.days.ago,
          updated_at: 2.days.ago
        )

        stream_dest = streaming_table.create!(
          name: dest.name,
          category: 0,
          config: {
            'url' => dest.destination_url,
            'headers' => {
              'X-Gitlab-Event-Streaming-Token' => {
                'value' => 'ns-sync-token-2',
                'active' => true
              }
            }
          },
          encrypted_secret_token: 'ns-sync-secret-2',
          encrypted_secret_token_iv: 'ns-sync-iv-2',
          legacy_destination_ref: dest.id,
          created_at: dest.created_at,
          updated_at: dest.updated_at
        )

        dest.update!(stream_destination_id: stream_dest.id)

        namespace_filters_table.create!(
          audit_events_instance_external_audit_event_destination_id: dest.id,
          namespace_id: namespace2.id,
          created_at: 3.days.ago,
          updated_at: 3.days.ago
        )

        dest
      end

      it 'syncs only missing namespace filters' do
        migration = described_class.new(
          start_id: sync_ns_destination_2.id,
          end_id: sync_ns_destination_2.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )

        expect { migration.perform }.to change {
          instance_namespace_filters_table.where(
            external_streaming_destination_id: sync_ns_destination_2.stream_destination_id
          ).count
        }.by(1)

        sync_ns_destination_2.reload
        stream_dest = streaming_table.find(sync_ns_destination_2.stream_destination_id)

        filters = instance_namespace_filters_table.where(
          external_streaming_destination_id: stream_dest.id
        )

        expect(filters.count).to eq(1)
        expect(filters.pluck(:namespace_id)).to match_array([namespace2.id])
      end

      it 'does not create duplicates when filter already exists' do
        migration = described_class.new(
          start_id: sync_ns_destination_1.id,
          end_id: sync_ns_destination_1.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )

        initial_count = instance_namespace_filters_table.where(
          external_streaming_destination_id: sync_ns_destination_1.stream_destination_id
        ).count

        expect { migration.perform }.not_to change {
          instance_namespace_filters_table.where(
            external_streaming_destination_id: sync_ns_destination_1.stream_destination_id
          ).count
        }

        expect(instance_namespace_filters_table.where(
          external_streaming_destination_id: sync_ns_destination_1.stream_destination_id
        ).count).to eq(initial_count)
      end
    end

    context 'with race condition on streaming destination creation' do
      let!(:concurrent_destination) do
        legacy_table.create!(
          name: "Concurrent Destination",
          destination_url: "https://example.com/concurrent",
          encrypted_verification_token: 'concurrent' * 4,
          encrypted_verification_token_iv: 'concurrent-iv',
          stream_destination_id: nil,
          created_at: 2.days.ago,
          updated_at: 1.day.ago
        )
      end

      let(:migration) do
        described_class.new(
          start_id: concurrent_destination.id,
          end_id: concurrent_destination.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )
      end

      it 'handles RecordNotUnique by finding existing destination' do
        existing_dest = streaming_table.create!(
          name: concurrent_destination.name,
          category: 0,
          config: {
            'url' => concurrent_destination.destination_url,
            'headers' => {
              'X-Gitlab-Event-Streaming-Token' => {
                'value' => 'existing-token',
                'active' => true
              }
            }
          },
          encrypted_secret_token: 'existing-secret',
          encrypted_secret_token_iv: 'existing-iv',
          created_at: concurrent_destination.created_at,
          updated_at: concurrent_destination.updated_at
        )

        find_by_call_count = 0

        allow(described_class::InstanceStreamingDestination).to receive(:find_by).and_wrap_original do |method, *args|
          find_by_call_count += 1

          if args[0].is_a?(Hash) &&
              args[0][:name] == concurrent_destination.name &&
              args[0][:category] == :http

            if find_by_call_count == 1
              nil
            else
              method.call(*args)
            end
          else
            method.call(*args)
          end
        end

        allow(described_class::InstanceStreamingDestination).to receive(:find_or_create_by!)
          .and_raise(ActiveRecord::RecordNotUnique)

        expect { migration.perform }.not_to raise_error

        concurrent_destination.reload
        expect(concurrent_destination.stream_destination_id).to eq(existing_dest.id)
      end
    end

    context 'with optimistic locking conflict on header sync' do
      let!(:header_sync_destination) do
        dest = legacy_table.create!(
          name: "Header Sync Destination",
          destination_url: "https://example.com/header-sync",
          encrypted_verification_token: 'header-sync' * 4,
          encrypted_verification_token_iv: 'header-sync-iv',
          created_at: 3.days.ago,
          updated_at: 2.days.ago
        )

        stream_dest = streaming_table.create!(
          name: dest.name,
          category: 0,
          config: {
            'url' => dest.destination_url,
            'headers' => {
              'X-Gitlab-Event-Streaming-Token' => {
                'value' => 'original-token',
                'active' => true
              }
            }
          },
          encrypted_secret_token: 'original-secret',
          encrypted_secret_token_iv: 'original-iv',
          legacy_destination_ref: dest.id,
          created_at: dest.created_at,
          updated_at: dest.updated_at
        )

        dest.update!(stream_destination_id: stream_dest.id)
        dest
      end

      let(:migration) do
        described_class.new(
          start_id: header_sync_destination.id,
          end_id: header_sync_destination.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )
      end

      before do
        headers_table.create!(
          instance_external_audit_event_destination_id: header_sync_destination.id,
          key: 'X-Stale-Header',
          value: 'stale-value',
          active: true,
          created_at: 3.days.ago,
          updated_at: 3.days.ago
        )
      end

      it 'handles StaleObjectError by refetching and retrying' do
        streaming_dest_id = header_sync_destination.stream_destination_id

        update_call_count = 0

        allow(described_class::InstanceStreamingDestination).to receive(:find_by)
          .and_wrap_original do |original_method, *args, &block|
          instance = original_method.call(*args, &block)

          if instance&.id == streaming_dest_id
            allow(instance).to receive(:update!) do |new_attrs|
              update_call_count += 1
              raise ActiveRecord::StaleObjectError.new(instance, 'update') if update_call_count == 1

              instance.update_columns(new_attrs)
            end
          end

          instance
        end

        allow(described_class::InstanceStreamingDestination).to receive(:find)
          .and_wrap_original do |original_method, *args, &block|
          instance = original_method.call(*args, &block)

          allow(instance).to receive(:update!).and_wrap_original do |_orig, new_attrs|
            instance.update_columns(new_attrs)
          end

          instance
        end

        expect { migration.perform }.not_to raise_error

        streaming_dest = streaming_table.find(streaming_dest_id)
        expect(streaming_dest.config['headers']).to have_key('X-Stale-Header')
        expect(streaming_dest.config['headers']['X-Stale-Header']['value']).to eq('stale-value')
      end
    end

    context 'with multiple concurrent race conditions' do
      let!(:race_destination) do
        dest = legacy_table.create!(
          name: "Race Condition Destination",
          destination_url: "https://example.com/race",
          encrypted_verification_token: 'race' * 8,
          encrypted_verification_token_iv: 'race-iv',
          stream_destination_id: nil,
          created_at: 2.days.ago,
          updated_at: 1.day.ago
        )

        namespace_filters_table.create!(
          audit_events_instance_external_audit_event_destination_id: dest.id,
          namespace_id: namespace.id,
          created_at: 2.days.ago,
          updated_at: 2.days.ago
        )

        event_type_filters_table.create!(
          instance_external_audit_event_destination_id: dest.id,
          audit_event_type: 'user_created',
          created_at: 2.days.ago,
          updated_at: 2.days.ago
        )

        dest
      end

      let(:migration) do
        described_class.new(
          start_id: race_destination.id,
          end_id: race_destination.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )
      end

      it 'handles multiple race conditions and completes migration' do
        existing_dest = streaming_table.create!(
          name: race_destination.name,
          category: 0,
          config: {
            'url' => race_destination.destination_url,
            'headers' => {
              'X-Gitlab-Event-Streaming-Token' => {
                'value' => 'race-token',
                'active' => true
              }
            }
          },
          encrypted_secret_token: 'race-secret',
          encrypted_secret_token_iv: 'race-iv',
          created_at: race_destination.created_at,
          updated_at: race_destination.updated_at
        )

        find_by_call_count = 0

        allow(described_class::InstanceStreamingDestination).to receive(:find_by).and_wrap_original do |method, *args|
          find_by_call_count += 1

          if args[0].is_a?(Hash) &&
              args[0][:name] == race_destination.name &&
              args[0][:category] == :http

            if find_by_call_count == 1
              nil
            else
              method.call(*args)
            end
          else
            method.call(*args)
          end
        end

        allow(described_class::InstanceStreamingDestination).to receive(:find_or_create_by!)
          .and_raise(ActiveRecord::RecordNotUnique)

        expect { migration.perform }.not_to raise_error

        race_destination.reload
        expect(race_destination.stream_destination_id).to eq(existing_dest.id)

        migrated_filters = instance_event_type_filters_table
          .where(external_streaming_destination_id: existing_dest.id)
        expect(migrated_filters.count).to eq(1)
        expect(migrated_filters.pluck(:audit_event_type)).to include('user_created')
      end
    end

    context 'with idempotency on race conditions' do
      let!(:idempotent_destination) do
        legacy_table.create!(
          name: "Idempotent Destination",
          destination_url: "https://example.com/idempotent",
          encrypted_verification_token: 'idempotent' * 4,
          encrypted_verification_token_iv: 'idempotent-iv',
          stream_destination_id: nil,
          created_at: 2.days.ago,
          updated_at: 1.day.ago
        )
      end

      it 'handles repeated runs without errors' do
        migration = described_class.new(
          start_id: idempotent_destination.id,
          end_id: idempotent_destination.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )

        expect { migration.perform }.to change { streaming_table.count }.by(1)

        idempotent_destination.reload
        expect(idempotent_destination.stream_destination_id).not_to be_nil

        second_migration = described_class.new(
          start_id: idempotent_destination.id,
          end_id: idempotent_destination.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )

        expect { second_migration.perform }.not_to raise_error
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
