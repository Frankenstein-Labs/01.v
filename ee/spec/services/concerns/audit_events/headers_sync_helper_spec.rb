# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- Necessary for creating test records
RSpec.describe AuditEvents::HeadersSyncHelper, feature_category: :audit_events do
  let(:test_class) { Class.new { include AuditEvents::HeadersSyncHelper } }
  let(:helper) { test_class.new }

  describe '#sync_legacy_headers' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group,
        config: {
          'url' => 'http://example.com',
          'headers' => {
            'Header-1' => { 'value' => 'value-1', 'active' => true },
            'Header-2' => { 'value' => 'value-2', 'active' => false }
          }
        })
    end

    before do
      stream_destination.update_column(:legacy_destination_ref, legacy_destination.id)
      allow(stream_destination).to receive(:http?).and_return(true)
    end

    it 'creates headers in legacy destination' do
      expect do
        helper.sync_legacy_headers(stream_destination, legacy_destination)
      end.to change { AuditEvents::Streaming::Header.count }.by(2)

      headers = legacy_destination.headers.order(:key)

      expect(headers.map(&:key)).to contain_exactly('Header-1', 'Header-2')
      expect(headers.map(&:value)).to contain_exactly('value-1', 'value-2')
      expect(headers.map(&:active)).to contain_exactly(true, false)
    end

    it 'removes existing headers before syncing' do
      create(:audit_events_streaming_header,
        key: 'Old-Header',
        external_audit_event_destination: legacy_destination
      )

      expect do
        helper.sync_legacy_headers(stream_destination, legacy_destination)
      end.to change { AuditEvents::Streaming::Header.count }.by(1)
      expect(legacy_destination.headers.pluck(:key)).not_to include('Old-Header')
    end

    context 'with instance level destination' do
      let_it_be(:instance_destination) { create(:instance_external_audit_event_destination) }
      let_it_be_with_reload(:instance_stream_destination) do
        create(:audit_events_instance_external_streaming_destination, :http,
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Header-1' => { 'value' => 'value-1', 'active' => true }
            }
          })
      end

      before do
        instance_stream_destination.update_column(:legacy_destination_ref, instance_destination.id)
        allow(instance_stream_destination).to receive(:http?).and_return(true)
        allow(instance_destination).to receive(:instance_level?).and_return(true)
      end

      it 'creates instance headers' do
        expect do
          helper.sync_legacy_headers(instance_stream_destination, instance_destination)
        end.to change { AuditEvents::Streaming::InstanceHeader.count }.by(1)

        header = AuditEvents::Streaming::InstanceHeader.last
        expect(header.key).to eq('Header-1')
        expect(header.instance_external_audit_event_destination_id).to eq(instance_destination.id)
      end
    end

    context 'when error occurs' do
      let(:specific_exception) { StandardError.new('Test error') }

      before do
        allow(AuditEvents::Streaming::Header).to receive(:where).and_raise(specific_exception)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_legacy_headers(stream_destination, legacy_destination)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          specific_exception,
          audit_event_destination_model: stream_destination.class.name
        )
      end
    end
  end

  describe '#sync_header_to_streaming_destination' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group,
        config: { 'url' => 'http://example.com' })
    end

    let_it_be(:header) do
      create(:audit_events_streaming_header, key: 'Test-Header', value: 'test-value', active: true,
        external_audit_event_destination: legacy_destination)
    end

    before do
      legacy_destination.update_column(:stream_destination_id, stream_destination.id)
      allow(helper).to receive(:should_sync_http?).and_return(true)
      allow(legacy_destination).to receive(:stream_destination).and_return(stream_destination)
      allow(stream_destination).to receive(:update).and_return(true)
    end

    it 'creates or updates header in streaming destination' do
      expect(stream_destination).to receive(:update) do |args|
        expect(args[:config]['headers']['Test-Header']).to eq({
          'value' => 'test-value',
          'active' => true
        })
        true
      end

      helper.sync_header_to_streaming_destination(legacy_destination, header)
    end

    context 'when streaming destination already has headers' do
      before do
        stream_destination.update!(
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Existing-Header' => { 'value' => 'existing', 'active' => true }
            }
          }
        )
      end

      it 'adds new header to existing headers' do
        expect(stream_destination).to receive(:update) do |args|
          expect(args[:config]['headers']).to include(
            'Existing-Header' => { 'value' => 'existing', 'active' => true },
            'Test-Header' => { 'value' => 'test-value', 'active' => true }
          )
          true
        end

        helper.sync_header_to_streaming_destination(legacy_destination, header)
      end
    end

    context 'when old key is provided and different from current key' do
      before do
        stream_destination.update!(
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Old-Key' => { 'value' => 'old-value', 'active' => true }
            }
          }
        )
      end

      it 'removes old key and adds new key' do
        expect(stream_destination).to receive(:update) do |args|
          expect(args[:config]['headers']).not_to include('Old-Key')
          expect(args[:config]['headers']['Test-Header']).to eq({
            'value' => 'test-value',
            'active' => true
          })
          true
        end

        helper.sync_header_to_streaming_destination(legacy_destination, header, 'Old-Key')
      end
    end

    context 'when old key is same as current key' do
      before do
        stream_destination.update!(
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Test-Header' => { 'value' => 'old-value', 'active' => false }
            }
          }
        )
      end

      it 'does not remove the key, just updates it' do
        expect(stream_destination).to receive(:update) do |args|
          expect(args[:config]['headers']['Test-Header']).to eq({
            'value' => 'test-value',
            'active' => true
          })
          true
        end

        helper.sync_header_to_streaming_destination(legacy_destination, header, 'Test-Header')
      end
    end

    context 'when error occurs' do
      before do
        allow(stream_destination).to receive(:update).and_raise(StandardError.new("Test error"))
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_header_to_streaming_destination(legacy_destination, header)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: legacy_destination.class.name,
          header_id: header.id
        )
      end
    end
  end

  describe '#sync_header_deletion_to_streaming_destination' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group,
        config: {
          'url' => 'http://example.com',
          'headers' => {
            'Header-To-Delete' => { 'value' => 'value', 'active' => true },
            'Other-Header' => { 'value' => 'other-value', 'active' => true }
          }
        })
    end

    before do
      legacy_destination.update_column(:stream_destination_id, stream_destination.id)
      allow(helper).to receive(:should_sync_http?).and_return(true)
      allow(legacy_destination).to receive(:stream_destination).and_return(stream_destination)
      allow(stream_destination).to receive(:update).and_return(true)
    end

    it 'removes the specified header from config' do
      expect(stream_destination).to receive(:update) do |args|
        expect(args[:config]['headers']).not_to include('Header-To-Delete')
        expect(args[:config]['headers']).to include('Other-Header')
        true
      end

      helper.sync_header_deletion_to_streaming_destination(legacy_destination, 'Header-To-Delete')
    end

    context 'when header does not exist in config' do
      it 'does not update the destination' do
        expect(stream_destination).not_to receive(:update)

        helper.sync_header_deletion_to_streaming_destination(legacy_destination, 'Non-Existent-Header')
      end
    end

    context 'when error occurs' do
      before do
        allow(stream_destination).to receive(:update).and_raise(StandardError.new('Test error'))
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_header_deletion_to_streaming_destination(legacy_destination, 'Header-To-Delete')

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: legacy_destination.class.name,
          header_key: 'Header-To-Delete'
        )
      end
    end
  end

  describe '#sync_http_destination' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group,
        config: {
          'url' => 'http://example.com',
          'headers' => {
            'Other-Header' => { 'value' => 'other-value', 'active' => true }
          }
        })
    end

    before do
      stream_destination.update_column(:legacy_destination_ref, legacy_destination.id)
      allow(stream_destination).to receive(:http?).and_return(true)

      config = stream_destination.config.dup
      config['headers']['X-Gitlab-Event-Streaming-Token'] = { 'value' => 'token-value', 'active' => true }
      stream_destination.update_column(:config, config)

      streaming_token_header = build(:audit_events_streaming_header,
        key: 'X-Gitlab-Event-Streaming-Token',
        value: 'old-token',
        external_audit_event_destination: legacy_destination
      )
      streaming_token_header.save!(validate: false)

      create(:audit_events_streaming_header,
        key: 'Existing-Header',
        value: 'existing-value',
        external_audit_event_destination: legacy_destination
      )
    end

    it 'removes streaming token from stream destination config' do
      helper.sync_http_destination(stream_destination, legacy_destination)

      stream_destination.reload
      expect(stream_destination.config['headers']).not_to have_key('X-Gitlab-Event-Streaming-Token')
      expect(stream_destination.config['headers']).to have_key('Other-Header')
    end

    it 'syncs headers to legacy destination excluding streaming token' do
      helper.sync_http_destination(stream_destination, legacy_destination)

      legacy_headers = legacy_destination.headers.reload
      expect(legacy_headers.pluck(:key)).to contain_exactly('Other-Header')
      expect(legacy_headers.pluck(:key)).not_to include('X-Gitlab-Event-Streaming-Token')
    end

    it 'removes legacy streaming token headers' do
      expect do
        helper.sync_http_destination(stream_destination, legacy_destination)
      end.to change {
        legacy_destination.headers.where(key: 'X-Gitlab-Event-Streaming-Token').count
      }.from(1).to(0)
    end
  end

  describe '#remove_streaming_token_from_headers' do
    let(:stream_destination) do
      destination = create(:audit_events_group_external_streaming_destination,
        config: {
          'url' => 'http://example.com',
          'headers' => {
            'Other-Header' => { 'value' => 'other-value', 'active' => true }
          }
        })

      config = destination.config.dup
      config['headers']['X-Gitlab-Event-Streaming-Token'] = { 'value' => 'token-value', 'active' => true }
      destination.update_column(:config, config)
      destination
    end

    it 'removes streaming token header from config' do
      expect(stream_destination.config['headers']).to have_key('X-Gitlab-Event-Streaming-Token')

      helper.remove_streaming_token_from_headers(stream_destination)

      stream_destination.reload
      expect(stream_destination.config['headers']).not_to have_key('X-Gitlab-Event-Streaming-Token')
      expect(stream_destination.config['headers']).to have_key('Other-Header')
    end

    it 'preserves other headers' do
      helper.remove_streaming_token_from_headers(stream_destination)

      stream_destination.reload
      expect(stream_destination.config['headers']).to have_key('Other-Header')
      expect(stream_destination.config['headers']).not_to have_key('X-Gitlab-Event-Streaming-Token')
    end

    context 'when streaming token is the only header' do
      let(:stream_destination_with_only_token) do
        destination = create(:audit_events_group_external_streaming_destination,
          config: { 'url' => 'http://example.com' })

        config = destination.config.dup
        config['headers'] = { 'X-Gitlab-Event-Streaming-Token' => { 'value' => 'token-value', 'active' => true } }
        destination.update_column(:config, config)
        destination
      end

      it 'removes the headers key from config' do
        expect(stream_destination_with_only_token.config['headers']).to have_key('X-Gitlab-Event-Streaming-Token')

        helper.remove_streaming_token_from_headers(stream_destination_with_only_token)

        stream_destination_with_only_token.reload
        expect(stream_destination_with_only_token.config).not_to have_key('headers')
      end
    end

    context 'when no streaming token header exists' do
      let(:stream_destination_without_token) do
        create(:audit_events_group_external_streaming_destination,
          config: {
            'url' => 'http://example.com',
            'headers' => {
              'Other-Header' => { 'value' => 'other-value', 'active' => true }
            }
          })
      end

      it 'does not modify the config' do
        expect(stream_destination_without_token).not_to receive(:update_column)

        helper.remove_streaming_token_from_headers(stream_destination_without_token)
      end
    end

    context 'when no headers exist' do
      let(:stream_destination_no_headers) do
        create(:audit_events_group_external_streaming_destination,
          config: { 'url' => 'http://example.com' })
      end

      it 'does not modify the config' do
        expect(stream_destination_no_headers).not_to receive(:update_column)

        helper.remove_streaming_token_from_headers(stream_destination_no_headers)
      end
    end
  end

  describe '#remove_legacy_streaming_token_headers' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }

    before do
      streaming_token_header = build(:audit_events_streaming_header,
        key: 'X-Gitlab-Event-Streaming-Token',
        value: 'token-value',
        external_audit_event_destination: legacy_destination
      )
      streaming_token_header.save!(validate: false)

      create(:audit_events_streaming_header,
        key: 'Other-Header',
        value: 'other-value',
        external_audit_event_destination: legacy_destination
      )
    end

    it 'removes only streaming token headers' do
      expect do
        helper.remove_legacy_streaming_token_headers(legacy_destination)
      end.to change {
        legacy_destination.headers.where(key: 'X-Gitlab-Event-Streaming-Token').count
      }.from(1).to(0)

      expect(legacy_destination.headers.where(key: 'Other-Header')).to exist
    end

    context 'when destination does not respond to headers' do
      let(:destination_without_headers) { instance_double(AuditEvents::ExternalAuditEventDestination) }

      before do
        allow(destination_without_headers).to receive(:respond_to?).with(:headers).and_return(false)
      end

      it 'does not attempt to delete headers' do
        expect(destination_without_headers).not_to receive(:headers)

        helper.remove_legacy_streaming_token_headers(destination_without_headers)
      end
    end

    context 'when no streaming token headers exist' do
      let(:legacy_destination_no_token) { create(:external_audit_event_destination, group: group) }

      before do
        create(:audit_events_streaming_header,
          key: 'Other-Header',
          value: 'other-value',
          external_audit_event_destination: legacy_destination_no_token
        )
      end

      it 'does not affect other headers' do
        expect do
          helper.remove_legacy_streaming_token_headers(legacy_destination_no_token)
        end.not_to change { legacy_destination_no_token.headers.count }
      end
    end
  end

  describe 'header.destination' do
    let_it_be(:group) { create(:group) }

    context 'with regular header' do
      let!(:destination) { create(:external_audit_event_destination, group: group) }
      let!(:header) { create(:audit_events_streaming_header, external_audit_event_destination: destination) }

      it 'finds regular destination' do
        expect(header.destination).to eq(destination)
      end
    end

    context 'with instance header' do
      let!(:destination) { create(:instance_external_audit_event_destination) }
      let!(:header) do
        create(:instance_audit_events_streaming_header, instance_external_audit_event_destination: destination)
      end

      it 'finds instance destination' do
        expect(header.destination).to eq(destination)
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
