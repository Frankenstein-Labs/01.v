# frozen_string_literal: true

RSpec.shared_examples 'audit event for variable access' do |variable_type|
  let(:audited_variable) { create(variable_type, **variable_attributes) }

  before do
    stub_licensed_features(audit_events: true)
  end

  context 'when variable is not hidden' do
    let(:is_hidden_variable) { false }
    let(:is_masked_variable) { false }

    it 'audits variable access' do
      expected_audit_context = {
        name: 'variable_viewed_api',
        author: user,
        scope: expected_entity,
        target: audited_variable,
        message: "CI/CD variable '#{audited_variable.key}' accessed with the API"
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

      make_request
    end
  end

  context 'when variable is hidden' do
    let(:is_hidden_variable) { true }
    let(:is_masked_variable) { true }

    it 'audits hidden variable access' do
      expected_audit_context = {
        name: 'variable_viewed_api',
        author: user,
        scope: expected_entity,
        target: audited_variable,
        message: "CI/CD variable '#{audited_variable.key}' accessed with the API (hidden variable, no value shown)"
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

      make_request
    end
  end
end
