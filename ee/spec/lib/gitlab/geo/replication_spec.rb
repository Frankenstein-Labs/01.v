# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::Replication, feature_category: :geo_replication do
  describe '.object_type_from_user_uploads?' do
    it 'returns true for representative user upload object types' do
      expect(described_class.object_type_from_user_uploads?(:attachment)).to be true
      expect(described_class.object_type_from_user_uploads?(:avatar)).to be true
      expect(described_class.object_type_from_user_uploads?(:import_export)).to be true
    end

    it 'returns true when passed string representation of valid types' do
      expect(described_class.object_type_from_user_uploads?('attachment')).to be true
      expect(described_class.object_type_from_user_uploads?('avatar')).to be true
    end

    it 'returns false for invalid object types' do
      expect(described_class.object_type_from_user_uploads?(:invalid_type)).to be false
      expect(described_class.object_type_from_user_uploads?('unknown')).to be false
    end
  end
end
