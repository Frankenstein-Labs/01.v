# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::Security::Report, feature_category: :vulnerability_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }

  let(:created_at) { 2.weeks.ago }

  subject(:report) { described_class.new('sast', pipeline, created_at) }

  describe '#tracked_context' do
    subject(:tracked_context) { report.tracked_context }

    context 'when a tracked context exists for the pipeline' do
      it 'returns the tracked context' do
        tracked = instance_double(Security::ProjectTrackedContext)
        allow(Security::ProjectTrackedContext)
          .to receive_message_chain(:for_pipeline, :tracked, :first)
          .and_return(tracked)
        expect(Security::ProjectTrackedContext).to receive(:for_pipeline).with(pipeline)

        expect(tracked_context).to eq(tracked)
      end
    end

    context 'when no tracked context exists for the pipeline' do
      it 'returns nil' do
        allow(Security::ProjectTrackedContext)
          .to receive_message_chain(:for_pipeline, :tracked, :first)
          .and_return(nil)
        expect(Security::ProjectTrackedContext).to receive(:for_pipeline).with(pipeline)

        expect(tracked_context).to be_nil
      end
    end
  end
end
