# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ThirdPartyFlows::CreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }

  let(:user) { maintainer }
  let(:definition) do
    <<~YAML
      injectGatewayToken: true
      image: example/image:latest
      commands:
        - /bin/bash
      variables:
        - VAL1
        - VAL2
    YAML
  end

  let(:params) do
    {
      name: 'Agent',
      description: 'Description',
      visibility: :restricted,
      definition: definition
    }
  end

  before do
    enable_ai_catalog
  end

  subject(:service) { described_class.new(project: project, current_user: user, params: params) }

  it_behaves_like Ai::Catalog::Items::BaseCreateService do
    let(:expected_item_type) { Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE }
    let(:expected_item_schema_version) { Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION }
    let(:expected_audit_event_create_item_message) { 'Created a new restricted AI external agent' }
    let(:expected_audit_event_item_name) { 'AI external agent' }
    let(:expected_updated_definition) do
      YAML.safe_load(definition).merge('yaml_definition' => definition)
    end

    let(:expected_create_event_properties) do
      {
        label: 'third_party_flow',
        item_type: 'custom_external_agent',
        item_version: '1.0.0',
        custom_item_id: kind_of(Integer)
      }
    end

    it_behaves_like 'yaml definition create service behavior', 'ThirdPartyFlow'

    context 'when ai_catalog_third_party_flows feature flag is disabled' do
      before do
        stub_feature_flags(ai_catalog_third_party_flows: false)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when just the ai_catalog StageCheck passes' do
      let(:third_party_flows_available) { false }

      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(true)
        allow(Gitlab::Llm::StageCheck).to receive(:available?)
          .with(project, :ai_catalog_third_party_flows).and_return(third_party_flows_available)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'

      context 'and the ai_catalog_third_party_flows StageCheck also passes' do
        let(:third_party_flows_available) { true }

        it 'is successful' do
          expect(execute_service).to be_success
        end
      end
    end
  end
end
