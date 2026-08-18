# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::AuthorizedKeysFlagCheck, :silence_stdout, feature_category: :geo_replication do
  describe '#check?' do
    subject(:authorized_keys_flag_check) { described_class.new.check? }

    it 'fails when write to authorized_keys still enabled' do
      stub_application_setting(authorized_keys_enabled: true)

      expect(authorized_keys_flag_check).to be_falsey
    end

    it 'succeed when write to authorized_keys is disabled' do
      stub_application_setting(authorized_keys_enabled: false)

      expect(authorized_keys_flag_check).to be_truthy
    end
  end
end
