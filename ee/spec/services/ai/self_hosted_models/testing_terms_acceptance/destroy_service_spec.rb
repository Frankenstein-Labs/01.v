# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::SelfHostedModels::TestingTermsAcceptance::DestroyService, feature_category: :"self-hosted_models" do
  let_it_be(:testing_terms_acceptance) { create(:ai_testing_terms_acceptances) }

  let(:service) { described_class.new(testing_terms_acceptance) }

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    context 'when the testing terms acceptance is successfully destroyed' do
      it 'returns a success response' do
        expect { result }.to change { ::Ai::TestingTermsAcceptance.count }.by(-1)

        expect(result).to be_success
        expect(result.message).to eq('Testing terms acceptance destroyed')
      end
    end

    context 'when the testing terms acceptance fails to be destroyed' do
      before do
        allow(testing_terms_acceptance).to receive(:destroy).and_return(false)
        allow(testing_terms_acceptance).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])
      end

      it 'returns an error response' do
        expect { result }.not_to change { ::Ai::TestingTermsAcceptance.count }

        expect(result).to be_error
        expect(result.message).to eq('Error message')
      end
    end
  end
end
