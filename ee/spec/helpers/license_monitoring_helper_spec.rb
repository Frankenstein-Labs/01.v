# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseMonitoringHelper, feature_category: :plan_provisioning do
  using RSpec::Parameterized::TableSyntax

  let(:license) { build_stubbed(:gitlab_license) }

  describe '#users_over_license' do
    subject { helper.users_over_license }

    before do
      allow(Gitlab).to receive(:com?).and_return(false)
      allow(License).to receive(:current).and_return(license)
      allow(license).to receive(:overage_with_historical_max).and_return(10)
    end

    it { is_expected.to eq(10) }

    context 'when in GitLab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      it 'returns 0 overage' do
        is_expected.to eq(0)
      end
    end

    context 'when license is not available' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'returns 0 overage' do
        is_expected.to eq(0)
      end
    end

    context 'when there is no overage' do
      before do
        allow(license).to receive(:overage_with_historical_max).and_return(0)
      end

      it 'returns 0 overage' do
        is_expected.to eq(0)
      end
    end
  end
end
