# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::HistoricalMaxUsersMetric, feature_category: :plan_provisioning do
  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', data_source: 'ruby' } do
    let(:expected_value) { ::License.current.historical_max }
  end

  context 'without a valid license' do
    let(:expected_value) { nil }

    before do
      allow(::License).to receive(:current).and_return(license)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all' } do
      let(:license) { nil }
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all' } do
      let(:license) do
        data = Gitlab::License::Encryptor
          .new(OpenSSL::PKey::RSA.generate(3072))
          .encrypt(Gitlab::License.new.to_json)

        build(:license, data: data)
      end
    end
  end
end
