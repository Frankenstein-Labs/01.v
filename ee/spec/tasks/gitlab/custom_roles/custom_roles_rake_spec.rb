# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/tasks/gitlab/custom_roles/compile_docs_task'

RSpec.describe 'gitlab:custom_roles rake tasks', :silence_stdout, feature_category: :permissions do
  before do
    Rake.application.rake_require('tasks/gitlab/custom_roles/custom_roles')
    stub_env('VERBOSE' => 'true')
  end

  describe 'compile_docs' do
    it 'invokes Gitlab::CustomRoles::CompileDocsTask with correct arguments' do
      compile_docs_task = instance_double(Tasks::Gitlab::CustomRoles::CompileDocsTask)

      expect(Tasks::Gitlab::CustomRoles::CompileDocsTask).to receive(:new).with(
        Rails.root.join("doc/user/custom_roles"),
        Rails.root.join("doc/user/custom_roles/abilities.md"),
        Rails.root.join("tooling/custom_roles/docs/templates/custom_abilities.md.erb")).and_return(compile_docs_task)

      expect(compile_docs_task).to receive(:run)

      run_rake_task('gitlab:custom_roles:compile_docs')
    end
  end

  describe 'check_docs' do
    it 'invokes Gitlab::CustomRoles::CheckDocsTask with correct arguments' do
      check_docs_task = instance_double(Tasks::Gitlab::CustomRoles::CheckDocsTask)

      expect(Tasks::Gitlab::CustomRoles::CheckDocsTask).to receive(:new).with(
        Rails.root.join("doc/user/custom_roles"),
        Rails.root.join("doc/user/custom_roles/abilities.md"),
        Rails.root.join("tooling/custom_roles/docs/templates/custom_abilities.md.erb")).and_return(check_docs_task)

      expect(check_docs_task).to receive(:run)

      run_rake_task('gitlab:custom_roles:check_docs')
    end
  end
end
