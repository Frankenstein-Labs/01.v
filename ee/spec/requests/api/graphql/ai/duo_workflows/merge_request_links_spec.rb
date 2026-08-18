# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Agent Platform session <-> merge request links', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }

  # The merge request we start the traversal from.
  let_it_be(:source_merge_request) { create(:merge_request, source_project: project) }
  # A second merge request the session created while running.
  let_it_be(:created_merge_request) do
    create(:merge_request, source_project: project, source_branch: 'feature', target_branch: 'master')
  end

  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

  let_it_be(:source_link) do
    create(:duo_workflows_workflow_merge_request, workflow: workflow, merge_request: source_merge_request,
      link_type: :source)
  end

  let_it_be(:created_link) do
    create(:duo_workflows_workflow_merge_request, workflow: workflow, merge_request: created_merge_request,
      link_type: :created)
  end

  let(:current_user) { user }

  before do
    # Make read_duo_workflow pass for the workflow owner, matching WorkflowPolicy's
    # owner rule. The link type delegates to the workflow for the same ability.
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf -- current_user identity differs across the request
  end

  context 'when querying a merge request for its session and the sessions artifacts' do
    let(:query) do
      <<~GRAPHQL
        query {
          mergeRequest(id: "#{source_merge_request.to_gid}") {
            duoWorkflowLinks {
              nodes {
                linkType
                workflow {
                  mergeRequestLinks {
                    nodes {
                      linkType
                      mergeRequest { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'traverses merge request -> sessions -> merge requests' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_nil

      workflow_links = graphql_data_at(:merge_request, :duo_workflow_links, :nodes)
      expect(workflow_links.pluck('linkType')).to contain_exactly('SOURCE')

      downstream = workflow_links.first.dig('workflow', 'mergeRequestLinks', 'nodes')
      expect(downstream).to contain_exactly(
        { 'linkType' => 'SOURCE', 'mergeRequest' => { 'id' => source_merge_request.to_gid.to_s } },
        { 'linkType' => 'CREATED', 'mergeRequest' => { 'id' => created_merge_request.to_gid.to_s } }
      )
    end
  end

  context 'with a link_type filter on the session links' do
    let(:query) do
      <<~GRAPHQL
        query {
          mergeRequest(id: "#{source_merge_request.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  mergeRequestLinks(linkType: CREATED) {
                    nodes {
                      linkType
                      mergeRequest { id }
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

      downstream = graphql_data_at(:merge_request, :duo_workflow_links, :nodes)
        .first.dig('workflow', 'mergeRequestLinks', 'nodes')

      expect(downstream).to contain_exactly(
        { 'linkType' => 'CREATED', 'mergeRequest' => { 'id' => created_merge_request.to_gid.to_s } }
      )
    end
  end

  context 'with a link_type filter that matches no links' do
    let_it_be(:lonely_merge_request) do
      create(:merge_request, source_project: project, source_branch: 'lonely', target_branch: 'master')
    end

    let_it_be(:lonely_workflow) { create(:duo_workflows_workflow, project: project, user: user) }

    let_it_be(:lonely_link) do
      create(:duo_workflows_workflow_merge_request, workflow: lonely_workflow, merge_request: lonely_merge_request,
        link_type: :source)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          mergeRequest(id: "#{lonely_merge_request.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  mergeRequestLinks(linkType: CREATED) {
                    nodes {
                      linkType
                      mergeRequest { id }
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

      downstream = graphql_data_at(:merge_request, :duo_workflow_links, :nodes)
        .first.dig('workflow', 'mergeRequestLinks', 'nodes')

      expect(downstream).to be_empty
    end
  end

  context 'with multiple linked sessions' do
    let(:query) do
      <<~GRAPHQL
        query {
          mergeRequest(id: "#{source_merge_request.to_gid}") {
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

      # Another session, owned by the same user, also linked to the source merge request.
      other_workflow = create(:duo_workflows_workflow, project: project, user: user)
      create(:duo_workflows_workflow_merge_request, workflow: other_workflow, merge_request: source_merge_request,
        link_type: :source)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with multiple merge requests linked to the session' do
    let(:query) do
      <<~GRAPHQL
        query {
          mergeRequest(id: "#{source_merge_request.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  mergeRequestLinks {
                    nodes {
                      linkType
                      mergeRequest { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'does not N+1 on the linked merge requests' do
      post_graphql(query, current_user: current_user) # warm up one-time setup queries
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }
      expect(graphql_errors).to be_nil

      extra_merge_request = create(:merge_request, source_project: project, source_branch: 'extra',
        target_branch: 'master')
      create(:duo_workflows_workflow_merge_request, workflow: workflow, merge_request: extra_merge_request,
        link_type: :created)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with a granular personal access token' do
    # The traversal crosses two granular boundaries: MergeRequestType authorizes
    # `read_merge_request` at the :project boundary, and DuoWorkflowMergeRequestLink authorizes
    # `read_duo_workflow` at the :user boundary.
    let(:read_merge_request_scope) do
      build(:granular_scope, boundary: ::Authz::Boundary.for(project),
        permissions: [assignable_name(:read_merge_request)])
    end

    let(:read_duo_workflow_scope) do
      build(:granular_scope, boundary: ::Authz::Boundary.for(:user), organization: project.organization,
        permissions: [assignable_name(:read_duo_workflow)])
    end

    let(:token_scopes) { [read_merge_request_scope, read_duo_workflow_scope] }

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
          mergeRequest(id: "#{source_merge_request.to_gid}") {
            duoWorkflowLinks {
              nodes { linkType }
            }
          }
        }
      GRAPHQL
    end

    subject(:links) { graphql_data_at(:merge_request, :duo_workflow_links, :nodes) }

    def assignable_name(permission)
      ::Authz::PermissionGroups::Assignable.for_permission(permission).first.name
    end

    it 'returns the linked sessions' do
      post_graphql(query, token: { personal_access_token: pat })

      expect(graphql_errors).to be_nil
      expect(links.pluck('linkType')).to contain_exactly('SOURCE')
    end

    context 'when the token is missing the read_duo_workflow scope' do
      let(:token_scopes) { [read_merge_request_scope] }

      it 'reads the merge request but omits its session links' do
        post_graphql(query, token: { personal_access_token: pat })

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:merge_request)).to be_present
        expect(links).to be_empty
      end
    end

    context 'when the `granular_personal_access_tokens` feature flag is disabled' do
      before do
        stub_feature_flags(granular_personal_access_tokens: false)
      end

      it 'denies access' do
        post_graphql(query, token: { personal_access_token: pat })

        expect(graphql_data_at(:merge_request)).to be_nil
      end
    end
  end

  describe 'granular PAT authorization' do
    # A public project lets the token pass the parent MergeRequestType authorization
    # via the public-access bypass, so the test gates on DuoWorkflowMergeRequestLink's
    # `read_duo_workflow` permission at the user boundary.
    let_it_be(:public_project) { create(:project, :public, :repository) }
    let_it_be(:public_merge_request) { create(:merge_request, source_project: public_project) }
    let_it_be(:public_workflow) { create(:duo_workflows_workflow, project: public_project, user: user) }

    let_it_be(:public_link) do
      create(:duo_workflows_workflow_merge_request, workflow: public_workflow, merge_request: public_merge_request,
        link_type: :source)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          mergeRequest(id: "#{public_merge_request.to_gid}") {
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
          mergeRequest(id: "#{source_merge_request.to_gid}") {
            duoWorkflowLinks { nodes { linkType } }
          }
        }
      GRAPHQL
    end

    it 'omits the link from the merge request' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:merge_request, :duo_workflow_links, :nodes)).to be_empty
    end
  end

  context 'when the merge request is linked to sessions not all of which the user can read' do
    let_it_be(:other_user) { create(:user, developer_of: project) }
    let_it_be(:other_workflow) { create(:duo_workflows_workflow, project: project, user: other_user) }

    let_it_be(:redacted_link) do
      create(:duo_workflows_workflow_merge_request, workflow: other_workflow, merge_request: source_merge_request,
        link_type: :source)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          mergeRequest(id: "#{source_merge_request.to_gid}") {
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

      linked_workflows = graphql_data_at(:merge_request, :duo_workflow_links, :nodes)
        .map { |node| node.dig('workflow', 'id') }
      expect(linked_workflows).to contain_exactly(workflow.to_gid.to_s)
    end
  end
end
