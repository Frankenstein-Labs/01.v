# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Agent Platform session <-> note links', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }

  # All notes hang off a shared noteable so the N+1 checks isolate the link
  # resolver rather than the per-noteable authorization each distinct note loads.
  let_it_be(:noteable, freeze: false) { create(:issue, project: project) }

  # The note we start the traversal from.
  let_it_be(:source_note) { create(:note, project: project, noteable: noteable) }
  # A second note the session created while running.
  let_it_be(:created_note) { create(:note, project: project, noteable: noteable) }

  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

  let_it_be(:source_link) do
    create(:duo_workflows_workflow_note, workflow: workflow, note: source_note, link_type: :created)
  end

  let_it_be(:created_link) do
    create(:duo_workflows_workflow_note, workflow: workflow, note: created_note, link_type: :created)
  end

  let(:current_user) { user }

  before do
    # Make read_duo_workflow pass for the workflow owner, matching WorkflowPolicy's
    # owner rule. The link type delegates to the workflow for the same ability.
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf -- current_user identity differs across the request
  end

  context 'when querying a note for its session and the sessions artifacts' do
    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{source_note.to_gid}") {
            duoWorkflowLinks {
              nodes {
                linkType
                workflow {
                  noteLinks {
                    nodes {
                      linkType
                      note { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'traverses note -> sessions -> notes' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_nil

      workflow_links = graphql_data_at(:note, :duo_workflow_links, :nodes)
      expect(workflow_links.pluck('linkType')).to contain_exactly('CREATED')

      downstream = workflow_links.first.dig('workflow', 'noteLinks', 'nodes')
      expect(downstream).to contain_exactly(
        { 'linkType' => 'CREATED', 'note' => { 'id' => source_note.to_gid.to_s } },
        { 'linkType' => 'CREATED', 'note' => { 'id' => created_note.to_gid.to_s } }
      )
    end
  end

  context 'with a link_type filter on the session links' do
    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{source_note.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  noteLinks(linkType: CREATED) {
                    nodes {
                      linkType
                      note { id }
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

      downstream = graphql_data_at(:note, :duo_workflow_links, :nodes)
        .first.dig('workflow', 'noteLinks', 'nodes')

      expect(downstream).to contain_exactly(
        { 'linkType' => 'CREATED', 'note' => { 'id' => source_note.to_gid.to_s } },
        { 'linkType' => 'CREATED', 'note' => { 'id' => created_note.to_gid.to_s } }
      )
    end
  end

  context 'when the note has no linked sessions' do
    let_it_be(:lonely_note) { create(:note, project: project) }

    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{lonely_note.to_gid}") {
            duoWorkflowLinks { nodes { linkType } }
          }
        }
      GRAPHQL
    end

    it 'returns an empty list of links' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:note, :duo_workflow_links, :nodes)).to be_empty
    end
  end

  context 'with multiple linked sessions' do
    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{source_note.to_gid}") {
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

      # Another session, owned by the same user, also linked to the source note.
      other_workflow = create(:duo_workflows_workflow, project: project, user: user)
      create(:duo_workflows_workflow_note, workflow: other_workflow, note: source_note, link_type: :created)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with multiple notes linked to the session' do
    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{source_note.to_gid}") {
            duoWorkflowLinks {
              nodes {
                workflow {
                  noteLinks {
                    nodes {
                      linkType
                      note { id }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'does not N+1 on the linked notes' do
      post_graphql(query, current_user: current_user) # warm up one-time setup queries
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }
      expect(graphql_errors).to be_nil

      extra_note = create(:note, project: project, noteable: noteable)
      create(:duo_workflows_workflow_note, workflow: workflow, note: extra_note, link_type: :created)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with a granular personal access token' do
    # The traversal crosses two granular boundaries: NoteType authorizes
    # `read_note` at the :resource_parent boundary, and DuoWorkflowNoteLink authorizes
    # `read_duo_workflow` at the :user boundary.
    let(:read_note_scope) do
      build(:granular_scope, boundary: ::Authz::Boundary.for(project),
        permissions: [assignable_name(:read_note)])
    end

    let(:read_duo_workflow_scope) do
      build(:granular_scope, boundary: ::Authz::Boundary.for(:user), organization: project.organization,
        permissions: [assignable_name(:read_duo_workflow)])
    end

    let(:token_scopes) { [read_note_scope, read_duo_workflow_scope] }

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
          note(id: "#{source_note.to_gid}") {
            duoWorkflowLinks {
              nodes { linkType }
            }
          }
        }
      GRAPHQL
    end

    subject(:links) { graphql_data_at(:note, :duo_workflow_links, :nodes) }

    def assignable_name(permission)
      ::Authz::PermissionGroups::Assignable.for_permission(permission).first.name
    end

    it 'returns the linked sessions' do
      post_graphql(query, token: { personal_access_token: pat })

      expect(graphql_errors).to be_nil
      expect(links.pluck('linkType')).to contain_exactly('CREATED')
    end

    context 'when the token is missing the read_duo_workflow scope' do
      let(:token_scopes) { [read_note_scope] }

      it 'reads the note but omits its session links' do
        post_graphql(query, token: { personal_access_token: pat })

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:note)).to be_present
        expect(links).to be_empty
      end
    end

    context 'when the `granular_personal_access_tokens` feature flag is disabled' do
      before do
        stub_feature_flags(granular_personal_access_tokens: false)
      end

      it 'denies access' do
        post_graphql(query, token: { personal_access_token: pat })

        expect(graphql_data_at(:note)).to be_nil
      end
    end
  end

  context 'when querying the triggered session' do
    let_it_be(:catalog_item_version) { create(:ai_catalog_item_version) }
    let_it_be(:triggered_workflow) do
      create(:duo_workflows_workflow, project: project, user: user, ai_catalog_item_version: catalog_item_version)
    end

    let_it_be(:triggered_link) do
      create(:duo_workflows_workflow_note, workflow: triggered_workflow, note: source_note, link_type: :triggered)
    end

    let(:session_fields) { 'duoTriggeredSession { id agentName statusName }' }
    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{source_note.to_gid}") {
            #{session_fields}
          }
        }
      GRAPHQL
    end

    it 'returns the triggered session', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:note, :duo_triggered_session)).to eq(
        'id' => triggered_workflow.to_gid.to_s,
        'agentName' => catalog_item_version.item.name,
        'statusName' => triggered_workflow.status_name.to_s
      )
    end

    it 'does not N+1 when resolving catalog agent names for multiple notes' do
      post_graphql(query, current_user: current_user)
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

      other_note = create(:note, project: project, noteable: noteable)
      other_item_version = create(:ai_catalog_item_version)
      # A different owner on purpose: WorkflowPolicy loads workflow.user to deny
      # access, so a shared owner hides the N+1 behind the query cache.
      other_workflow = create(:duo_workflows_workflow,
        project: project, user: create(:user, developer_of: project),
        ai_catalog_item_version: other_item_version)
      create(:duo_workflows_workflow_note, workflow: other_workflow, note: other_note, link_type: :triggered)

      multi_note_query = <<~GRAPHQL
        query {
          first: note(id: "#{source_note.to_gid}") { #{session_fields} }
          second: note(id: "#{other_note.to_gid}") { #{session_fields} }
        }
      GRAPHQL

      expect do
        post_graphql(multi_note_query, current_user: current_user)
      end.not_to exceed_query_limit(control)
    end
  end

  describe 'granular PAT authorization' do
    # A public project lets the token pass the parent NoteType authorization
    # via the public-access bypass, so the test gates on DuoWorkflowNoteLink's
    # `read_duo_workflow` permission at the user boundary.
    let_it_be(:public_project) { create(:project, :public) }
    let_it_be(:public_noteable) { create(:issue, project: public_project) }
    let_it_be(:public_note) { create(:note, project: public_project, noteable: public_noteable) }
    let_it_be(:public_workflow) { create(:duo_workflows_workflow, project: public_project, user: user) }

    let_it_be(:public_link) do
      create(:duo_workflows_workflow_note, workflow: public_workflow, note: public_note, link_type: :created)
    end

    let_it_be(:public_triggered_link) do
      create(:duo_workflows_workflow_note, workflow: public_workflow, note: public_note, link_type: :triggered)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{public_note.to_gid}") {
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

    context 'when querying duoTriggeredSession' do
      let(:query) { graphql_query_for(:note, { id: public_note.to_gid }, 'duoTriggeredSession { id }') }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :read_duo_workflow do
        let(:boundary_object) { :user }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
      end
    end
  end

  context 'when the user cannot read the linked session' do
    let_it_be(:other_user) { create(:user, developer_of: project) }
    let(:current_user) { other_user }

    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{source_note.to_gid}") {
            duoWorkflowLinks { nodes { linkType } }
          }
        }
      GRAPHQL
    end

    it 'omits the link from the note' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:note, :duo_workflow_links, :nodes)).to be_empty
    end
  end

  context 'when the note is linked to sessions the user cannot all read' do
    let_it_be(:other_user) { create(:user, developer_of: project) }
    let_it_be(:other_workflow) { create(:duo_workflows_workflow, project: project, user: other_user) }

    let_it_be(:redacted_link) do
      create(:duo_workflows_workflow_note, workflow: other_workflow, note: source_note, link_type: :created)
    end

    let(:query) do
      <<~GRAPHQL
        query {
          note(id: "#{source_note.to_gid}") {
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

      linked_workflows = graphql_data_at(:note, :duo_workflow_links, :nodes)
        .map { |node| node.dig('workflow', 'id') }
      expect(linked_workflows).to contain_exactly(workflow.to_gid.to_s)
    end
  end
end
