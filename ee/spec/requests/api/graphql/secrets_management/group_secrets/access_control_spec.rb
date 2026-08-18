# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'group secrets', :gitlab_secrets_manager, :freeze_time, feature_category: :secrets_management do
  include GraphqlHelpers

  before do
    provision_group_secrets_manager(secrets_manager, current_user)
  end

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let(:inactive_error_message) { "Secrets manager is not active" }
  let(:access_error_message) { Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }

  let(:list_query) do
    graphql_query_for(
      'groupSecrets',
      { group_path: group.full_path },
      "nodes { #{all_graphql_fields_for('GroupSecret', max_depth: 2)} }"
    )
  end

  let(:list_query_via_edges) do
    graphql_query_for(
      'groupSecrets',
      { group_path: group.full_path },
      "edges { node { #{all_graphql_fields_for('GroupSecret', max_depth: 2)} } }"
    )
  end

  let(:read_query) do
    graphql_query_for(
      'groupSecret',
      { group_path: group.full_path, name: 'MY_SECRET_1' },
      all_graphql_fields_for('GroupSecret', max_depth: 2).to_s
    )
  end

  let(:invalid_read_query) do
    graphql_query_for(
      'groupSecret',
      { group_path: group.full_path, name: 'SECRET_DOES_NOT_EXIST' },
      all_graphql_fields_for('GroupSecret', max_depth: 2).to_s
    )
  end

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }

  context 'when current user is not part of the group' do
    before do
      post_graphql(list_query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is not part of the group and attempts to fetch a secret' do
    before do
      get_graphql(read_query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is maintainer but has no policies in OpenBao' do
    let(:current_user) { create(:user, maintainer_of: group) }

    before do
      post_graphql(list_query, current_user: current_user)
    end

    it 'returns permission error from Openbao' do
      expect(response).to have_gitlab_http_status(:success)

      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message'])
        .to include(access_error_message)
      expect(graphql_data['groupSecrets']).to be_nil
    end
  end

  context 'when current user maintainer, no policies in OpenBao attempts to fetch a secret' do
    before_all do
      group.add_maintainer(current_user)
    end

    before do
      get_graphql(read_query, current_user: current_user)
    end

    it 'returns permission error from Openbao' do
      expect(response).to have_gitlab_http_status(:success)

      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message'])
        .to include(access_error_message)
      expect(graphql_data['groupSecret']).to be_nil
    end
  end

  context 'when current user is the group owner' do
    before_all do
      group.add_owner(current_user)
    end

    let!(:secret_1) do
      SecretsManagement::GroupSecrets::CreateService.new(group, current_user).execute(
        name: 'MY_SECRET_1',
        description: 'test description 1',
        environment: 'production',
        protected: true,
        value: 'test value 1'
      )
    end

    let!(:secret_2) do
      SecretsManagement::GroupSecrets::CreateService.new(group, current_user).execute(
        name: 'MY_SECRET_2',
        description: 'test description 2',
        environment: 'staging',
        protected: false,
        value: 'test value 2'
      )
    end

    context 'and the group secrets manager is not active' do
      before do
        secrets_manager.destroy!
        post_graphql(list_query, current_user: current_user)
      end

      it 'returns a top-level error' do
        expect(graphql_errors).to be_present
        error_messages = graphql_errors.pluck('message')
        expect(error_messages).to match_array([inactive_error_message])
      end
    end

    context 'and the group secrets manager is not active and attempts to fetch a secret' do
      before do
        secrets_manager.destroy!
        get_graphql(read_query, current_user: current_user)
      end

      it 'returns a top-level error' do
        expect(graphql_errors).to be_present
        error_messages = graphql_errors.pluck('message')
        expect(error_messages).to match_array([inactive_error_message])
      end
    end

    context 'and the secrets manager entitlement denies access' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
        allow(SecretsManagement::Entitlement).to receive(:for)
          .and_return(SecretsManagement::Entitlement.new(state: :ineligible))

        post_graphql(list_query, current_user: current_user)
      end

      it 'returns the existing hard permission error (no resolver code change for this path)' do
        expect(graphql_errors).to be_present
        expect(graphql_errors.first['message']).to include(access_error_message)
        expect(graphql_data['groupSecrets']).to be_nil
      end
    end

    context 'and the secrets manager entitlement denies access and attempts to fetch a secret' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
        allow(SecretsManagement::Entitlement).to receive(:for)
          .and_return(SecretsManagement::Entitlement.new(state: :ineligible))

        get_graphql(read_query, current_user: current_user)
      end

      it 'returns the existing hard permission error (no resolver code change for this path)' do
        expect(graphql_errors).to be_present
        expect(graphql_errors.first['message']).to include(access_error_message)
        expect(graphql_data['groupSecret']).to be_nil
      end
    end

    context 'and the group secrets manager is active' do
      it 'returns the list of group secrets via nodes' do
        post_graphql(list_query, current_user: current_user)

        expect(graphql_data_at(:group_secrets, :nodes))
          .to contain_exactly(
            a_graphql_entity_for(
              group: a_graphql_entity_for(group),
              name: 'MY_SECRET_1',
              description: 'test description 1',
              environment: 'production',
              protected: true,
              metadata_version: 2
            ),
            a_graphql_entity_for(
              group: a_graphql_entity_for(group),
              name: 'MY_SECRET_2',
              description: 'test description 2',
              environment: 'staging',
              protected: false,
              metadata_version: 2
            )
          )
      end

      it 'returns the list of group secrets via edges' do
        post_graphql(list_query_via_edges, current_user: current_user)

        expect(graphql_data_at(:group_secrets, :edges))
          .to contain_exactly(
            a_graphql_entity_for(
              node: a_graphql_entity_for(
                group: a_graphql_entity_for(group),
                name: 'MY_SECRET_1',
                description: 'test description 1',
                environment: 'production',
                protected: true,
                metadata_version: 2
              )
            ),
            a_graphql_entity_for(
              node: a_graphql_entity_for(
                group: a_graphql_entity_for(group),
                name: 'MY_SECRET_2',
                description: 'test description 2',
                environment: 'staging',
                protected: false,
                metadata_version: 2
              )
            )
          )
      end

      it 'returns created_at in ISO8601 format' do
        post_graphql(list_query_via_edges, current_user: current_user)

        edges = graphql_data_at(:group_secrets, :edges)
        edges.each do |edge|
          created_at = edge.dig('node', 'createdAt')
          expect(created_at).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/)
        end
      end

      context 'when status reflects timestamps' do
        let(:namespace) { group.secrets_manager.full_group_namespace_path }
        let(:mount) { group.secrets_manager.ci_secrets_mount_path }
        let(:path) { group.secrets_manager.ci_data_path('MY_SECRET_1') }
        let(:client) { secrets_manager_client.with_namespace(namespace) }
        let(:cas) { 2 }

        def iso(datetime)
          datetime.utc.iso8601
        end

        it 'returns completed for just created secret' do
          get_graphql(read_query, current_user: current_user)
          node = graphql_data_at(:group_secret)
          expect(node['status']).to eq('COMPLETED')
        end

        it 'returns stale for old create timestamps' do
          allow_next_instance_of(SecretsManagement::GroupSecrets::ReadMetadataService) do |svc|
            allow(svc).to receive(:execute).and_wrap_original do |orig, name|
              resp = orig.call(name)

              if resp.success? && name == 'MY_SECRET_1'
                gs = resp.payload[:secret]
                gs.create_started_at = 10.minutes.ago.to_s
                gs.create_completed_at = nil
                ServiceResponse.success(payload: { secret: gs })
              else
                resp
              end
            end
          end

          get_graphql(read_query, current_user: current_user)
          node = graphql_data_at(:group_secret)
          expect(node['status']).to eq('CREATE_STALE')
        end

        it 'returns completed for recent update timestamps' do
          client.update_kv_secret_metadata(
            mount,
            path,
            {
              description: 'test description 1',
              environment: 'production',
              protected: 'true',
              create_started_at: iso(5.minutes.ago),
              create_completed_at: iso(5.minutes.ago),
              update_started_at: iso(10.seconds.ago),
              update_completed_at: iso(Time.current)
            },
            metadata_cas: cas
          )

          get_graphql(read_query, current_user: current_user)
          node = graphql_data_at(:group_secret)
          expect(node['status']).to eq('COMPLETED')
        end

        it 'returns stale for old update timestamps without completion' do
          client.update_kv_secret_metadata(
            mount,
            path,
            {
              description: 'test description 1',
              environment: 'production',
              protected: 'true',
              update_started_at: iso(2.minutes.ago)
            },
            metadata_cas: cas
          )

          get_graphql(read_query, current_user: current_user)
          node = graphql_data_at(:group_secret)
          expect(node['status']).to eq('UPDATE_STALE')
        end
      end

      it 'avoids N+1 queries' do
        control_count = ActiveRecord::QueryRecorder.new do
          post_graphql(list_query, current_user: current_user)
        end

        SecretsManagement::GroupSecrets::CreateService.new(group, current_user).execute(
          name: 'MY_SECRET_3',
          description: 'test description 3',
          environment: 'production',
          protected: true,
          value: 'test value 3'
        )

        expect do
          post_graphql(list_query, current_user: current_user)
        end.not_to exceed_query_limit(control_count)
      end

      context 'and we can fetch secrets' do
        before do
          get_graphql(read_query, current_user: current_user)
        end

        it 'returns a secret' do
          expect(graphql_data_at(:group_secret))
            .to match(
              a_graphql_entity_for(
                group: a_graphql_entity_for(group),
                name: 'MY_SECRET_1',
                description: 'test description 1',
                environment: 'production',
                protected: true,
                metadata_version: 2
              )
            )
        end
      end

      context 'and we error on invalid secret fetches' do
        before do
          get_graphql(invalid_read_query, current_user: current_user)
        end

        it 'returns a top-level error' do
          expect(graphql_errors).to include(a_hash_including('message' => 'Group secret does not exist.'))
        end
      end
    end
  end
end
