# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::Base, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:flow_item) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent_item_1) { create(:ai_catalog_agent, project: project) }
  let_it_be(:agent_item_2) { create(:ai_catalog_agent, project: project) }

  let(:flow) { flow_item }
  let(:params) { { my_param: 1 } }
  let(:pinned_version_prefix) { '1.1' }

  subject(:builder) { described_class.new(flow, pinned_version_prefix:, params:) }

  describe 'includes' do
    it 'includes Gitlab::Utils::StrongMemoize' do
      expect(described_class.included_modules).to include(Gitlab::Utils::StrongMemoize)
    end

    it 'includes ActiveModel::Model' do
      expect(described_class.included_modules).to include(ActiveModel::Model)
    end
  end

  describe '#initialize' do
    it 'sets instance variables' do
      expect(builder.instance_variable_get(:@flow)).to eq(flow)
      expect(builder.instance_variable_get(:@pinned_version_prefix)).to eq(pinned_version_prefix)
      expect(builder.instance_variable_get(:@params)).to eq(params)
    end
  end

  describe 'validation' do
    shared_examples 'raises validation error' do |expected_error|
      it 'raises an ArgumentError' do
        expect { builder.build }.to raise_error(ArgumentError, expected_error)
      end
    end

    context 'when flow is nil' do
      let(:flow) { nil }

      it_behaves_like 'raises validation error', 'Flow is required'
    end

    context 'when flow is not a flow type' do
      let(:flow) { build(:ai_catalog_agent) }

      it_behaves_like 'raises validation error', 'Flow must have item_type of flow'
    end

    context 'when flow is other records than Ai::Catalog::Item' do
      let(:flow) { project }

      it_behaves_like 'raises validation error', 'Flow must be an Ai::Catalog::Item'
    end
  end

  describe '#build' do
    it 'calls build_flow_config' do
      expect(builder).to receive(:build_flow_config)
      builder.build
    end
  end
end
