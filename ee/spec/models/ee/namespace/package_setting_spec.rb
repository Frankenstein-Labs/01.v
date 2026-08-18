# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespace::PackageSetting, feature_category: :package_registry do
  describe 'validations' do
    it { is_expected.to allow_value(true, false).for(:audit_events_enabled) }
    it { is_expected.not_to allow_value(nil).for(:audit_events_enabled) }
  end

  describe 'scopes' do
    describe '.with_audit_events_enabled' do
      let_it_be(:package_settings) { create(:namespace_package_setting, audit_events_enabled: true) }
      let_it_be(:other_package_settings) { create(:namespace_package_setting) }

      subject { described_class.with_audit_events_enabled }

      it { is_expected.to eq([package_settings]) }
    end
  end
end
