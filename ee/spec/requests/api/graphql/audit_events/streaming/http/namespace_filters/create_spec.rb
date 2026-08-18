# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a namespace filter for group level external audit event destinations', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let(:destination) { create(:external_audit_event_destination, group: group) }
  let_it_be(:current_user) { create(:user) }
  let(:mutation) { graphql_mutation(:audit_events_streaming_http_namespace_filters_add, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_streaming_http_namespace_filters_add) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'does not create namespace filter' do
    it do
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

      expect { mutate }.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }

      expect(graphql_errors).to include(a_hash_including('message' => error_message))
      expect(mutation_response).to be_nil
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before_all do
        group.add_owner(current_user)
      end

      shared_examples 'creation of namespace filters with one path' do
        context 'when namespace is a descendant of the destination group' do
          let(:input) do
            {
              destinationId: destination.to_gid,
              "#{namespace_path.camelize(:lower)}": namespace.full_path
            }
          end

          it 'creates a namespace filter', :aggregate_failures do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
              name: 'create_http_namespace_filter',
              author: current_user,
              scope: group,
              target: destination,
              message: "Create namespace filter for http audit event streaming destination #{destination.name} " \
                       "and namespace #{namespace.full_path}")).once.and_call_original

            expect { mutate }
              .to change { AuditEventReader.count }.by(1)

            namespace_filter = destination.namespace_filter
            expect(namespace_filter.namespace).to eq(namespace)
            expect(namespace_filter.external_audit_event_destination).to eq(destination)

            expect_graphql_errors_to_be_empty

            expect(mutation_response['errors']).to be_empty
            expect(mutation_response).to have_key('namespaceFilter')
            expect(mutation_response['namespaceFilter']['namespace']['fullPath']).to eq(namespace.full_path)
            expect(mutation_response['namespaceFilter']['externalAuditEventDestination']['name'])
              .to eq(destination.name)
          end

          context 'when namespace filter for the destination already exists' do
            before do
              create(:audit_events_streaming_http_namespace_filter, external_audit_event_destination: destination,
                namespace: create(:group, parent: group))
            end

            it 'returns error' do
              expect { mutate }.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }

              expect(mutation_response['errors'])
                .to match_array(['External audit event destination has already been taken'])
              expect(mutation_response['namespaceFilter']).to be_nil
            end
          end

          context 'when namespace filter for the given namespace already exists' do
            before do
              create(:audit_events_streaming_http_namespace_filter,
                external_audit_event_destination: create(:external_audit_event_destination, group: group),
                namespace: namespace
              )
            end

            it 'returns error' do
              expect { mutate }.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }

              expect(mutation_response['errors']).to match_array(['Namespace has already been taken'])
              expect(mutation_response['namespaceFilter']).to be_nil
            end
          end
        end

        context 'when namespace group is not a descendant of the destination group' do
          let(:input) do
            {
              destinationId: destination.to_gid,
              "#{namespace_path.camelize(:lower)}": other_namespace.full_path
            }
          end

          it 'returns error' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            expect { mutate }.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }

            expect(mutation_response).to include(
              'errors' => ['External audit event destination does not belong to the top-level group of the namespace.']
            )
            expect(mutation_response['namespaceFilter']).to be_nil
          end
        end

        context 'when given namespace path is invalid' do
          let(:input) do
            {
              destinationId: destination.to_gid,
              "#{namespace_path.camelize(:lower)}": 'invalid_path'
            }
          end

          it 'returns error' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            expect { mutate }.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }

            expect(graphql_errors).to include(a_hash_including('message' => "#{namespace_path} is invalid"))
            expect(mutation_response).to be_nil
          end
        end
      end

      context 'when group_path is passed in params' do
        it_behaves_like 'creation of namespace filters with one path' do
          let_it_be(:namespace) { create(:group, parent: group) }
          let_it_be(:other_namespace) { create(:group) }
          let(:namespace_path) { "group_path" }
        end
      end

      context 'when project_path is passed in params' do
        it_behaves_like 'creation of namespace filters with one path' do
          let_it_be(:project) { create(:project, group: group) }
          let_it_be(:namespace) { project.project_namespace }
          let_it_be(:other_namespace) { create(:project_namespace) }
          let(:namespace_path) { "project_path" }
        end
      end

      context 'when both group_path and project_path are passed in params' do
        let_it_be(:namespace_group) { create(:group, parent: group) }
        let_it_be(:namespace_project) { create(:project, group: group) }

        let(:input) do
          {
            destinationId: destination.to_gid,
            projectPath: namespace_project.full_path,
            groupPath: namespace_group.full_path
          }
        end

        let(:error_message) { 'One and only one of [groupPath, projectPath] arguments is required.' }

        it_behaves_like 'does not create namespace filter'
      end

      context 'when none of group_path and project_path is passed in params' do
        let(:input) do
          {
            destinationId: destination.to_gid
          }
        end

        let(:error_message) { 'One and only one of [groupPath, projectPath] arguments is required.' }

        it_behaves_like 'does not create namespace filter'
      end

      context 'with sync functionality' do
        let(:namespace_path) { "group_path" }
        let_it_be(:namespace) { create(:group, parent: group) }

        let(:stream_destination) { create(:audit_events_group_external_streaming_destination, group: group) }
        let(:input) do
          {
            destinationId: destination.to_gid,
            "#{namespace_path.camelize(:lower)}": namespace.full_path
          }
        end

        context 'when legacy destination has corresponding streaming destination' do
          before do
            destination.update_column(:stream_destination_id, stream_destination.id)
          end

          it 'calls sync method after successful operation' do
            allow_next_instance_of(Mutations::AuditEvents::Streaming::HTTP::NamespaceFilters::Create) do |instance|
              allow(instance).to receive(:sync_stream_namespace_filter).and_return(nil)
            end

            mutate
            expect_graphql_errors_to_be_empty
          end
        end
      end
    end

    context 'when current user is a group maintainer' do
      before_all do
        group.add_maintainer(current_user)
      end

      let_it_be(:namespace_group) { create(:group, parent: group) }
      let(:input) do
        {
          destinationId: destination.to_gid,
          groupPath: namespace_group.full_path
        }
      end

      let(:error_message) { ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }

      it_behaves_like 'does not create namespace filter'
    end

    context 'when current user is a group developer' do
      before_all do
        group.add_developer(current_user)
      end

      let_it_be(:namespace_group) { create(:group, parent: group) }
      let(:input) do
        {
          destinationId: destination.to_gid,
          groupPath: namespace_group.full_path
        }
      end

      let(:error_message) { ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }

      it_behaves_like 'does not create namespace filter'
    end

    context 'when current user is a group guest' do
      before_all do
        group.add_guest(current_user)
      end

      let_it_be(:namespace_group) { create(:group, parent: group) }
      let(:input) do
        {
          destinationId: destination.to_gid,
          groupPath: namespace_group.full_path
        }
      end

      let(:error_message) { ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }

      it_behaves_like 'does not create namespace filter'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    let_it_be(:namespace_group) { create(:group, parent: group) }
    let(:input) do
      {
        destinationId: destination.to_gid,
        groupPath: namespace_group.full_path
      }
    end

    let(:error_message) { ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }

    it_behaves_like 'does not create namespace filter'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:user) }
    let_it_be(:namespace_group) { create(:group, parent: group) }

    let(:input) do
      {
        destinationId: destination.to_gid,
        groupPath: namespace_group.full_path
      }
    end

    before_all do
      group.add_owner(granular_token_user)
    end

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { group }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
