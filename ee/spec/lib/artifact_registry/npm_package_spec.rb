# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ArtifactRegistry::NpmPackage, feature_category: :artifact_registry do
  let(:attributes) do
    {
      'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
      'name' => '@acme/ui-components',
      'scope' => '@acme',
      'versions_count' => 7,
      'tags_count' => 2,
      'last_downloaded_at' => '2026-07-03T09:15:00Z'
    }
  end

  subject(:package) { described_class.new(attributes) }

  describe 'rendered readers' do
    it 'exposes the identifier, the full name, the scope, and the versions count', :aggregate_failures do
      expect(package.id).to eq('a1b2c3d4-0000-0000-0000-000000000000')
      expect(package.name).to eq('@acme/ui-components')
      expect(package.scope).to eq('@acme')
      expect(package.versions_count).to eq(7)
    end
  end

  describe 'fields the client does not read' do
    let(:attributes) { super().merge('newly_added_ar_field' => 'ignored') }

    it 'defines no reader for the contract fields nothing renders yet, nor for unknown keys',
      :aggregate_failures do
      expect(package.name).to eq('@acme/ui-components')
      expect(package).not_to respond_to(:tags_count)
      expect(package).not_to respond_to(:last_downloaded_at)
      expect(package).not_to respond_to(:newly_added_ar_field)
    end
  end

  describe 'an unscoped package' do
    let(:attributes) { super().merge('name' => 'ui-components', 'scope' => nil) }

    it 'exposes the name with a nil scope, which the contract sends as JSON null', :aggregate_failures do
      expect(package.name).to eq('ui-components')
      expect(package.scope).to be_nil
    end
  end

  describe 'absent fields' do
    let(:attributes) { { 'id' => 'a1b2c3d4-0000-0000-0000-000000000000' } }

    it 'returns nil for absent fields without raising or defaulting the count', :aggregate_failures do
      expect(package.id).to eq('a1b2c3d4-0000-0000-0000-000000000000')
      expect(package.name).to be_nil
      expect(package.scope).to be_nil
      expect(package.versions_count).to be_nil
    end
  end

  describe 'when constructed with nil attributes' do
    subject(:package) { described_class.new(nil) }

    it 'treats it as an empty resource without raising', :aggregate_failures do
      expect(package.id).to be_nil
      expect(package.name).to be_nil
      expect(package.versions_count).to be_nil
    end
  end
end
