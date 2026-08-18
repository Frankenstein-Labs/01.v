# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'policy rule' do
  let_it_be(:policy_configuration, freeze: false) { create(:security_orchestration_policy_configuration) }
  let(:attributes) { described_class.attributes_from_rule_hash(rule_hash, policy_configuration) }

  describe '::attributes_from_rule_hash' do
    subject { attributes }

    it { is_expected.to include(content: rule_hash.except(:type)) }

    describe 'type' do
      subject(:type) { attributes[:type] }

      it { is_expected.to eq(rule_hash[:type]) }
    end
  end

  describe '#typed_content' do
    let(:rule) do
      Security::PolicyRule
        .for_policy_type(policy_type)
        .new
        .tap { |rule| rule.assign_attributes(attributes) }
    end

    subject(:typed_content) { rule.typed_content }

    it { is_expected.to include(rule_hash.except(:type).deep_stringify_keys) }

    it { is_expected.to include("type" => rule.type) }
  end
end
