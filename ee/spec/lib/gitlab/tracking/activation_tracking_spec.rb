# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::ActivationTracking, feature_category: :onboarding do
  describe '.track_event' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    context 'when event matches an activation metric enum' do
      it 'calls Activation::Metric.track with the event name as metric type' do
        expect(Activation::Metric).to receive(:track).with(
          :merged_mr,
          user: user,
          namespace: group
        )

        described_class.track_event('merged_mr', user: user, namespace: group)
      end

      context 'when namespace is derived from project' do
        it 'uses the project namespace' do
          expect(Activation::Metric).to receive(:track).with(
            :merged_mr,
            user: user,
            namespace: project.namespace
          )

          described_class.track_event('merged_mr', user: user, project: project)
        end
      end

      context 'when neither namespace nor project is provided' do
        it 'calls Activation::Metric.track with nil namespace' do
          expect(Activation::Metric).to receive(:track).with(
            :merged_mr,
            user: user,
            namespace: nil
          )

          described_class.track_event('merged_mr', user: user)
        end
      end

      context 'when namespace is provided alongside project' do
        it 'prefers the explicit namespace' do
          other_namespace = create(:group)

          expect(Activation::Metric).to receive(:track).with(
            :merged_mr,
            user: user,
            namespace: other_namespace
          )

          described_class.track_event('merged_mr', user: user, project: project, namespace: other_namespace)
        end
      end
    end

    context 'when activation_tracking feature flag is enabled' do
      it 'creates a record in the activation_metrics table' do
        expect do
          described_class.track_event('merged_mr', user: user, namespace: group)
        end.to change { Activation::Metric.count }.by(1)

        record = Activation::Metric.last
        expect(record.user_id).to eq(user.id)
        expect(record.namespace_id).to eq(group.id)
        expect(record.metric).to eq('merged_mr')
      end
    end

    context 'when activation_tracking feature flag is disabled' do
      before do
        stub_feature_flags(activation_tracking: false)
      end

      it 'does not create a record' do
        expect do
          described_class.track_event('merged_mr', user: user, namespace: group)
        end.not_to change { Activation::Metric.count }
      end
    end
  end
end
