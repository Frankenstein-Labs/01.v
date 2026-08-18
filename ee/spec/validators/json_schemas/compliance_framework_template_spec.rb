# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'compliance_framework_template.json', feature_category: :compliance_management do
  let(:schema_path) do
    Rails.root.join("ee/app/validators/json_schemas/compliance_framework_template.json")
  end

  let(:schema) { JSONSchemer.schema(schema_path) }
  let(:templates_path) { Rails.root.join('ee/config/compliance_management/templates') }

  describe 'all template files conform to schema' do
    Dir.glob(Rails.root.join('ee/config/compliance_management/templates/*.json')).each do |file_path|
      template_id = File.basename(file_path, '.json')

      context "with #{template_id} template" do
        let(:template) { ::Gitlab::Json.safe_parse(File.read(file_path)) }

        it 'is valid' do
          errors = schema.validate(template).map { |e| JSONSchemer::Errors.pretty(e) }

          expect(errors).to be_empty
        end
      end
    end
  end

  describe 'schema rejects invalid templates' do
    it 'rejects a template without version' do
      template = { "name" => "Test", "description" => "Desc", "color" => "#000000", "requirements" => [] }

      expect(schema.valid?(template)).to be false
    end

    it 'rejects a template with empty requirements' do
      template = { "version" => 1, "name" => "Test", "description" => "Desc", "color" => "#000000",
                   "requirements" => [] }

      expect(schema.valid?(template)).to be false
    end

    it 'rejects a template with missing name' do
      template = { "version" => 1, "description" => "Desc", "color" => "#000000",
                   "requirements" => [{ "name" => "R1", "description" => "D1",
                                        "controls" => [valid_control] }] }

      expect(schema.valid?(template)).to be false
    end

    it 'rejects a template with invalid color' do
      template = { "version" => 1, "name" => "Test", "description" => "Desc", "color" => "not-a-color",
                   "requirements" => [{ "name" => "R1", "description" => "D1",
                                        "controls" => [valid_control] }] }

      expect(schema.valid?(template)).to be false
    end

    it 'rejects a requirement with empty controls' do
      template = { "version" => 1, "name" => "Test", "description" => "Desc", "color" => "#000000",
                   "requirements" => [{ "name" => "R1", "description" => "D1", "controls" => [] }] }

      expect(schema.valid?(template)).to be false
    end

    it 'rejects a control with invalid control_type' do
      control = valid_control.merge("control_type" => "unknown")
      template = valid_template(controls: [control])

      expect(schema.valid?(template)).to be false
    end

    it 'rejects a control missing expression' do
      control = { "name" => "test_control", "control_type" => "internal" }
      template = valid_template(controls: [control])

      expect(schema.valid?(template)).to be false
    end

    it 'rejects additional properties at top level' do
      template = valid_template.merge("extra_field" => "value")

      expect(schema.valid?(template)).to be false
    end
  end

  def valid_control
    {
      "name" => "test_control",
      "control_type" => "internal",
      "expression" => { "operator" => "=", "field" => "test_field", "value" => true }
    }
  end

  def valid_template(controls: [valid_control])
    {
      "version" => 1,
      "name" => "Test",
      "description" => "Desc",
      "color" => "#000000",
      "requirements" => [{ "name" => "R1", "description" => "D1", "controls" => controls }]
    }
  end
end
