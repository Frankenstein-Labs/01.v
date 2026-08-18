# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::ModelDefinitions, feature_category: :"self-hosted_models" do
  let(:user) { build_stubbed(:user) }
  let(:payload) do
    {
      'models' => [{ 'identifier' => 'claude', 'name' => 'Claude', 'provider' => 'Anthropic' }],
      'unit_primitives' => []
    }
  end

  let(:service_response) { ServiceResponse.success(payload: payload) }

  subject(:catalog) { described_class.fetch(user) }

  before do
    allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService, user) do |service|
      allow(service).to receive(:execute).and_return(service_response)
    end
  end

  describe '.fetch' do
    it 'builds the catalog from the fetch service' do
      expect_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService, user) do |service|
        expect(service).to receive(:execute).and_return(service_response)
      end

      catalog
    end
  end

  context 'when the fetch succeeds' do
    it 'is successful and exposes the payload with no error message', :aggregate_failures do
      expect(catalog).to be_success
      expect(catalog.payload).to eq(payload)
      expect(catalog.error_message).to be_nil
    end

    it 'builds a parser over the payload' do
      expect(catalog.parser.model_with_ref('claude')).to include('ref' => 'claude', 'name' => 'Claude')
    end
  end

  context 'when the fetch succeeds with a nil payload' do
    let(:service_response) { ServiceResponse.success(payload: nil) }

    it 'is successful with a nil payload', :aggregate_failures do
      expect(catalog).to be_success
      expect(catalog.payload).to be_nil
    end

    it 'does not build a parser' do
      expect(catalog.parser).to be_nil
    end
  end

  context 'when the fetch fails' do
    let(:service_response) { ServiceResponse.error(message: 'boom') }

    it 'is not successful and surfaces the error message', :aggregate_failures do
      expect(catalog).not_to be_success
      expect(catalog.payload).to be_nil
      expect(catalog.error_message).to eq('boom')
    end

    it 'does not build a parser' do
      expect(catalog.parser).to be_nil
    end
  end
end
