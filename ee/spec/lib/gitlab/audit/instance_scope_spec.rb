# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Audit::InstanceScope, feature_category: :audit_events do
  describe '#initialize' do
    it 'sets correct attributes' do
      expect(described_class.new)
        .to have_attributes(id: 1, name: Gitlab::Audit::InstanceScope::SCOPE_NAME,
          full_path: Gitlab::Audit::InstanceScope::SCOPE_NAME)
    end

    describe '#licensed_feature_available?' do
      subject(:instance_scope) { described_class.new.licensed_feature_available?(:external_audit_events) }

      context 'when license is available' do
        before do
          stub_licensed_features(external_audit_events: true)
        end

        it { is_expected.to be_truthy }
      end

      context 'when license is not available' do
        it { is_expected.to be_falsey }
      end

      context 'when aliased to feature_available?' do
        # rubocop:disable Gitlab/FeatureAvailableUsage -- intentional, see below
        # Intentionally use feature_available here since we need consistent
        # call pattern between project, namespace, group, and now instance scopes.
        subject(:instance_scope) { described_class.new.feature_available?(:external_audit_events) }

        # rubocop:enable Gitlab/FeatureAvailableUsage

        it { is_expected.to be_falsey }

        context 'when license is available' do
          before do
            stub_licensed_features(external_audit_events: true)
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end
end
