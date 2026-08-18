# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ArtifactRegistry::Image, feature_category: :artifact_registry do
  let(:attributes) do
    {
      'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
      'name' => 'api-gateway',
      'last_downloaded_at' => '2026-07-03T09:15:00Z'
    }
  end

  subject(:image) { described_class.new(attributes) }

  describe 'rendered readers' do
    it 'exposes the identifier and the image name', :aggregate_failures do
      expect(image.id).to eq('a1b2c3d4-0000-0000-0000-000000000000')
      expect(image.name).to eq('api-gateway')
    end
  end

  describe 'fields the client does not read' do
    let(:attributes) { super().merge('newly_added_ar_field' => 'ignored') }

    it 'defines no reader for the contract fields nothing renders yet, nor for unknown keys',
      :aggregate_failures do
      expect(image.name).to eq('api-gateway')
      expect(image).not_to respond_to(:last_downloaded_at)
      expect(image).not_to respond_to(:newly_added_ar_field)
    end
  end

  describe 'absent fields' do
    let(:attributes) { { 'id' => 'a1b2c3d4-0000-0000-0000-000000000000' } }

    it 'returns nil for an absent name without raising', :aggregate_failures do
      expect(image.id).to eq('a1b2c3d4-0000-0000-0000-000000000000')
      expect(image.name).to be_nil
    end
  end

  describe 'when constructed with nil attributes' do
    subject(:image) { described_class.new(nil) }

    it 'treats it as an empty resource without raising', :aggregate_failures do
      expect(image.id).to be_nil
      expect(image.name).to be_nil
    end
  end
end
