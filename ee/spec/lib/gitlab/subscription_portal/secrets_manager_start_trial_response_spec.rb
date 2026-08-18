# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse, feature_category: :secrets_management do
  describe '#initialize' do
    context 'with a successful result' do
      subject(:response) { described_class.new(success: true) }

      it 'is successful with no error details', :aggregate_failures do
        expect(response).to be_success
        expect(response.error_code).to be_nil
        expect(response.error_message).to be_nil
      end
    end

    context 'with a failure result' do
      subject(:response) do
        described_class.new(success: false, error_code: :ineligible, error_message: 'Already used its trial')
      end

      it 'carries the error code and message', :aggregate_failures do
        expect(response).not_to be_success
        expect(response.error_code).to eq(:ineligible)
        expect(response.error_message).to eq('Already used its trial')
      end
    end

    it 'accepts every known error code' do
      described_class::ERROR_CODES.each do |error_code|
        expect { described_class.new(success: false, error_code: error_code) }.not_to raise_error
      end
    end

    context 'with an invalid combination' do
      it 'rejects a success with an error code' do
        expect { described_class.new(success: true, error_code: :ineligible) }
          .to raise_error(ArgumentError, /Invalid start-trial result/)
      end

      it 'rejects a failure with no error code' do
        expect { described_class.new(success: false) }
          .to raise_error(ArgumentError, /Invalid start-trial result/)
      end

      it 'rejects a failure with an unknown error code' do
        expect { described_class.new(success: false, error_code: :something_else) }
          .to raise_error(ArgumentError, /Invalid start-trial result/)
      end
    end
  end
end
