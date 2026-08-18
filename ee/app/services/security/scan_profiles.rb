# frozen_string_literal: true

module Security
  module ScanProfiles
    def self.update_lease_key(namespace_id)
      "update_scan_profile:namespace:#{namespace_id}"
    end
  end
end
