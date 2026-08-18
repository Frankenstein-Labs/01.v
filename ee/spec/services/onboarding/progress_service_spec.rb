# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::ProgressService, feature_category: :onboarding do
  let(:action) { :merge_request_created }

  describe '.async' do
    let(:namespace_id) { non_existing_record_id }
    let(:namespace) { build(:namespace, id: namespace_id) }
    let(:onboarding_enabled?) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled?)
    end

    subject(:async) { described_class.async(namespace.id, action) }

    context 'when the SaaS feature onboarding is available' do
      it 'schedules a worker ensuring the action is converted to a string for general async param guidelines' do
        expect(::Onboarding::ProgressTrackingWorker).to receive(:perform_async).with(namespace_id, action.to_s)

        async
      end
    end

    context 'when the SaaS feature onboarding is not available' do
      let(:onboarding_enabled?) { false }

      it 'does not schedule a worker' do
        expect(::Onboarding::ProgressTrackingWorker).not_to receive(:perform_async)

        async
      end
    end
  end

  describe '#execute' do
    let(:namespace) { create(:namespace) }

    subject(:execute_service) { described_class.new(namespace).execute(action: action) }

    context 'when the namespace is a root' do
      before do
        Onboarding::Progress.onboard(namespace)
      end

      it 'registers a namespace onboarding progress action for the given namespace' do
        execute_service

        expect(Onboarding::Progress.completed?(namespace, action)).to be(true)
      end
    end

    context 'when the namespace is not the root' do
      let(:group) { create(:group, :nested) }

      before do
        Onboarding::Progress.onboard(group)
      end

      it 'does not register a namespace onboarding progress action' do
        execute_service

        expect(Onboarding::Progress.completed?(group, action)).to be(false)
      end
    end

    context 'when no namespace is passed' do
      let(:namespace) { nil }

      it 'does not register a namespace onboarding progress action' do
        execute_service

        expect(Onboarding::Progress.completed?(namespace, action)).to be(false)
      end
    end
  end
end
