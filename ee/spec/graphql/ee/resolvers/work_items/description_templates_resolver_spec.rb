# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::WorkItems::DescriptionTemplatesResolver, feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) do
    create(:group).tap do |g|
      g.add_owner(user)
    end
  end

  let_it_be(:sub_group) do
    create(:group, parent: group).tap do |g|
      g.add_owner(user)
    end
  end

  let_it_be(:template_files) do
    {
      ".gitlab/issue_templates/project_issues_template_a.md" => "project_issues_template_a content",
      ".gitlab/issue_templates/project_issues_template_b.md" => "project_issues_template_b content"
    }
  end

  let_it_be_with_reload(:project) do
    create(:project, :custom_repo, files: template_files, group: group)
       .tap { |p| group.file_template_project_id = p.id }
  end

  let_it_be_with_reload(:no_files_project) { create(:project, :custom_repo, group: group) }

  let_it_be(:no_files_project_namespace) { no_files_project.project_namespace }

  let_it_be(:project_namespace) { project.project_namespace }

  before do
    stub_licensed_features(custom_file_templates: true, custom_file_templates_for_namespace: true)
    set_file_template_project_id(group, project.id)
  end

  describe '#resolve' do
    it 'returns from ancestor projects when sub-group has no file template project set' do
      templates = resolve_templates

      templates.items.each_with_index do |template, index|
        expect(".gitlab/issue_templates/#{template.name}.md").to eq(template_files.to_a[index][0])
        expect(template.content).to eq(template_files.to_a[index][1])
        expect(template.category).to eq("Group #{group.name}")
        expect(template.project_id).to eq(project.id)
      end
    end

    it 'filters out the project level templates when a group is queried' do
      templates = resolve_templates(group: group)
      templates.items.each_with_index do |template, index|
        expect(".gitlab/issue_templates/#{template.name}.md").to eq(template_files.to_a[index][0])
        expect(template.content).to eq(template_files.to_a[index][1])
        expect(template.category).to eq("Group #{group.name}")
        expect(template.project_id).to eq(project.id)
      end
    end

    context 'with project settings default template' do
      it 'prepends settings default template when project has issues_template configured' do
        project.update!(issues_template: 'Default template content from settings')

        templates = resolve_templates
        first_template = templates.items.first

        expect(first_template).to have_attributes(
          name: 'Default (Project Settings)',
          category: 'Project Templates',
          project_id: project.id,
          content: 'Default template content from settings'
        )
        expect(templates.items.size).to eq(3)
      end

      it 'does not include settings default template when project has no issues_template' do
        project.update!(issues_template: nil)

        templates = resolve_templates

        expect(templates.items.size).to eq(2)
        expect(templates.items.map(&:name)).not_to include('Default (Project Settings)')
      end

      it 'does not include settings default template when issues_template is empty' do
        project.update!(issues_template: '')

        templates = resolve_templates

        expect(templates.items.size).to eq(2)
        expect(templates.items.map(&:name)).not_to include('Default (Project Settings)')
      end

      it 'includes settings default template when project has only issues_template and no file templates' do
        set_file_template_project_id(group, no_files_project.id)
        no_files_project.update!(issues_template: 'Default template content from settings')

        templates = resolve_templates(group: sub_group)

        expect(templates.items.size).to eq(1)
        expect(templates.items.first).to have_attributes(
          name: 'Default (Project Settings)',
          category: 'Project Templates',
          project_id: no_files_project.id,
          content: 'Default template content from settings'
        )
      end
    end
  end

  def resolve_templates(args: {}, current_user: user, group: sub_group)
    context = GraphQL::Query::Context.new(
      query: query_double(schema: nil),
      values: { current_user: current_user }
    )

    resolve(described_class, obj: group, args: args, ctx: context, field_opts: { calls_gitaly: true })
  end
end
