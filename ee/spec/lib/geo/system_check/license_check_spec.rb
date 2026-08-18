# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::LicenseCheck, feature_category: :geo_replication do
  subject(:license_check) { described_class.new }

  describe '#check?' do
    using RSpec::Parameterized::TableSyntax

    where(:primary, :geo_enabled, :license_allows, :check_result, :pass_message) do
      true | true | true | true | ''
      true | true | false | false | ''
      true | false | true | true | 'License supports Geo, but Geo is not enabled'
      true | false | false | true | 'License does not support Geo, and Geo is not enabled'
      false | true | true | true | ''
      false | true | false | true | 'License only required on a primary site'
      false | false | true | true | ''
      false | false | false | true | ''
    end

    with_them do
      before do
        allow(Gitlab::Geo).to receive_messages(primary?: primary, enabled?: geo_enabled,
          license_allows?: license_allows)
      end

      it 'checks the license' do
        expect(license_check.check?).to eq(check_result)
        expect(described_class.check_pass).to eq(pass_message) if check_result
      end
    end

    describe '#show_error' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(false)
      end

      it 'returns the geo setup/database page' do
        expect(license_check).to receive(:try_fixing_it).with('Add a new license that includes the GitLab Geo feature')
        expect(license_check).to receive(:for_more_information).with('https://about.gitlab.com/solutions/geo/')

        license_check.show_error
      end
    end
  end
end
