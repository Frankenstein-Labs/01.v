# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::SelfHostedModels::TestingTermsAcceptance::CreateService, feature_category: :"self-hosted_models" do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }

  before do
    allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
  end

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    let(:testing_terms_acceptance) { result.payload }
    let(:audit_event) do
      {
        name: 'self_hosted_model_terms_accepted',
        author: user,
        scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
        target: testing_terms_acceptance,
        message: "Self-hosted model testing terms accepted by user - ID: #{user.id}, email: #{user.email}"
      }
    end

    it 'creates a testing terms acceptance record' do
      expect { result }.to change { ::Ai::TestingTermsAcceptance.count }.by(1)
      expect(result).to be_success

      expect(testing_terms_acceptance.user_id).to eq(user.id)
      expect(testing_terms_acceptance.user_email).to eq(user.email)

      expect(Gitlab::Audit::Auditor).to have_received(:audit).with(audit_event)
    end

    context 'when there is an error saving the testing terms acceptance record' do
      before do
        allow_next_instance_of(::Ai::TestingTermsAcceptance) do |instance|
          allow(instance).to receive(:save).and_return(false)
        end
      end

      it 'returns an error response' do
        expect { result }.not_to change { ::Ai::TestingTermsAcceptance.count }

        expect(result).to be_error

        expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(
          hash_including(name: "self_hosted_model_terms_accepted")
        )
      end
    end
  end
end
