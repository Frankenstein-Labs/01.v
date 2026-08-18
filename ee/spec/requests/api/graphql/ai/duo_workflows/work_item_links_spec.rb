# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Agent Platform session <-> work item links', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }

  # The work item we start the traversal from.
  let_it_be(:source_work_item) { create(:work_item, project: project) }
  # A second work item the session created while running.
  let_it_be(:created_work_item) { create(:work_item, project: project) }

  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

  let_it_be(:source_link) do
    create(:duo_workflows_workflow_work_item, workflow: workflow, work_item: source_work_item, link_type: :source)
  end

  let_it_be(:created_link) do
    create(:duo_workflows_workflow_work_item, workflow: workflow, work_item: created_work_item, link_type: :created)
  end

  let(:current_user) { user }

  before do
    # Make read_duo_workflow pass for the workflow owner, matching WorkflowPolicy's
    # owner rule. The link type delegates to the workflow for the same ability.
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf -- current_user identity differs across the request
  end

  context 'when querying a work item for its session and the sessions artifacts' do
    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{source_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes {
                linkType
                workflow {
                  workItemLinks {
                    nodes {
                      linkType
                      workItem { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'traverses work item -> sessions -> work items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_nil

      workflow_links = graphql_data_at(:work_item, :duo_workflow_links, :nodes)
      expect(workflow_links.pluck('linkType')).to contain_exactly('SOURCE')

      downstream = workflow_links.first.dig('workflow', 'workItemLinks', 'nodes')
      expect(downstream).to contain_exactly(
        { 'linkType' => 'SOURCE', 'workItem' => { 'id' => source_work_item.to_gid.to_s } },
        { 'linkType' => 'CREATED', 'workItem' => { 'id' => created_work_item.to_gid.to_s } }
      )
    end
  end

  context 'with a link_type filter on the session links' do
    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{source_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  workItemLinks(linkType: CREATED) {
                    nodes {
                      linkType
                      workItem { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'returns only links of the requested type' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil

      downstream = graphql_data_at(:work_item, :duo_workflow_links, :nodes)
        .first.dig('workflow', 'workItemLinks', 'nodes')

      expect(downstream).to contain_exactly(
        { 'linkType' => 'CREATED', 'workItem' => { 'id' => created_work_item.to_gid.to_s } }
      )
    end
  end

  context 'with a link_type filter that matches no links' do
    let_it_be(:lonely_work_item) { create(:work_item, project: project) }
    let_it_be(:lonely_workflow) { create(:duo_workflows_workflow, project: project, user: user) }

    let_it_be(:lonely_link) do
      create(:duo_workflows_workflow_work_item, workflow: lonely_workflow, work_item: lonely_work_item,
        link_type: :source)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{lonely_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  workItemLinks(linkType: CREATED) {
                    nodes {
                      linkType
                      workItem { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'returns an empty list of links' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil

      downstream = graphql_data_at(:work_item, :duo_workflow_links, :nodes)
        .first.dig('workflow', 'workItemLinks', 'nodes')

      expect(downstream).to be_empty
    end
  end

  context 'with multiple linked sessions' do
    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{source_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes {
                linkType
                workflow { id humanStatus }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'does not N+1 on the per-session authorization' do
      post_graphql(query, current_user: current_user) # warm up one-time setup queries
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }
      expect(graphql_errors).to be_nil

      # Another session, owned by the same user, also linked to the source work item.
      other_workflow = create(:duo_workflows_workflow, project: project, user: user)
      create(:duo_workflows_workflow_work_item, workflow: other_workflow, work_item: source_work_item,
        link_type: :source)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with multiple work items linked to the session' do
    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{source_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  workItemLinks {
                    nodes {
                      linkType
                      workItem { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'does not N+1 on the linked work items' do
      post_graphql(query, current_user: current_user) # warm up one-time setup queries
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }
      expect(graphql_errors).to be_nil

      extra_work_item = create(:work_item, project: project)
      create(:duo_workflows_workflow_work_item, workflow: workflow, work_item: extra_work_item, link_type: :created)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with a granular personal access token' do
    # The traversal crosses two granular boundaries: WorkItemType authorizes
    # `read_work_item` at the :project boundary, and DuoWorkflowWorkItemLink authorizes
    # `read_duo_workflow` at the :user boundary.
    let(:read_work_item_scope) do
      build(:granular_scope, boundary: ::Authz::Boundary.for(project),
        permissions: [assignable_name(:read_work_item)])
    end

    let(:read_duo_workflow_scope) do
      build(:granular_scope, boundary: ::Authz::Boundary.for(:user), organization: project.organization,
        permissions: [assignable_name(:read_duo_workflow)])
    end

    let(:token_scopes) { [read_work_item_scope, read_duo_workflow_scope] }

    let(:pat) do
      create(:granular_pat, user: user, organization: project.organization).tap do |token|
        token_scopes.each do |scope|
          create(:personal_access_token_granular_scope,
            personal_access_token: token, granular_scope: scope, organization: project.organization)
        end
      end
    end

    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{source_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes { linkType }
            }
          }
        }
      GRAPHQL
    end

    subject(:links) { graphql_data_at(:work_item, :duo_workflow_links, :nodes) }

    def assignable_name(permission)
      ::Authz::PermissionGroups::Assignable.for_permission(permission).first.name
    end

    it 'returns the linked sessions' do
      post_graphql(query, token: { personal_access_token: pat })

      expect(graphql_errors).to be_nil
      expect(links.pluck('linkType')).to contain_exactly('SOURCE')
    end

    context 'when the token is missing the read_duo_workflow scope' do
      let(:token_scopes) { [read_work_item_scope] }

      it 'reads the work item but omits its session links' do
        post_graphql(query, token: { personal_access_token: pat })

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:work_item)).to be_present
        expect(links).to be_empty
      end
    end

    context 'when the `granular_personal_access_tokens` feature flag is disabled' do
      before do
        stub_feature_flags(granular_personal_access_tokens: false)
      end

      it 'denies access' do
        post_graphql(query, token: { personal_access_token: pat })

        expect(graphql_data_at(:work_item)).to be_nil
      end
    end
  end

  describe 'granular PAT authorization' do
    # A public project lets the token pass the parent WorkItemType authorization
    # via the public-access bypass, so the test gates on DuoWorkflowWorkItemLink's
    # `read_duo_workflow` permission at the user boundary.
    let_it_be(:public_project) { create(:project, :public) }
    let_it_be(:public_work_item) { create(:work_item, project: public_project) }
    let_it_be(:public_workflow) { create(:duo_workflows_workflow, project: public_project, user: user) }

    let_it_be(:public_link) do
      create(:duo_workflows_workflow_work_item, workflow: public_workflow, work_item: public_work_item,
        link_type: :source)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{public_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes { linkType }
            }
          }
        }
      GRAPHQL
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(public_project, :duo_workflow).and_return(true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :read_duo_workflow do
      let(:boundary_object) { :user }
      let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    end
  end

  context 'when the user cannot read the linked session' do
    let_it_be(:other_user) { create(:user, developer_of: project) }
    let(:current_user) { other_user }

    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{source_work_item.to_gid}") {
            duoWorkflowLinks { nodes { linkType } }
          }
        }
      GRAPHQL
    end

    it 'omits the link from the work item' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:work_item, :duo_workflow_links, :nodes)).to be_empty
    end
  end

  context 'when the work item is linked to sessions the user cannot all read' do
    let_it_be(:other_user) { create(:user, developer_of: project) }
    let_it_be(:other_workflow) { create(:duo_workflows_workflow, project: project, user: other_user) }

    let_it_be(:redacted_link) do
      create(:duo_workflows_workflow_work_item, workflow: other_workflow, work_item: source_work_item,
        link_type: :source)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          workItem(id: "#{source_work_item.to_gid}") {
            duoWorkflowLinks {
              nodes {
                linkType
                workflow { id }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'returns only the links to sessions the user can read' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil

      linked_workflows = graphql_data_at(:work_item, :duo_workflow_links, :nodes)
        .map { |node| node.dig('workflow', 'id') }
      expect(linked_workflows).to contain_exactly(workflow.to_gid.to_s)
    end
  end
end
