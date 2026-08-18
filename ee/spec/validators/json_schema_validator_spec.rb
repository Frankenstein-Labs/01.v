# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JsonSchemaValidator do
  describe '#validates_each' do
    let(:validator) { described_class.new(attributes: [:foo], filename: schema_name, base_directory: %w[spec fixtures]) }
    let(:fake_draft) { double('Draft7', valid?: true) }

    let(:schema_name) { 'sample_schema' }
    let(:ce_path) { Rails.root.join('spec', 'fixtures', 'sample_schema.json') }
    let(:ee_path) { Rails.root.join('ee', 'spec', 'fixtures', 'sample_schema.json') }

    subject(:validate_subject) { validator.validate_each(double(:subject), :foo, 'bar') }

    before do
      allow(JSONSchemer).to receive(:schema).with(expected_schema_path).and_return(fake_draft)
    end

    context 'when the schema file exists on CE' do
      let(:expected_schema_path) { ce_path }

      before do
        allow(File).to receive(:exist?).with(ce_path).and_return(true)
        allow(File).to receive(:exist?).with(ee_path).and_return(false)
      end

      it 'calls the validator with CE schema' do
        validate_subject

        expect(fake_draft).to have_received(:valid?)
      end
    end

    context 'when the schema file exists on EE' do
      let(:expected_schema_path) { ee_path }

      before do
        allow(File).to receive(:exist?).with(ce_path).and_return(false)
        allow(File).to receive(:exist?).with(ee_path).and_return(true)
      end

      it 'calls the validator with EE schema' do
        validate_subject

        expect(fake_draft).to have_received(:valid?)
      end
    end

    context 'when both schema files exist' do
      let(:expected_schema_path) { ee_path }

      before do
        allow(File).to receive(:exist?).with(ce_path).and_return(true)
        allow(File).to receive(:exist?).with(ee_path).and_return(true)
      end

      it 'calls the validator with EE schema' do
        validate_subject

        expect(fake_draft).to have_received(:valid?)
      end
    end

    context 'when no schema file exist' do
      let(:expected_schema_path) { nil }

      before do
        allow(File).to receive(:exist?).with(ce_path).and_return(false)
        allow(File).to receive(:exist?).with(ee_path).and_return(false)
      end

      it 'calls the validator with EE schema' do
        expect do
          validate_subject
        end.to raise_error("No json validation schema `sample_schema.json` found")

        expect(fake_draft).not_to have_received(:valid?)
      end
    end
  end
end
