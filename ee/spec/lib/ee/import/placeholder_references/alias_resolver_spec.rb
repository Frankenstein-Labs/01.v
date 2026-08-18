# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::PlaceholderReferences::AliasResolver, feature_category: :importers do
  describe '.aliases' do
    it 'includes CE aliases' do
      stub_const('Import::PlaceholderReferences::AliasResolver::ALIASES', { 'Note' => {} })

      expect(described_class.aliases).to include('Note')
    end

    it 'includes EE aliases' do
      stub_const('Import::PlaceholderReferences::AliasResolver::EE_ALIASES', { 'BoardAssignee' => {} })

      expect(described_class.aliases).to include('BoardAssignee')
    end
  end
end
