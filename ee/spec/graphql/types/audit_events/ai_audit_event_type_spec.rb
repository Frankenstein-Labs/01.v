# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAuditEvent'], feature_category: :duo_agent_platform do
  it 'has the expected fields' do
    expected_fields = %i[id event_name created_at workflow_id ip_address details author human_author]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'exposes id as non-null GraphQL ID' do
    expect(described_class.fields['id'].type.to_type_signature).to eq('ID!')
  end

  it 'exposes workflowId as non-null GraphQL ID' do
    expect(described_class.fields['workflowId'].type.to_type_signature).to eq('ID!')
  end

  it 'exposes createdAt as non-null Time' do
    expect(described_class.fields['createdAt'].type.to_type_signature).to eq('Time!')
  end

  it 'exposes ipAddress as nullable String' do
    expect(described_class.fields['ipAddress'].type.to_type_signature).to eq('String')
  end

  it 'exposes details as nullable JSON' do
    expect(described_class.fields['details'].type.to_type_signature).to eq('JSON')
  end

  it 'exposes author as nullable UserCore' do
    expect(described_class.fields['author'].type.to_type_signature).to eq('UserCore')
  end

  it 'exposes humanAuthor as nullable UserCore' do
    expect(described_class.fields['humanAuthor'].type.to_type_signature).to eq('UserCore')
  end

  describe 'resolving fields polymorphically' do
    let(:author) { build_stubbed(:user) }
    let(:created_at) { Time.zone.parse('2026-01-02 03:04:05') }
    let(:cloud_event_id) { 'd6f9b6d6-1f5c-4e2b-9c1d-1ce5b1f4a000' }

    # Lightweight stand-ins for the GraphQL field resolver mechanics. We only
    # care that `hash_or_attr` reads from the right place on each backend.
    def resolve(field_name, record)
      described_class.send(:new, record, {}).public_send(field_name)
    end

    context 'with an ActiveRecord record (Postgres path)' do
      let(:human) { build_stubbed(:user) }

      let(:record) do
        instance_double(
          ::AuditEvents::AiAuditEvent,
          id: 42,
          cloud_event_id: cloud_event_id,
          event_name: 'ai_llm_input_sent',
          created_at: created_at,
          workflow_id: 7,
          ip_address: IPAddr.new('203.0.113.5'),
          details: { 'token_count' => 12 },
          author_id: author.id
        )
      end

      it 'prefers cloud_event_id for the GraphQL id' do
        expect(resolve(:id, record)).to eq(cloud_event_id)
      end

      it 'returns event_name, workflow_id, and created_at directly' do
        expect(resolve(:event_name, record)).to eq('ai_llm_input_sent')
        expect(resolve(:workflow_id, record)).to eq(7)
        expect(resolve(:created_at, record)).to eq(created_at)
      end

      it 'stringifies ip_address' do
        expect(resolve(:ip_address, record)).to eq('203.0.113.5')
      end

      it 'returns details as a Hash' do
        expect(resolve(:details, record)).to eq('token_count' => 12)
      end

      context 'when details contains human_author_id' do
        let(:record) do
          instance_double(
            ::AuditEvents::AiAuditEvent,
            id: 42,
            cloud_event_id: cloud_event_id,
            event_name: 'ai_llm_input_sent',
            created_at: created_at,
            workflow_id: 7,
            ip_address: IPAddr.new('203.0.113.5'),
            details: { 'human_author_id' => human.id, 'human_author_name' => human.name },
            author_id: author.id
          )
        end

        it 'returns a BatchLoader for human_author' do
          result = resolve(:human_author, record)

          expect(result).to be_a(BatchLoader::GraphQL)
        end
      end

      context 'when details does not contain human_author_id' do
        it 'returns nil for human_author' do
          expect(resolve(:human_author, record)).to be_nil
        end
      end
    end

    context 'with a Hash row (ClickHouse path)' do
      # ClickHouse stores the UUID directly under `id` and has no separate
      # `cloud_event_id` column, so realistic CH rows only carry `id`.
      let(:human) { build_stubbed(:user) }

      let(:record) do
        {
          'id' => cloud_event_id,
          'event_name' => 'ai_llm_input_sent',
          'created_at' => '2026-01-02 03:04:05',
          'workflow_id' => '7',
          'ip_address' => '203.0.113.5',
          'details' => '{"token_count":12}',
          'author_id' => author.id
        }
      end

      it 'falls back to id when cloud_event_id is absent (CH path)' do
        expect(resolve(:id, record)).to eq(cloud_event_id)
      end

      it 'returns event_name and workflow_id from the hash' do
        expect(resolve(:event_name, record)).to eq('ai_llm_input_sent')
        expect(resolve(:workflow_id, record)).to eq('7')
      end

      it 'parses created_at strings into Time' do
        expect(resolve(:created_at, record)).to eq(Time.zone.parse('2026-01-02 03:04:05'))
      end

      it 'returns ip_address as String' do
        expect(resolve(:ip_address, record)).to eq('203.0.113.5')
      end

      it 'parses details JSON strings into a Hash' do
        expect(resolve(:details, record)).to eq('token_count' => 12)
      end

      it 'returns nil when details is blank' do
        record['details'] = ''
        expect(resolve(:details, record)).to be_nil
      end

      it 'returns nil and tracks an exception when details JSON is malformed' do
        record['details'] = '{not valid json'
        expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(::JSON::ParserError).or(an_instance_of(::EncodingError)),
          hash_including(workflow_id: '7', cloud_event_id: cloud_event_id)
        )

        expect(resolve(:details, record)).to be_nil
      end

      it 'parses details only once when both details and human_author are resolved' do
        record['details'] = '{not valid json'
        instance = described_class.send(:new, record, {})

        expect(::Gitlab::ErrorTracking).to receive(:track_exception).once

        instance.details
        instance.human_author
      end

      it 'returns nil for ip_address when blank' do
        record['ip_address'] = ''
        expect(resolve(:ip_address, record)).to be_nil
      end

      context 'when details JSON contains human_author_id' do
        before do
          record['details'] = %({"token_count":12,"human_author_id":#{human.id}})
        end

        it 'returns a BatchLoader for human_author' do
          result = resolve(:human_author, record)

          expect(result).to be_a(BatchLoader::GraphQL)
        end
      end

      context 'when details JSON does not contain human_author_id' do
        it 'returns nil for human_author' do
          expect(resolve(:human_author, record)).to be_nil
        end
      end
    end
  end
end
