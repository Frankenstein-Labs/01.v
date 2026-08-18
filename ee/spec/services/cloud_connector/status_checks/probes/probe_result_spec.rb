# frozen_string_literal: true

require 'fast_spec_helper'
require 'gitlab/cloud_connector'
require_relative "../../../../../app/services/cloud_connector/status_checks/probes/probe_result"

RSpec.describe CloudConnector::StatusChecks::Probes::ProbeResult, feature_category: :duo_setting do
  let(:name) { 'Test Probe' }
  let(:success) { true }
  let(:message) { 'Probe successful' }
  let(:details) { { key: 'value' } }
  let(:errors) { ['An error occurred'] }
  let(:probe_result) { described_class.new(name, success, message, details, errors) }

  describe '#success?' do
    context 'when success is true' do
      it 'returns true' do
        expect(probe_result.success?).to be true
      end
    end

    context 'when success is false' do
      let(:success) { false }

      it 'returns false' do
        expect(probe_result.success?).to be false
      end
    end

    context 'when success is nil' do
      let(:success) { nil }

      it 'returns false' do
        expect(probe_result.success?).to be false
      end
    end
  end

  describe 'attribute readers' do
    it 'allows reading of name attribute' do
      expect(probe_result.name).to eq(name)
    end

    it 'allows reading of success attribute' do
      expect(probe_result.success).to eq(success)
    end

    it 'allows reading of message attribute' do
      expect(probe_result.message).to eq(message)
    end

    it 'allows reading of details attribute' do
      expect(probe_result.details).to eq(details)
    end

    it 'allows reading of errors attribute' do
      expect(probe_result.errors).to eq(errors)
    end
  end

  describe '#initialize' do
    context 'when details and errors are not provided' do
      let(:probe_result) { described_class.new(name, success, message) }

      it 'defaults details to an empty array' do
        expect(probe_result.details).to eq([])
      end

      it 'defaults errors to an empty array' do
        expect(probe_result.errors).to eq([])
      end
    end
  end
end
