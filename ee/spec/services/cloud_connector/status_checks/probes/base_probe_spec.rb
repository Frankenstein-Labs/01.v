# frozen_string_literal: true

require 'spec_helper'
require_relative 'test_probe'

RSpec.describe CloudConnector::StatusChecks::Probes::BaseProbe, feature_category: :duo_setting do
  subject(:test_probe) { test_probe_class.new(**params) }

  let(:params) { { success: true } }
  let(:test_probe_class) { CloudConnector::StatusChecks::Probes::TestProbe }

  describe '#execute' do
    context 'when #success_message is not implemented in subclass' do
      let(:params) { {} }
      let(:test_probe_class) { Class.new(described_class) }

      before do
        stub_const('TestProbe', test_probe_class)
      end

      it 'raises a NotImplementedError when success_message is not implemented' do
        expect { test_probe.execute }.to raise_error(NotImplementedError, "TestProbe must implement #success_message")
      end
    end

    context 'when #success_message is implemented in subclass' do
      context 'when validation passes' do
        it 'returns a successful ProbeResult' do
          result = test_probe.execute

          expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
          expect(result.success?).to be true
          expect(result.message).to eq('OK')
          expect(result.name).to eq(:test_probe)
          expect(result.errors).to be_empty
          expect(result.details).to include(test: 'true')
        end
      end

      context 'when validation fails' do
        let(:params) { { success: false } }

        it 'returns a failed ProbeResult with validation errors' do
          result = test_probe.execute

          expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
          expect(result.success?).to be false
          expect(result.message).to eq('NOK')
          expect(result.name).to eq(:test_probe)
          expect(result.errors.full_messages).to match_array(%w[NOK])
          expect(result.details).to include(test: 'true')
        end
      end
    end
  end
end
