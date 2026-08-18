# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::Vulnerabilities::TriggeredWorkflowType, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }
  let_it_be(:vulnerability_finding) { create(:vulnerabilities_finding, project: project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }
  let_it_be(:triggered_workflow) do
    create(:vulnerability_triggered_workflow,
      vulnerability_occurrence: vulnerability_finding,
      workflow: workflow,
      workflow_name: :sast_fp_detection)
  end

  let(:fields) do
    %w[
      workflowName
      workflow
    ]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
  it { expect(described_class).to require_graphql_authorizations(:read_vulnerability) }

  describe 'field types' do
    specify do
      expect(described_class.fields['workflowName']).to have_graphql_type(
        ::Types::Vulnerabilities::TriggeredWorkflowNameEnum, null: false)
    end

    specify do
      expect(described_class.fields['workflow']).to have_graphql_type(::Types::Ai::DuoWorkflows::WorkflowType,
        null: true)
    end
  end

  describe 'when the associated workflow has been deleted' do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilities {
              nodes {
                aiWorkflows {
                  nodes {
                    workflowName
                    workflow {
                      id
                    }
                  }
                }
              }
            }
          }
        }
      )
    end

    let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
    let_it_be(:orphan_workflow) { create(:duo_workflows_workflow, user: user, project: project) }
    let_it_be(:orphan_triggered_workflow) do
      create(:vulnerability_triggered_workflow,
        vulnerability_occurrence: vulnerability.finding,
        workflow: orphan_workflow,
        workflow_name: :sast_fp_detection)
    end

    it 'returns no errors' do
      orphan_workflow.delete

      result = GitlabSchema.execute(query, context: { current_user: user })

      expect(result['errors']).to be_nil
    end
  end

  describe 'N+1 queries' do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilities {
              nodes {
                aiWorkflows {
                  nodes {
                    workflowName
                    workflow {
                      id
                      workflowDefinition
                    }
                  }
                }
              }
            }
          }
        }
      )
    end

    it 'avoids N+1 queries when loading multiple triggered workflows', :request_store do
      3.times do
        finding = create(:vulnerabilities_finding, project: project)
        workflow = create(:duo_workflows_workflow, user: user, project: project)
        create(:vulnerability_triggered_workflow,
          vulnerability_occurrence: finding,
          workflow: workflow,
          workflow_name: :sast_fp_detection)
      end

      control_count = ActiveRecord::QueryRecorder.new do
        GitlabSchema.execute(query, context: { current_user: user })
      end.count

      5.times do
        finding = create(:vulnerabilities_finding, project: project)
        workflow = create(:duo_workflows_workflow, user: user, project: project)
        create(:vulnerability_triggered_workflow,
          vulnerability_occurrence: finding,
          workflow: workflow,
          workflow_name: :resolve_sast_vulnerability)
      end

      expect do
        GitlabSchema.execute(query, context: { current_user: user })
      end.not_to exceed_query_limit(control_count)
    end
  end
end
