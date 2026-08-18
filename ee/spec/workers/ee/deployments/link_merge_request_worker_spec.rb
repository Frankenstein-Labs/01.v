# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Deployments::LinkMergeRequestWorker, feature_category: :continuous_integration do
  subject(:perform) { described_class.new.perform(deployment.id) }

  describe '#execute' do
    context 'when deployment is successful' do
      let(:deployment) { create(:deployment, :success) }

      it 'triggers dora watcher' do
        expect(Dora::Watchers).to receive(:process_event).with(deployment, :successful)

        perform
      end
    end

    context 'with non-successful deployment' do
      let(:deployment) { create(:deployment, :canceled) }

      it 'does not trigger dora watcher' do
        expect(Dora::Watchers).not_to receive(:process_event)

        perform
      end
    end
  end
end
