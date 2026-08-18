# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Access, :models, feature_category: :plan_provisioning do
  describe 'validations' do
    context 'when invalid catalog JSON is provided' do
      let(:cloud_connector_access) { build(:cloud_connector_access, catalog: 'invalid') }

      it 'is invalid and reports schema error' do
        expect(cloud_connector_access).not_to be_valid
        expect(cloud_connector_access.errors[:catalog]).to include('must be a valid json schema')
      end
    end

    context 'when catalog is nil' do
      let(:cloud_connector_access) { build(:cloud_connector_access, catalog: nil) }

      it 'is invalid and reports presence error' do
        expect(cloud_connector_access).not_to be_valid
        expect(cloud_connector_access.errors[:catalog]).to include("can't be blank")
      end
    end

    context 'when catalog is valid' do
      subject(:cloud_connector_access) { build(:cloud_connector_access) }

      it { is_expected.to be_valid }
    end
  end

  describe 'constants' do
    it 'defines STALE_PERIOD as 3 days' do
      expect(described_class::STALE_PERIOD).to eq(3.days)
    end
  end
end
