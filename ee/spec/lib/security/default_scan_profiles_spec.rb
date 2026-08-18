# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DefaultScanProfiles, feature_category: :security_testing_configuration do
  describe '.find_by_scan_type' do
    it 'returns the matching profile when scan type exists' do
      profile = described_class.find_by_scan_type(:secret_detection)

      expect(profile).to be_a(Security::ScanProfile).and have_attributes(scan_type: 'secret_detection')
    end

    it 'returns nil when scan type does not exist' do
      profile = described_class.find_by_scan_type(:non_existent_type)

      expect(profile).to be_nil
    end
  end
end
