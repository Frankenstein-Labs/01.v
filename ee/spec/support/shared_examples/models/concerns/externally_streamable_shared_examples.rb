# frozen_string_literal: true

RSpec.shared_examples 'includes ExternallyStreamable concern' do |destination_factory|
  describe 'validations' do
    it { is_expected.to validate_presence_of(:config) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to be_a(AuditEvents::ExternallyStreamable) }
    it { is_expected.to validate_length_of(:name).is_at_most(72) }

    context 'when category' do
      it 'is valid' do
        expect(destination).to be_valid
      end

      it 'is nil' do
        destination.category = nil

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages)
          .to match_array(["Category can't be blank"])
      end

      it 'is invalid' do
        expect { destination.category = 'invalid' }.to raise_error(ArgumentError)
      end
    end

    context 'for secret_token' do
      context 'when secret_token is empty' do
        context 'when category is http' do
          it 'secret token is present' do
            destination1 = build(model_factory_name, category: 'http', secret_token: nil)

            expect(destination1).to be_valid
            expect(destination1.secret_token).to be_present
          end
        end

        context 'when category is not http' do
          it 'destination is invalid' do
            destination1 = build(model_factory_name, :aws, secret_token: nil)

            expect(destination1).to be_invalid
            expect(destination1.secret_token).to be_nil
          end
        end

        context 'when category is nil' do
          it 'destination is invalid' do
            destination1 = build(model_factory_name, category: nil, secret_token: nil)
            expect(destination1).to be_invalid
            expect(destination1.secret_token).to be_nil
          end
        end
      end

      context 'when secret_token is not empty' do
        context 'when category is http' do
          context 'when given secret_token is invalid' do
            it 'destination is invalid' do
              destination1 = build(model_factory_name, category: 'http', secret_token: 'invalid')

              expect(destination1).to be_invalid
              expect(destination1.errors)
                .to match_array(['Secret token should have length between 16 to 24 characters.'])
            end
          end

          context 'when given secret_token is valid' do
            it 'destination is valid' do
              destination1 = build(model_factory_name, category: 'http', secret_token: 'valid_secure_token_123')

              expect(destination1).to be_valid
              expect(destination1.secret_token).to eq('valid_secure_token_123')
            end
          end
        end

        context 'when category is not http' do
          it 'secret_token is present' do
            destination1 = build(model_factory_name, :aws, secret_token: 'random_aws_token')

            expect(destination1).to be_valid
            expect(destination1.secret_token).to eq('random_aws_token')
          end

          context 'when secret_token exceeds maximum length' do
            it 'is invalid when secret_token is over 4096 characters' do
              destination = build(model_factory_name, :gcp, secret_token: 'a' * 8193)

              expect(destination).not_to be_valid
              expect(destination.errors[:secret_token]).to include('is too long (maximum is 4096 characters)')
            end

            it 'is valid when secret_token is exactly 4096 characters' do
              destination = build(model_factory_name, :aws, secret_token: 'a' * 4096)

              expect(destination).to be_valid
            end
          end
        end

        context 'when category is nil' do
          it 'destination is invalid' do
            destination1 = build(model_factory_name, category: nil, secret_token: 'random_secret_token')
            expect(destination1).to be_invalid
          end
        end
      end
    end

    it_behaves_like 'having unique enum values'

    context 'when config' do
      it 'is invalid' do
        destination.config = 'hello'

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages).to include('Config must be a valid json schema')
      end
    end

    context 'when creating without a name' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('12345678')
      end

      it 'assigns a default name' do
        destination = build(model_factory_name, name: nil)

        expect(destination).to be_valid
        expect(destination.name).to eq('Destination_12345678')
      end
    end

    context 'when category is http' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(model_factory_name, config: { url: http_url, headers: http_headers })
        end

        let(:more_than_allowed_headers) { {} }

        let(:large_string) { "a" * 256 }
        let(:very_large_string) { "a" * 2001 }
        let(:large_but_valid_string) { "a" * 2000 }
        let(:large_url) { "http://#{large_string}.com" }
        let(:header_hash1) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }
        let(:header_hash2) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }
        let(:header_with_large_valid_value) { { key1: { value: large_but_valid_string, active: true } } }
        let(:header_with_too_large_value) { { key1: { value: very_large_string, active: true } } }
        let(:invalid_properties) { { key1: { value: 'value1', extra: 'extra key value' } } }
        let(:invalid_characters) { { key1: { value: ' leading or trailing space ', active: true } } }
        let(:valid_special_characters) { { 'X-Meta-Custom_header': { value: '"value",commas,' } } }

        before do
          21.times do |i|
            more_than_allowed_headers["Key#{i}"] = { value: "Value#{i}", active: true }
          end
        end

        where(:http_url, :http_headers, :is_valid) do
          nil                   | nil                                                   | false
          'http://example.com'  | nil                                                   | true
          ref(:large_url)       | nil                                                   | false
          'https://example.com' | nil                                                   | true
          'ftp://example.com'   | nil                                                   | false
          nil                   | { key1: 'value1' }                                    | false
          'http://example.com'  | { key1: { value: 'value1', active: true } }           | true
          'http://example.com'  | { key1: { value: ref(:large_string), active: true } } | true
          'http://example.com'  | ref(:header_with_large_valid_value)                   | true
          'http://example.com'  | ref(:header_with_too_large_value)                     | false
          'http://example.com'  | { key1: { value: 'value1', active: false } }          | true
          'http://example.com'  | {}                                                    | true
          'http://example.com'  | ref(:header_hash1)                                    | true
          'http://example.com'  | { key1: 'value1' }                                    | false
          'http://example.com'  | ref(:header_hash2)                                    | true
          'http://example.com'  | ref(:more_than_allowed_headers)                       | false
          'http://example.com'  | ref(:invalid_properties)                              | false
          'http://example.com'  | ref(:invalid_characters)                              | false
          'http://example.com'  | ref(:valid_special_characters)                        | true
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end

      describe 'empty headers handling' do
        it 'removes empty headers object before validation' do
          destination = build(model_factory_name, config: { url: 'https://example.com', headers: {} })

          expect(destination).to be_valid
          expect(destination.config).to eq({ 'url' => 'https://example.com' })
          expect(destination.config).not_to have_key('headers')
        end

        it 'does not affect non-empty headers' do
          config_with_headers = {
            url: 'https://example.com',
            headers: { 'X-Custom' => { value: 'test', active: true } }
          }
          destination = build(model_factory_name, config: config_with_headers)

          expect(destination).to be_valid
          expect(destination.config['headers']).to be_present
          expect(destination.config['headers']['X-Custom']['value']).to eq('test')
        end

        it 'handles updates that result in empty headers' do
          destination = create(model_factory_name,
            config: {
              url: 'https://example.com',
              headers: { 'X-Custom' => { value: 'test', active: true } }
            }
          )

          destination.config = { url: 'https://example.com', headers: {} }

          expect(destination).to be_valid
          expect(destination.save).to be true

          destination.reload
          expect(destination.config).to eq({ 'url' => 'https://example.com' })
        end
      end
    end

    context 'when category is aws' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(:audit_events_group_external_streaming_destination, :aws,
            config: { accessKeyXid: access_key, bucketName: bucket, awsRegion: region })
        end

        where(:access_key, :bucket, :region, :is_valid) do
          SecureRandom.hex(8)   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | true
          nil                   | nil                   | nil                    | false
          SecureRandom.hex(8)   | SecureRandom.hex(8)   | nil                    | false
          SecureRandom.hex(8)   | nil                   | SecureRandom.hex(8)    | false
          nil                   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | false
          SecureRandom.hex(7)   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | false
          SecureRandom.hex(8)   | SecureRandom.hex(35) | SecureRandom.hex(8)    | false
          SecureRandom.hex(8)   | SecureRandom.hex(8) | SecureRandom.hex(26)    | false
          "access-id-with-hyphen" | SecureRandom.hex(8) | SecureRandom.hex(8) | false
          SecureRandom.hex(8) | "bucket/logs/test" | SecureRandom.hex(8) | false
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end

      context 'for awsRegion format validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(model_factory_name, :aws,
            config: { accessKeyXid: SecureRandom.hex(8), bucketName: SecureRandom.hex(8), awsRegion: region })
        end

        where(:region, :is_valid) { AuditEvents::AwsRegionTestCases::CASES }

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end

        context 'with a malformed region' do
          let(:region) { 'us east 1' }

          it 'names the offending field instead of only reporting a schema failure' do
            expect(destination).not_to be_valid
            expect(destination.errors.full_messages)
              .to include('AWS region must be a valid region code, for example us-east-1')
          end
        end
      end

      describe '#normalize_aws_region' do
        subject(:destination) do
          build(model_factory_name, :aws,
            config: { accessKeyXid: SecureRandom.hex(8), bucketName: SecureRandom.hex(8),
                      awsRegion: '  us-east-1  ' })
        end

        it 'strips surrounding whitespace so the destination stays valid' do
          expect(destination).to be_valid
          expect(destination.config['awsRegion']).to eq('us-east-1')
        end
      end

      context 'when an existing destination already stores a malformed region' do
        let(:stored_region) { 'us east 1' }

        let(:existing) do
          build(model_factory_name, :aws, name: "existing-#{SecureRandom.hex(4)}").tap do |record|
            record.config = record.config.merge('awsRegion' => stored_region)
            record.save!(validate: false)
          end
        end

        it 'can still be renamed without correcting the region' do
          existing.name = 'renamed'

          expect(existing).to be_valid
        end

        it 'can still be deactivated without correcting the region' do
          expect { existing.deactivate! }.not_to raise_error
          expect(existing.reload).not_to be_active
        end

        it 'is rejected as soon as the region itself is changed' do
          existing.config = existing.config.merge('awsRegion' => 'us west 2')

          expect(existing).not_to be_valid
          expect(existing.errors.full_messages)
            .to include('AWS region must be a valid region code, for example us-east-1')
        end

        context 'when the stored region also carries surrounding whitespace' do
          let(:stored_region) { 'us east 1 ' }

          it 'can still be renamed, and the strip does not dirty the config' do
            existing.name = 'renamed'

            expect(existing).to be_valid
            expect(existing.config['awsRegion']).to eq('us east 1 ')
          end
        end
      end
    end

    context 'when category is gcp' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(model_factory_name, :gcp,
            config: { googleProjectIdName: project_id, clientEmail: client_email, logIdName: log_id }.compact)
        end

        where(:project_id, :client_email, :log_id, :is_valid) do
          "valid-project-id"     | "abcd@example.com"                         | "audit-events"        | true
          "valid-project-id-1"   | "abcd@example.com"                         | "audit-events"        | true
          "invalid_project_id"   | "abcd@example.com"                         | "audit-events"        | false
          "invalid-project-id-"  | "abcd@example.com"                         | "audit-events"        | false
          "Invalid-project-id"   | "abcd@example.com"                         | "audit-events"        | false
          "1-invalid-project-id" | "abcd@example.com"                         | "audit-events"        | false
          "-invalid-project-id"  | "abcd@example.com"                         | "audit-events"        | false
          "small"                | "abcd@example.com"                         | "audit-events"        | false
          SecureRandom.hex(16)   | "abcd@example.com"                         | "audit-events"        | false

          "valid-project-id"     | "valid_email+mail@mail.com"                | "audit-events"        | true
          "valid-project-id"     | "invalid_email"                            | "audit-events"        | false
          "valid-project-id"     | "invalid@.com"                             | "audit-events"        | false
          "valid-project-id"     | "invalid..com"                             | "audit-events"        | false
          "valid-project-id"     | "abcd#{SecureRandom.hex(120)}@example.com" | "audit-events"        | false

          "valid-project-id"     | "abcd@example.com"                         | "audit_events"        | true
          "valid-project-id"     | "abcd@example.com"                         | "audit.events"        | true
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENTS"        | true
          "valid-project-id"     | "abcd@example.com"                         | "audit_events/123"    | true
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENT@"        | false
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENT$"        | false
          "valid-project-id"     | "abcd@example.com"                         | "#AUDIT_EVENT"        | false
          "valid-project-id"     | "abcd@example.com"                         | "%audit_events/123"   | false
          "valid-project-id"     | "abcd@example.com"                         | SecureRandom.hex(256) | false

          nil                    | nil                                        | nil                   | false
          "valid-project-id"     | "abcd@example.com"                         | nil                   | true
          "valid-project-id"     | nil                                        | "audit-events"        | false
          nil                    | "abcd@example.com"                         | "audit-events"        | false
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end
    end

    describe "#assign_default_log_id" do
      context 'when category is gcp' do
        context 'when log id is provided' do
          it 'does not assign default value' do
            destination = create(model_factory_name,
              :gcp,
              config: {
                googleProjectIdName: "project-id",
                clientEmail: "abcd@email.com",
                logIdName: 'non-default-log'
              }
            )

            expect(destination).to be_valid
            expect(destination.errors).to be_empty
            expect(destination.config['logIdName']).to eq('non-default-log')
          end
        end

        context 'when log id is not provided' do
          it 'assigns default value' do
            destination = create(model_factory_name,
              :gcp,
              config: {
                googleProjectIdName: "project-id",
                clientEmail: "abcd@email.com"
              }
            )

            expect(destination).to be_valid
            expect(destination.errors).to be_empty
            expect(destination.config['logIdName']).to eq('audit-events')
          end
        end
      end

      context 'when category is not gcp' do
        it 'does not add logIdName field to config' do
          destination = create(model_factory_name, config: { url: "https://www.example.com" })

          expect(destination).to be_valid
          expect(destination.config.keys).not_to include('logIdName')
        end
      end
    end

    describe '#headers_hash' do
      subject(:destination) do
        create(model_factory_name, config: { url: 'https://example.com', headers: http_headers })
      end

      context 'when there are no headers' do
        let(:http_headers) { nil }

        it 'returns a hash with only secret token' do
          headers_hash = destination.headers_hash

          expect(headers_hash.length).to eq(1)
          expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
            .to eq(destination.secret_token)
        end
      end

      context 'when there is no active header' do
        let(:http_headers) { { key1: { value: 'value1', active: false }, key2: { value: 'value2', active: false } } }

        it 'returns a hash with only secret token' do
          headers_hash = destination.headers_hash

          expect(headers_hash.length).to eq(1)
          expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
            .to eq(destination.secret_token)
        end
      end

      context 'when there are active and inactive headers' do
        let(:http_headers) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }

        it 'returns a hash with active headers and secret token header' do
          headers_hash = destination.headers_hash

          expect(headers_hash.length).to eq(2)

          expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
            .to eq(destination.secret_token)
          expect(headers_hash["key1"]).to eq('value1')
        end
      end

      context 'when attempting to use protected header key' do
        it 'prevents creation with protected header' do
          expect do
            create(model_factory_name, config: {
              url: 'https://example.com',
              headers: {
                AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY => {
                  value: 'custom_token_overwrite',
                  active: true
                }
              }
            })
          end.to raise_error(ActiveRecord::RecordInvalid, /headers cannot contain X-Gitlab-Event-Streaming-Token/)
        end

        it 'prevents creation with protected header in different case' do
          expect do
            create(model_factory_name, config: {
              url: 'https://example.com',
              headers: {
                'x-gitlab-event-streaming-token' => {
                  value: 'custom_token_overwrite',
                  active: true
                }
              }
            })
          end.to raise_error(ActiveRecord::RecordInvalid, /headers cannot contain X-Gitlab-Event-Streaming-Token/)
        end

        context 'when protected header exists in database (bypass scenario)' do
          it 'headers_hash still uses the real secret token' do
            destination = create(model_factory_name, config: { url: 'https://example.com' })

            destination.class.where(id: destination.id).update_all(
              config: {
                url: 'https://example.com',
                headers: {
                  AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY => {
                    value: 'fake_token_from_db',
                    active: true
                  }
                }
              }.to_json
            )

            destination.reload
            headers_hash = destination.headers_hash

            expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
              .to eq(destination.secret_token)
            expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
              .not_to eq('fake_token_from_db')
          end
        end
      end
    end

    context 'with large header values' do
      it 'accepts values up to 2000 characters' do
        large_value = 'a' * 2000
        destination = build(model_factory_name,
          config: {
            url: 'https://example.com',
            headers: {
              'X-Custom-Header': { value: large_value, active: true }
            }
          }
        )

        expect(destination).to be_valid
      end

      it 'rejects values over 2000 characters' do
        too_large_value = 'a' * 2001
        destination = build(model_factory_name,
          config: {
            url: 'https://example.com',
            headers: {
              'X-Custom-Header': { value: too_large_value, active: true }
            }
          }
        )

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages).to include('Config must be a valid json schema')
      end
    end
  end

  describe 'config format validation' do
    context 'when config is a JSON string' do
      it 'automatically converts valid JSON strings to hash before validation' do
        json_string = '{"url":"https://example.com","headers":{"X-Header":{"value":"test","active":true}}}'
        destination = build(model_factory_name, category: 'http', config: json_string)

        expect(destination).to be_valid
        expect(destination.config).to be_a(Hash)
        expect(destination.config['url']).to eq('https://example.com')
        expect(destination.config['headers']['X-Header']['value']).to eq('test')
      end

      it 'handles JSON strings with whitespace before or after braces' do
        json_string = '  {"url":"https://example.com"}  '
        destination = build(model_factory_name, category: 'http', config: json_string)

        expect(destination).to be_valid
        expect(destination.config).to be_a(Hash)
        expect(destination.config['url']).to eq('https://example.com')
      end

      it 'rejects invalid JSON strings' do
        invalid_json = '{this is not valid json}'
        destination = build(model_factory_name, category: 'http', config: invalid_json)

        expect(destination).not_to be_valid
        expect(destination.errors[:config]).to include('must be a hash')
      end

      it 'rejects regular strings' do
        destination = build(model_factory_name, category: 'http', config: 'just a regular string')

        expect(destination).not_to be_valid
        expect(destination.errors[:config]).to include('must be a hash')
      end

      it 'handles double-encoded JSON strings from migrations' do
        hash_config = { 'url' => 'https://example.com' }
        json_string = hash_config.to_json

        destination = build(model_factory_name, category: 'http', config: json_string)

        expect(destination).to be_valid
        expect(destination.config).to be_a(Hash)
        expect(destination.config['url']).to eq('https://example.com')
      end
    end

    context 'when accessing config' do
      it 'dynamically converts string configs when accessed' do
        destination = build(model_factory_name, category: 'http')
        destination.send(:write_attribute, :config, '{"url":"https://example.com"}')

        expect(destination.config).to be_a(Hash)
        expect(destination.config['url']).to eq('https://example.com')
      end

      it 'returns original config when string cannot be parsed' do
        destination = build(model_factory_name, category: 'http')
        destination.send(:write_attribute, :config, '{invalid json}')

        expect(destination.config).to eq('{invalid json}')
      end
    end

    context 'when updating non-config attributes' do
      it 'allows updates to other attributes when config is invalid but unchanged' do
        destination = create(model_factory_name, category: 'http', config: { url: 'https://example.com' })

        described_class.where(id: destination.id).update_all(config: '{"url":"https://example.com"}')

        destination.reload

        allow(destination).to receive(:config_changed?).and_return(false)

        destination.name = "New name"
        expect(destination.valid?).to be_truthy
        expect(destination.save).to be_truthy
      end
    end

    context 'when saving to database' do
      it 'stores config in a format that is loaded as a hash' do
        json_string = '{"url":"https://example.com"}'
        destination = create(model_factory_name, category: 'http', config: json_string)

        reloaded = described_class.find(destination.id)

        expect(reloaded.config).to be_a(Hash)
        expect(reloaded.config).to include('url' => 'https://example.com')
        expect(reloaded.config['url']).to eq('https://example.com')
      end
    end
  end

  describe '#allowed_to_stream?' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Rails/SaveBang -- Need to create
    let_it_be(:destination_without_filters, freeze: false) { create(destination_factory) }
    let_it_be(:destination_with_filters, freeze: false) { create(destination_factory) }
    # rubocop:enable Rails/SaveBang

    let_it_be(:legacy_user_event, freeze: false) { create(:user_audit_event) }
    let_it_be(:legacy_project_event, freeze: false) { create(:project_audit_event) }
    let_it_be(:legacy_group_event, freeze: false) { create(:group_audit_event) }

    let_it_be(:new_user_event, freeze: false) { create(:audit_events_user_audit_event) }
    let_it_be(:new_project_event, freeze: false) { create(:audit_events_project_audit_event) }
    let_it_be(:new_group_event, freeze: false) { create(:audit_events_group_audit_event) }

    before_all do
      filter_factory = case destination_factory
                       when :audit_events_group_external_streaming_destination
                         :audit_events_group_event_type_filters
                       when :audit_events_instance_external_streaming_destination
                         :audit_events_instance_event_type_filters
                       end

      create(filter_factory,
        external_streaming_destination: destination_with_filters,
        audit_event_type: 'event_type_filters_created')

      create(filter_factory,
        external_streaming_destination: destination_with_filters,
        audit_event_type: 'event_type_filters_deleted')
    end

    where(:destination, :event_type, :audit_event, :expected_result) do
      # Destination without filters - always allows streaming
      ref(:destination_without_filters) | 'any_event' | ref(:legacy_user_event) | true
      ref(:destination_without_filters) | 'event_type_filters_created'  | ref(:legacy_project_event) | true
      ref(:destination_without_filters) | nil                           | ref(:legacy_group_event)   | true
      ref(:destination_without_filters) | 'any_event' | ref(:new_user_event) | true
      ref(:destination_without_filters) | 'event_type_filters_created'  | ref(:new_project_event)    | true
      ref(:destination_without_filters) | nil                           | ref(:new_group_event)      | true
      ref(:destination_without_filters) | 'any_event' | nil | true

      # Destination with filters - matching event types
      ref(:destination_with_filters)    | 'event_type_filters_created'  | ref(:legacy_user_event)    | true
      ref(:destination_with_filters)    | 'event_type_filters_deleted'  | ref(:legacy_project_event) | true
      ref(:destination_with_filters)    | 'event_type_filters_created'  | ref(:new_user_event)       | true
      ref(:destination_with_filters)    | 'event_type_filters_deleted'  | ref(:new_group_event)      | true
      ref(:destination_with_filters)    | 'event_type_filters_created'  | nil                        | true

      # Destination with filters - non-matching event types
      ref(:destination_with_filters)    | 'non_matching_event'          | ref(:legacy_user_event)    | false
      ref(:destination_with_filters)    | 'other_event_type'            | ref(:legacy_project_event) | false
      ref(:destination_with_filters)    | 'non_matching_event'          | ref(:new_user_event)       | false
      ref(:destination_with_filters)    | 'other_event_type'            | ref(:new_group_event)      | false

      # Destination with filters - nil event type
      ref(:destination_with_filters)    | nil                           | ref(:legacy_user_event)    | true
      ref(:destination_with_filters)    | nil                           | ref(:new_project_event)    | true
    end

    with_them do
      it 'returns expected streaming permission' do
        expect(destination.allowed_to_stream?(event_type, audit_event)).to eq(expected_result)
      end
    end
    context 'with namespace filters' do
      let(:namespace_filter_factory) do
        case destination_factory
        when :audit_events_group_external_streaming_destination
          :audit_events_streaming_group_namespace_filters
        when :audit_events_instance_external_streaming_destination
          :audit_events_streaming_instance_namespace_filters
        end
      end

      let(:destination_with_namespace_filters) { create(destination_factory) } # rubocop:disable Rails/SaveBang -- Need save

      let(:root_group) do
        case destination_factory
        when :audit_events_group_external_streaming_destination
          destination_with_namespace_filters.group
        else
          create(:group)
        end
      end

      let_it_be(:unrelated_group, freeze: false) { create(:group) }
      let(:child_group) { create(:group, parent: root_group) }
      let(:grandchild_group) { create(:group, parent: child_group) }

      let_it_be(:base_audit_event, freeze: false) { create(:audit_event) }

      def stub_streamable_namespace(audit_event, namespace)
        allow(audit_event).to receive(:streamable_namespace).and_return(namespace)
      end

      context 'when audit event does not respond to streamable_namespace' do
        before do
          create(namespace_filter_factory,
            external_streaming_destination: destination_with_namespace_filters,
            namespace: child_group)

          allow(base_audit_event).to receive(:respond_to?).with(:streamable_namespace).and_return(false)
        end

        it 'allows streaming' do
          expect(destination_with_namespace_filters.allowed_to_stream?('any_event', base_audit_event)).to be true
        end
      end

      context 'when audit event streamable_namespace is nil' do
        before do
          create(namespace_filter_factory,
            external_streaming_destination: destination_with_namespace_filters,
            namespace: child_group)

          stub_streamable_namespace(base_audit_event, nil)
        end

        it 'allows streaming' do
          expect(destination_with_namespace_filters.allowed_to_stream?('any_event', base_audit_event)).to be true
        end
      end

      context 'with group namespace filters' do
        before do
          create(namespace_filter_factory,
            external_streaming_destination: destination_with_namespace_filters,
            namespace: root_group)
          create(namespace_filter_factory,
            external_streaming_destination: destination_with_namespace_filters,
            namespace: child_group)
        end

        where(:namespace, :expected) do
          ref(:root_group) | true
          ref(:grandchild_group) | true
          ref(:unrelated_group) | false
        end

        with_them do
          it "returns #{params[:expected]} for namespace streaming check" do
            stub_streamable_namespace(base_audit_event, namespace)
            expect(destination_with_namespace_filters.allowed_to_stream?('any_event', base_audit_event)).to eq(expected)
          end
        end
      end

      context 'with project namespace filters' do
        let(:project_in_root) { create(:project, namespace: root_group) }
        let(:project_in_child) { create(:project, namespace: child_group) }
        let(:project_namespace_filter) { project_in_root.project_namespace }

        before do
          create(namespace_filter_factory,
            external_streaming_destination: destination_with_namespace_filters,
            namespace: project_namespace_filter)
        end

        where(:namespace_key, :expected) do
          :project_namespace_filter | true
          :project_child_namespace | false
          :root_group                   | false
          :child_group                  | false
        end

        with_them do
          let(:namespace) do
            case namespace_key
            when :project_namespace_filter then project_namespace_filter
            when :project_child_namespace then project_in_child.project_namespace
            when :root_group then root_group
            when :child_group then child_group
            end
          end

          it "returns #{params[:expected]} for project namespace filter" do
            stub_streamable_namespace(base_audit_event, namespace)
            expect(destination_with_namespace_filters.allowed_to_stream?('any_event', base_audit_event)).to eq(expected)
          end
        end
      end

      context 'with mixed group and project namespace filters' do
        let(:project_in_child) { create(:project, namespace: child_group) }

        before do
          create(namespace_filter_factory,
            external_streaming_destination: destination_with_namespace_filters,
            namespace: root_group)
          create(namespace_filter_factory,
            external_streaming_destination: destination_with_namespace_filters,
            namespace: project_in_child.project_namespace)
        end

        where(:namespace_key, :expected) do
          :child_group           | true
          :project_namespace     | true
          :unrelated_group       | false
        end

        with_them do
          let(:namespace) do
            case namespace_key
            when :child_group then child_group
            when :project_namespace then project_in_child.project_namespace
            when :unrelated_group then unrelated_group
            end
          end

          it "returns #{params[:expected]} for mixed filters" do
            stub_streamable_namespace(base_audit_event, namespace)
            expect(destination_with_namespace_filters.allowed_to_stream?('any_event', base_audit_event)).to eq(expected)
          end
        end
      end
    end

    context 'with instance audit events' do
      let(:legacy_instance_event) { create(:instance_audit_event) }
      let(:new_instance_event) { create(:audit_events_instance_audit_event) }

      where(:destination, :event_type, :audit_event, :expected_result) do
        ref(:destination_without_filters) | 'any_event' | ref(:legacy_instance_event) | true
        ref(:destination_without_filters) | nil                          | ref(:new_instance_event)    | true
        ref(:destination_with_filters)    | 'event_type_filters_created' | ref(:legacy_instance_event) | true
        ref(:destination_with_filters)    | 'event_type_filters_created' | ref(:new_instance_event)    | true
        ref(:destination_with_filters)    | 'non_matching_event'         | ref(:legacy_instance_event) | false
        ref(:destination_with_filters)    | 'non_matching_event'         | ref(:new_instance_event)    | false
      end

      with_them do
        it 'returns expected streaming permission for instance events' do
          expect(destination.allowed_to_stream?(event_type, audit_event)).to eq(expected_result)
        end
      end
    end
  end
end
