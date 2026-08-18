# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/tasks/gitlab/custom_roles/compile_docs_task'
require_relative '../../../../lib/tasks/gitlab/custom_roles/check_docs_task'

RSpec.describe Tasks::Gitlab::CustomRoles::CheckDocsTask, feature_category: :permissions, quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9502' do
  let(:docs_dir) { Rails.root.join("tmp/tests/doc/administration/custom_roles") }
  let(:docs_path) { Rails.root.join(docs_dir, 'abilities.md') }
  let(:template_erb_path) { Rails.root.join("tooling/custom_roles/docs/templates/custom_abilities.md.erb") }

  let(:stub_definitions) do
    expect(::MemberRole).to receive(:all_customizable_permissions).and_return(updated_definitions)
  end

  describe '#run' do
    before do
      Tasks::Gitlab::CustomRoles::CompileDocsTask.new(docs_dir, docs_path, template_erb_path).run
    end

    let(:new_ability) do
      { new_ability: {
        name: 'new_ability',
        description: 'some description',
        feature_category: 'code_review_workflow'
      } }
    end

    let(:added_definition) { MemberRole.all_customizable_permissions.merge(new_ability) }
    let(:removed_definition) { MemberRole.all_customizable_permissions.except(:admin_terraform_state) }
    let(:updated_definition) do
      definitions = MemberRole.all_customizable_permissions
      definitions[:read_code][:milestone] = '12.0'

      definitions
    end

    let(:success_message) { "Custom roles documentation is up to date.\n" }
    let(:error_message) do
      "Custom roles documentation is outdated! Please update it " \
        "by running `bundle exec rake gitlab:custom_roles:compile_docs`"
    end

    it_behaves_like 'checks if the doc is up-to-date'
  end
end
