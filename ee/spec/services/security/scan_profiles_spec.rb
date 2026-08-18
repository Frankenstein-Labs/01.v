# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles, feature_category: :security_testing_configuration do
  describe '.update_lease_key' do
    subject { described_class.update_lease_key(123) }

    it { is_expected.to eq('update_scan_profile:namespace:123') }
  end
end
