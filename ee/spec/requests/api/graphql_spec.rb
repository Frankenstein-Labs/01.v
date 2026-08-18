# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL', feature_category: :api do
  include GraphqlHelpers
  include ::EE::GeoHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:current_user) { create(:user, developer_of: [project]) }
  let_it_be(:resource) { create(:issue, project: project) }
  let(:params) { { chat: { resource_id: resource&.to_gid, content: "summarize" } } }
  let(:query) { graphql_query_for('echo', text: 'Hello world') }
  let(:mutation) { 'mutation { echoCreate(input: { messages: ["hello", "world"] }) { echoes } }' }
  let(:ai_mutation) { graphql_mutation(:ai_action, params) }

  let_it_be(:user) { create(:user) }

  describe 'authentication', :allow_forgery_protection do
    context 'with personal access token authentication' do
      let(:token) { create(:personal_access_token, user: user) }

      context 'when personal access tokens are disabled by enterprise group' do
        let_it_be(:enterprise_group) do
          create(:group, namespace_settings: create(:namespace_settings, disable_personal_access_tokens: true))
        end

        let_it_be(:enterprise_user_of_the_group) { create(:enterprise_user, enterprise_group: enterprise_group) }
        let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

        before do
          stub_saas_features(disable_personal_access_tokens: true)
          stub_licensed_features(disable_personal_access_tokens: true)
        end

        context 'for non-enterprise users of the group' do
          let(:user) { enterprise_user_of_another_group }

          it 'authenticates the user with a PAT', :aggregate_failures do
            post_graphql(query, headers: { 'PRIVATE-TOKEN' => token.token })

            expect(response).to have_gitlab_http_status(:ok)

            expect(graphql_data['echo']).to eq("\"#{user.username}\" says: Hello world")
          end
        end

        context 'for enterprise users of the group' do
          let(:user) { enterprise_user_of_the_group }

          it 'does not authenticate the user with a PAT', :aggregate_failures do
            post_graphql(query, headers: { 'PRIVATE-TOKEN' => token.token })

            expect(response).to have_gitlab_http_status(:unauthorized)

            expect_graphql_errors_to_include(/Invalid token/)
          end
        end
      end

      context 'when the personal access token has ai_features scope' do
        let_it_be(:thread) { create(:ai_conversation_thread, user: user) }

        before do
          token.update!(scopes: [:ai_features])
        end

        it 'they can perform an ai mutation' do
          expect_next_instance_of(Llm::ExecuteMethodService) do |service|
            expect(service).to receive(:execute)
              .and_return(ServiceResponse.success(
                payload: {
                  ai_message: instance_double(::Gitlab::Llm::AiMessage, request_id: 'abc123', thread: thread)
                }
              ))
          end

          post_graphql(ai_mutation.query, variables: ai_mutation.variables, headers: { 'PRIVATE-TOKEN' => token.token })

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_mutation_response(:ai_action)['requestId']).to eq('abc123')
          expect(graphql_mutation_response(:ai_action)['threadId']).to eq(thread.to_global_id.to_s)
          expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
        end

        it 'they cannot perform a non ai query' do
          post_graphql(query, headers: { 'PRIVATE-TOKEN' => token.token })

          # The response status is OK but they get no data back
          expect(response).to have_gitlab_http_status(:ok)

          expect(fresh_response_data['data']).to be_nil
        end

        it 'they cannot perform a non ai mutation' do
          post_graphql(mutation, headers: { 'PRIVATE-TOKEN' => token.token })

          # The response status is OK but they get no data back and they get errors
          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_data['echoCreate']).to be_nil

          expect_graphql_errors_to_include("does not exist or you don't have permission")
        end
      end
    end

    context 'with JWT token authentication' do
      let_it_be(:geo_node) { create(:geo_node) }

      before do
        stub_current_geo_node(geo_node)
        stub_current_node_name(geo_node.name)
      end

      context 'when the request is a Geo API request' do
        context 'when request authentication type is GL-Geo' do
          let(:headers) { { 'Authorization' => "GL-Geo #{geo_node.access_key}:#{jwt.encoded}" } }
          let(:jwt) do
            build_jwt_for_geo(
              secret_access_key: secret_access_key,
              token_scope: token_scope,
              authenticating_user_id: authenticating_user_id)
          end

          context 'when the token is successfully decoded' do
            let(:secret_access_key) { geo_node.secret_access_key }

            context 'when the token payload scope is geo_api' do
              let(:token_scope) { ::Gitlab::Geo::API_SCOPE }

              context 'when the user is found' do
                let(:authenticating_user_id) { current_user.id }

                context 'when the query does not require any authentication' do
                  it 'performs the query as the user' do
                    post_geo_graphql(query, headers: headers)

                    expect(response).to have_gitlab_http_status(:ok)
                    expect(graphql_errors).to be_nil
                    expect(graphql_data).to eq({ 'echo' => "\"#{current_user.username}\" says: Hello world" })
                  end
                end

                context 'when the query requires admin permissions' do
                  context 'when the user is not an admin' do
                    let(:query) { '{ geoNode { name } }' }

                    it 'performs the GraphQL query as an unauthorized user' do
                      post_geo_graphql(query, headers: headers)

                      expect(response).to have_gitlab_http_status(:ok)
                      expect(graphql_errors).to be_nil
                      expect(graphql_data).to eq({ "geoNode" => nil })
                    end
                  end

                  context 'when the user is an admin' do
                    let_it_be(:current_user) { create(:user, :admin) }
                    let(:query) { '{ geoNode { name } }' }

                    it 'performs the GraphQL query as the authorized user' do
                      post_geo_graphql(query, headers: headers)

                      expect(response).to have_gitlab_http_status(:ok)
                      expect(graphql_errors).to be_nil
                      expect(graphql_data).to eq({ "geoNode" => { "name" => geo_node.name } })
                    end
                  end
                end
              end

              context 'when the user is not found' do
                let(:authenticating_user_id) { non_existing_record_id }

                context 'when the query does not require any authentication' do
                  it 'performs the query as an unauthorized user' do
                    post_geo_graphql(query, headers: headers)

                    expect(response).to have_gitlab_http_status(:ok)
                    expect(graphql_errors).to be_nil
                    expect(graphql_data).to eq({ 'echo' => 'nil says: Hello world' })
                  end
                end

                context 'when the query requires admin permissions' do
                  let(:query) { '{ geoNode { name } }' }

                  it 'performs the GraphQL query as an unauthorized user' do
                    post_geo_graphql(query, headers: headers)

                    expect(response).to have_gitlab_http_status(:ok)
                    expect(graphql_errors).to be_nil
                    expect(graphql_data).to eq({ "geoNode" => nil })
                  end
                end
              end
            end

            context 'when the token payload scope is unknown' do
              let(:token_scope) { 'foo' }
              let(:authenticating_user_id) { current_user.id }

              context 'when the query does not require any authentication' do
                it 'performs the query as an unauthorized user' do
                  post_geo_graphql(query, headers: headers)

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(graphql_errors).to be_nil
                  expect(graphql_data).to eq({ 'echo' => 'nil says: Hello world' })
                end
              end

              context 'when the query requires admin permissions' do
                let(:query) { '{ geoNode { name } }' }

                it 'performs the GraphQL query as an unauthorized user' do
                  post_geo_graphql(query, headers: headers)

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(graphql_errors).to be_nil
                  expect(graphql_data).to eq({ "geoNode" => nil })
                end
              end
            end
          end

          context 'when the token fails to be decoded' do
            let(:secret_access_key) { 'incorrect key' }
            let(:token_scope) { ::Gitlab::Geo::API_SCOPE }
            let(:authenticating_user_id) { current_user.id }

            context 'when the query does not require any authentication' do
              it 'performs the query as an unauthorized user' do
                post_geo_graphql(query, headers: headers)

                expect(response).to have_gitlab_http_status(:ok)
                expect(graphql_errors).to be_nil
                expect(graphql_data).to eq({ 'echo' => 'nil says: Hello world' })
              end
            end

            context 'when the query requires admin permissions' do
              let(:query) { '{ geoNode { name } }' }

              it 'performs the GraphQL query as an unauthorized user' do
                post_geo_graphql(query, headers: headers)

                expect(response).to have_gitlab_http_status(:ok)
                expect(graphql_errors).to be_nil
                expect(graphql_data).to eq({ "geoNode" => nil })
              end
            end
          end
        end
      end
    end
  end

  # Request made by the primary site, against the secondary site, to /api/v4/geo/graphql.
  # The request is made on behalf of an admin. The purpose is so that an admin can view
  # secondary-specific data, and the admin can initiate this request from any site.
  def post_geo_graphql(query, variables: nil, headers: {}, params: {})
    params = params.merge(query: query, variables: serialize_variables(variables))
    post api('/geo/graphql'), params: params, headers: headers

    return unless graphql_errors

    # Errors are acceptable, but not this one:
    expect(graphql_errors).not_to include(a_hash_including('message' => 'Internal server error'))
  end

  def build_jwt_for_geo(secret_access_key:, token_scope:, authenticating_user_id:, expire_time: nil)
    JSONWebToken::HMACToken.new(secret_access_key).tap do |jwt|
      data = { scope: token_scope, authenticating_user_id: authenticating_user_id }
      jwt['data'] = data.to_json
      jwt.expire_time = expire_time || (jwt.issued_at + ::Gitlab::Geo::SignedData::VALIDITY_PERIOD)
    end
  end
end
