# frozen_string_literal: true

require 'spec_helper'
require 'rake'

RSpec.describe 'compliance_management:control_schema rake tasks', feature_category: :compliance_management do
  before :all do
    Rake.application.rake_require 'tasks/compliance_management/control_schema'
    Rake::Task.define_task(:environment)
  end

  describe 'compliance_management:control_schema:generate' do
    let(:schema_path) do
      Rails.root.join('ee/app/validators/json_schemas/compliance_requirements_control_expression.json')
    end

    let(:controls_path) { Rails.root.join('ee/config/compliance_management/requirement_controls.json') }

    before do
      allow(File).to receive(:write).and_return(true)
      allow(ComplianceManagement::ComplianceFramework::Controls::Registry)
        .to receive(:validate_registry!).and_return(true)

      Rake::Task['compliance_management:control_schema:generate'].reenable
    end

    it 'generates schema and control definition files' do
      expect(File).to receive(:write).with(schema_path, anything)
      expect(File).to receive(:write).with(controls_path, anything)

      Rake::Task['compliance_management:control_schema:generate'].invoke
    end

    it 'validates registry order' do
      expect(ComplianceManagement::ComplianceFramework::Controls::Registry).to receive(:validate_registry!)

      Rake::Task['compliance_management:control_schema:generate'].invoke
    end

    context 'when registry order is invalid' do
      before do
        allow(ComplianceManagement::ComplianceFramework::Controls::Registry).to receive(:validate_registry!)
          .and_raise(RuntimeError, "Control registry order violation: expected control1 at position 0, found control2")
      end

      it 'warns about order violation but continues' do
        expect { Rake::Task['compliance_management:control_schema:generate'].invoke }
          .to output(/WARNING: Control registry order violation/).to_stdout
      end
    end
  end
end
