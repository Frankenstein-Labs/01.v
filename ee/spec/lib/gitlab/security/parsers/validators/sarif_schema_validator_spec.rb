# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Security::Parsers::Validators::SarifSchemaValidator, feature_category: :vulnerability_management do
  subject(:validator) { described_class.new(report_data) }

  context 'with a valid SARIF 2.1.0 document' do
    let(:report_data) do
      Gitlab::Json.safe_parse(
        fixture_file('security_reports/sarif/valid.sarif.json', dir: 'ee')
      )
    end

    it { is_expected.to be_valid }
    it { expect(validator.errors).to be_empty }
  end

  context 'with an unsupported version' do
    let(:report_data) { { 'version' => '2.0.0', 'runs' => [] } }

    it { is_expected.not_to be_valid }
    it { expect(validator.errors.first).to match(/Unsupported SARIF version/) }
  end

  context 'with a nil version' do
    let(:report_data) { { 'runs' => [] } }

    it { is_expected.not_to be_valid }
    it { expect(validator.errors.first).to match(/Unsupported SARIF version/) }
  end

  context 'with a non-Hash input' do
    let(:report_data) { [] }

    it { is_expected.not_to be_valid }
    it { expect(validator.errors.first).to match(/Expected JSON object but received Array/) }
  end

  context 'with a schema-invalid document' do
    let(:report_data) { { 'version' => '2.1.0' } }

    it { is_expected.not_to be_valid }
  end
end
