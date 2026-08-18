# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../../tooling/dast_variables/docs/renderer'

RSpec.describe 'gitlab:dast_variables rake tasks', feature_category: :dynamic_application_security_testing do
  output_file = Rails.root.join("doc/user/application_security/dast/browser/configuration/variables.md")
  template_file = Rails.root.join("tooling/dast_variables/docs/templates/default.md.haml")
  variables_content = "some variables"

  before do
    Rake.application.rake_require('tasks/gitlab/dast_variables')
    stub_file_read(output_file, content: variables_content)
  end

  let(:renderer) { instance_double(Tooling::DastVariables::Docs::Renderer) }

  describe 'compile_docs' do
    it 'generates the variables documentation' do
      expect(Tooling::DastVariables::Docs::Renderer).to receive(:new).with({
        output_file: output_file,
        template: template_file
      }).and_return(renderer)
      expect(renderer).to receive(:write)

      run_rake_task('gitlab:dast_variables:compile_docs')
    end
  end

  describe 'check_docs' do
    it 'checks whether documentation matches variable data' do
      expect(Tooling::DastVariables::Docs::Renderer).to receive(:new).with({
        output_file: output_file,
        template: template_file
      }).and_return(renderer)
      expect(renderer).to receive(:contents).and_return(variables_content)

      run_rake_task('gitlab:dast_variables:check_docs')
    end

    it 'raises an error when documentation does not match variable data' do
      expect(Tooling::DastVariables::Docs::Renderer).to receive(:new).with({
        output_file: output_file,
        template: template_file
      }).and_return(renderer)
      expect(renderer).to receive(:contents).and_return("other variables")

      expect { run_rake_task('gitlab:dast_variables:check_docs') }
        .to raise_error(RuntimeError)
          .with_message(a_string_including('DAST variables documentation is outdated'))
    end
  end
end
