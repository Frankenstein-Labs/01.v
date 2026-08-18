# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::StatusService, feature_category: :instance_resiliency do
  include StubRequests

  subject(:status) { described_class.new.execute }

  describe '#execute' do
    context 'when a response from arkose is received' do
      before do
        stub_full_request(described_class::ARKOSE_STATUS_URL).and_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: arkose_response_body.to_json
        )
      end

      context 'when arkose is operational' do
        let(:arkose_response_body) { { 'status' => { 'indicator' => 'none' } } }

        it 'returns a success response' do
          expect(status).to be_success
        end
      end

      context 'when arkose outage is minor' do
        let(:arkose_response_body) { { 'status' => { 'indicator' => 'minor' } } }

        it 'returns a success response' do
          expect(status).to be_success
        end
      end

      context 'when arkose outage is critical' do
        let(:arkose_response_body) { { 'status' => { 'indicator' => 'critical' } } }
        let(:error_message) { 'Arkose outage, status: critical' }

        it 'returns an error response' do
          expect(status).to be_error
        end

        it 'returns an error message' do
          expect(subject.message).to eq error_message
        end

        it 'logs an error message' do
          expect(Gitlab::AppLogger).to receive(:error).with(error_message)

          status
        end
      end
    end

    context 'when the request is unsuccessful' do
      let(:error_message) { 'Arkose outage, status: unknown' }

      before do
        stub_full_request(described_class::ARKOSE_STATUS_URL).and_return(
          status: 500
        )
      end

      it 'returns an error response' do
        expect(status).to be_error
      end

      it 'returns an error message' do
        expect(subject.message).to eq error_message
      end

      it 'logs an error message' do
        expect(Gitlab::AppLogger).to receive(:error).with(error_message)

        status
      end
    end

    context 'when an http error is raised' do
      let(:error_message) { 'Arkose outage, status: unknown' }

      before do
        stub_full_request(described_class::ARKOSE_STATUS_URL).and_raise(Timeout::Error)
      end

      it 'returns an error response' do
        expect(status).to be_error
      end

      it 'returns an error message' do
        expect(subject.message).to eq error_message
      end

      it 'logs an error message' do
        expect(Gitlab::AppLogger).to receive(:error).with(error_message)

        status
      end
    end
  end
end
