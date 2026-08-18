# frozen_string_literal: true

module Security
  class DefaultScanProfiles
    def self.find_by_scan_type(scan_type)
      Security::DefaultScanProfilesHelper.default_scan_profiles.find { |profile| profile.scan_type == scan_type.to_s }
    end
  end
end
