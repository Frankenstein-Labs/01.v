# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::LicenseProbe, feature_category: :duo_setting do
  describe '#execute', :with_license do
    using RSpec::Parameterized::TableSyntax

    subject(:probe) { described_class.new }

    before do
      allow(License).to receive(:current).and_return(license)
    end

    where(:exists?, :cloud, :expired, :trial, :success?, :message) do
      false | false | false  | false  | false | 'Contact GitLab customer support to obtain a license'
      true  | true  | true   | true   | true  | 'Subscription can be synchronized'
      true  | true  | true   | false  | true  | 'Subscription can be synchronized'
      true  | true  | false  | true   | true  | 'Subscription can be synchronized'
      true  | true  | false  | false  | true  | 'Subscription can be synchronized'
      true  | false | true   | true   | false | 'Contact GitLab customer support to upgrade your license'
      true  | false | true   | false  | false | 'Contact GitLab customer support to upgrade your license'
      true  | false | false  | true   | false | 'Contact GitLab customer support to upgrade your license'
      true  | false | false  | false  | false | 'Contact GitLab customer support to upgrade your license'
    end

    with_them do
      let(:license) { build(:license, cloud: cloud, expired: expired, trial: trial) if exists? }

      it 'returns a correct result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be success?
        expect(result.message).to match(message)
        expect(result.details).to include(
          instance_id: Gitlab::GlobalAnonymousId.instance_id,
          gitlab_version: Gitlab::VERSION
        )

        if exists?
          expect(result.details[:license]).to include(license.license.as_json)
        else
          expect(result.details[:license]).to be_nil
        end
      end
    end
  end
end
