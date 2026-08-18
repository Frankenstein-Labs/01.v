# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ArtifactRegistry::Repository, feature_category: :artifact_registry do
  let(:attributes) do
    {
      'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
      'name' => 'my-repo',
      'format' => 'maven',
      'kind' => 'hosted',
      'visibility' => 'private',
      'description' => 'A hosted Maven repository',
      'artifacts_count' => 12,
      'downloads_count' => 340,
      'size_bytes' => 987_654,
      'created_at' => '2026-07-01T10:00:00Z',
      'last_updated_at' => '2026-07-02T11:30:00Z',
      'created_by' => '101',
      'updated_by' => '202',
      'settings' => { 'immutable_tags' => true }
    }
  end

  subject(:repository) { described_class.new(attributes) }

  describe 'documented readers' do
    it 'exposes every documented field from the parsed response hash', :aggregate_failures do
      expect(repository.id).to eq('a1b2c3d4-0000-0000-0000-000000000000')
      expect(repository.name).to eq('my-repo')
      expect(repository.format).to eq('maven')
      expect(repository.kind).to eq('hosted')
      expect(repository.visibility).to eq('private')
      expect(repository.description).to eq('A hosted Maven repository')
      expect(repository.artifacts_count).to eq(12)
      expect(repository.downloads_count).to eq(340)
      expect(repository.size_bytes).to eq(987_654)
      expect(repository.created_at).to eq(DateTime.iso8601('2026-07-01T10:00:00Z'))
      expect(repository.last_updated_at).to eq(DateTime.iso8601('2026-07-02T11:30:00Z'))
      expect(repository.created_by).to eq('101')
      expect(repository.updated_by).to eq('202')
      expect(repository.settings).to eq({ 'immutable_tags' => true })
    end
  end

  describe 'unknown-field tolerance' do
    let(:attributes) { super().merge('newly_added_ar_field' => 'ignored', 'nested_future' => { 'x' => 1 }) }

    it 'still exposes every documented field and defines no reader for undocumented keys', :aggregate_failures do
      expect(repository.name).to eq('my-repo')
      expect(repository.format).to eq('maven')
      expect(repository).not_to respond_to(:newly_added_ar_field)
    end
  end

  describe 'absent optional fields' do
    let(:attributes) { { 'name' => 'bare-repo' } }

    it 'returns nil for absent documented fields without raising', :aggregate_failures do
      expect(repository.name).to eq('bare-repo')
      expect(repository.description).to be_nil
      expect(repository.last_updated_at).to be_nil
      expect(repository.created_by).to be_nil
      expect(repository.updated_by).to be_nil
    end

    it 'exposes settings as an empty Hash when the response omits it' do
      expect(repository.settings).to eq({})
    end
  end

  describe 'timestamp coercion' do
    it 'coerces ISO8601 timestamps to DateTime', :aggregate_failures do
      expect(repository.created_at).to be_a(DateTime)
      expect(repository.last_updated_at).to be_a(DateTime)
    end

    context 'when a timestamp is not parseable' do
      let(:attributes) { super().merge('created_at' => 'not-a-timestamp') }

      it 'returns nil rather than raising' do
        expect(repository.created_at).to be_nil
      end
    end

    context 'when a timestamp is not a string' do
      let(:attributes) { super().merge('created_at' => 12345) }

      it 'returns nil rather than raising' do
        expect(repository.created_at).to be_nil
      end
    end
  end

  describe 'when constructed with nil attributes' do
    subject(:repository) { described_class.new(nil) }

    it 'treats it as an empty resource without raising', :aggregate_failures do
      expect(repository.name).to be_nil
      expect(repository.settings).to eq({})
    end
  end
end
