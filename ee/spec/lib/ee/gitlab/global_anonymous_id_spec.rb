# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GlobalAnonymousId, feature_category: :subscription_management do
  describe '.self_managed_instance_identifier' do
    subject { described_class.self_managed_instance_identifier }

    context 'when on trial license' do
      before do
        create_current_license(:trial)
      end

      it { is_expected.to eq(described_class.instance_uuid) }
    end

    context 'when on paid license' do
      before do
        create_current_license
      end

      it { is_expected.to eq(described_class.instance_id) }
    end

    context 'when no license exists', :without_license do
      it { is_expected.to eq(described_class.instance_id) }
    end
  end
end
