# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a WorkItem description template and content', type: :request, feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }
  let_it_be(:current_user) { create(:user) }
  let(:expected_graphql_data) { graphql_data['workItemDescriptionTemplateContent'] }

  context 'when the user does not have explicit access to the project of the template' do
    let_it_be(:without_explicit_access_project) do
      create(:project,
        :private,
        :custom_repo,
        files: { ".gitlab/issue_templates/without_explicit_access_template.md" => "some content" },
        group: subgroup)
    end

    context 'when the project is set as the instance level template repository' do
      before do
        stub_application_setting(file_template_project: without_explicit_access_project)
        stub_licensed_features(custom_file_templates: true)
      end

      let(:query) do
        graphql_query_for(:workItemDescriptionTemplateContent,
          { templateContentInput: {
            projectId: without_explicit_access_project.id,
            name: "without_explicit_access_template"
          } })
      end

      it 'allows the user to read the template' do
        post_graphql(query, current_user: current_user)

        expect(expected_graphql_data["projectId"]).to eq(without_explicit_access_project.id)
        expect(expected_graphql_data["name"]).to eq("without_explicit_access_template")
        expect(expected_graphql_data["content"]).to eq("some content")

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
      end
    end

    context 'when from_namespace is passed' do
      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
      end

      def query_with_from_namespace(from_namespace)
        graphql_query_for(:workItemDescriptionTemplateContent,
          { templateContentInput: {
            projectId: without_explicit_access_project.id,
            name: "without_explicit_access_template",
            from_namespace: from_namespace.full_path
          } })
      end

      context 'as a project' do
        let_it_be(:project_with_access) { create(:project, developers: current_user, group: subgroup) }

        context "when no ancestor of from_namespace has the template repository project as the template's project" do
          it 'does not allow the user to read the template' do
            post_graphql(query_with_from_namespace(project_with_access), current_user: current_user)

            expect(expected_graphql_data).to be_nil
          end
        end

        context "when any ancestor of from_namespace has the template repository project as the template's project" do
          before do
            set_file_template_project_id(subgroup, without_explicit_access_project.id)
          end

          context 'when the user has access to from_namespace' do
            it 'allows the user to read the template' do
              post_graphql(query_with_from_namespace(project_with_access), current_user: current_user)

              # Since one of the ancestors of project_with_access has without_explicit_access_project set as the
              # template repository, we allow the user to read the template
              expect(expected_graphql_data["projectId"]).to eq(without_explicit_access_project.id)
              expect(expected_graphql_data["name"]).to eq("without_explicit_access_template")
              expect(expected_graphql_data["content"]).to eq("some content")

              expect(response).to have_gitlab_http_status(:ok)
              expect(graphql_errors).to be_nil
            end
          end

          context 'when the user does not have access to from_namespace' do
            let_it_be(:project_without_access) { create(:project, group: subgroup) }

            it 'does not allow the user to read the template' do
              post_graphql(query_with_from_namespace(project_without_access), current_user: current_user)

              expect(expected_graphql_data).to be_nil
            end
          end
        end
      end

      context 'as a group' do
        context "when no ancestor of from_namespace has the template repository project as the template's project" do
          it 'does not allow the user to read the template' do
            post_graphql(query_with_from_namespace(subgroup), current_user: current_user)

            expect(expected_graphql_data).to be_nil
          end
        end

        context "when any ancestor of from_namespace has the template repository project as the template's project" do
          before do
            set_file_template_project_id(group, without_explicit_access_project.id)
          end

          context 'when the user has access to from_namespace' do
            before_all do
              subgroup.add_developer(current_user)
            end

            it 'allows the user to read the template' do
              post_graphql(query_with_from_namespace(subgroup), current_user: current_user)

              # Since one of the ancestors of subgroup has without_explicit_access_project set as the template
              # repository, we allow the user to read the template
              expect(expected_graphql_data["projectId"]).to eq(without_explicit_access_project.id)
              expect(expected_graphql_data["name"]).to eq("without_explicit_access_template")
              expect(expected_graphql_data["content"]).to eq("some content")

              expect(response).to have_gitlab_http_status(:ok)
              expect(graphql_errors).to be_nil
            end
          end

          context 'when the user does not have access to from_namespace' do
            it 'does not allow the user to read the template' do
              post_graphql(query_with_from_namespace(subgroup), current_user: current_user)

              expect(expected_graphql_data).to be_nil
            end
          end
        end
      end
    end
  end

  context 'when the user has explicit access to the project' do
    let_it_be(:with_explicit_access_project) do
      create(:project,
        :private,
        :custom_repo,
        files: { ".gitlab/issue_templates/with_explicit_access_template.md" => "template content" },
        developers: current_user)
    end

    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: {
          projectId: with_explicit_access_project.id,
          name: "with_explicit_access_template"
        } })
    end

    it 'allows the user to read the template' do
      post_graphql(query, current_user: current_user)

      expect(expected_graphql_data["projectId"]).to eq(with_explicit_access_project.id)
      expect(expected_graphql_data["name"]).to eq("with_explicit_access_template")
      expect(expected_graphql_data["content"]).to eq("template content")

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
    end
  end

  context 'when the project is public' do
    let_it_be(:public_project) do
      create(:project,
        :public,
        :custom_repo,
        files: { ".gitlab/issue_templates/public_template.md" => "public content" })
    end

    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: {
          projectId: public_project.id,
          name: "public_template"
        } })
    end

    it 'allows the user to read the template' do
      post_graphql(query, current_user: current_user)

      expect(expected_graphql_data["projectId"]).to eq(public_project.id)
      expect(expected_graphql_data["name"]).to eq("public_template")
      expect(expected_graphql_data["content"]).to eq("public content")

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
    end
  end

  context 'when requesting the Settings Default template' do
    let_it_be(:project_with_default_template) do
      create(:project, :private, developers: current_user, issues_template: "Default template content")
    end

    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: {
          projectId: project_with_default_template.id,
          name: "Default (Project Settings)"
        } })
    end

    context 'when the project has an issues_template' do
      context 'when the user has access to the project' do
        it 'returns the Settings Default template' do
          post_graphql(query, current_user: current_user)

          expect(expected_graphql_data).to match(
            "projectId" => project_with_default_template.id,
            "name" => "Default (Project Settings)",
            "content" => "Default template content",
            "category" => "Project Templates"
          )

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_errors).to be_nil
        end
      end

      context 'when the user does not have access to the project' do
        let_it_be(:project_without_access) do
          create(:project, :private, issues_template: "Private default template content")
        end

        let(:query_without_access) do
          graphql_query_for(:workItemDescriptionTemplateContent,
            { templateContentInput: {
              projectId: project_without_access.id,
              name: "Default (Project Settings)"
            } })
        end

        it 'does not allow the user to read the template' do
          post_graphql(query_without_access, current_user: current_user)

          expect(expected_graphql_data).to be_nil
        end
      end
    end

    context 'when the project does not have an issues_template' do
      let_it_be(:project_without_template) do
        create(:project, :private, developers: current_user)
      end

      let(:query_without_template) do
        graphql_query_for(:workItemDescriptionTemplateContent,
          { templateContentInput: {
            projectId: project_without_template.id,
            name: "Default (Project Settings)"
          } })
      end

      it 'returns nil' do
        post_graphql(query_without_template, current_user: current_user)

        expect(expected_graphql_data).to be_nil
      end
    end

    context 'when the project does not exist' do
      let(:query_non_existent_project) do
        graphql_query_for(:workItemDescriptionTemplateContent,
          { templateContentInput: {
            projectId: non_existing_record_id,
            name: "Default (Project Settings)"
          } })
      end

      it 'returns nil' do
        post_graphql(query_non_existent_project, current_user: current_user)

        expect(expected_graphql_data).to be_nil
      end
    end
  end
end
