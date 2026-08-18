# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::SlackInteractions::ViewSubmissionService, feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:execute) { described_class.new(params).execute }

    let(:params) do
      {
        view: { callback_id: ::Integrations::SlackInteractions::DuoFeedbackModal::CALLBACK_ID },
        foo: 'bar'
      }
    end

    it 'delegates Duo feedback modal submissions to the EE handler' do
      expect_next_instance_of(
        Integrations::SlackInteractions::DuoFeedbackModalSubmitService, params
      ) do |service|
        expect(service).to receive(:execute).and_return(ServiceResponse.success)
      end

      execute
    end
  end
end
