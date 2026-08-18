# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::LicenseeMetrics, feature_category: :plan_provisioning do
  let(:expected_value) do
    {
      "Name" => ::License.current.licensee_name,
      "Company" => ::License.current.licensee_company,
      "Email" => ::License.current.licensee_email
    }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }

  context 'without a license' do
    let(:expected_value) do
      {
        'Name' => nil,
        'Company' => nil,
        'Email' => nil
      }
    end

    before do
      allow(::License).to receive(:current).and_return(license)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all' } do
      let(:license) do
        data = Gitlab::License::Encryptor
          .new(OpenSSL::PKey::RSA.generate(3072))
          .encrypt(Gitlab::License.new.to_json)

        build(:license, data: data)
      end
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all' } do
      let(:license) { nil }
    end
  end
end
