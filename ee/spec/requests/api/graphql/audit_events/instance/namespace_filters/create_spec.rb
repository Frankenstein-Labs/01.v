# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a namespace filter for instance level external audit event destinations', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be_with_reload(:destination) { create(:audit_events_instance_external_streaming_destination) }
  let_it_be(:current_user) { create(:user) }
  let(:mutation) { graphql_mutation(:audit_events_instance_destination_namespace_filter_create, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_instance_destination_namespace_filter_create) }

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is instance admin' do
      let(:current_user) { create(:admin) }

      shared_examples 'creation of namespace filters' do
        context 'when namespace_path is valid' do
          let(:input) do
            {
              destinationId: destination.to_gid,
              namespacePath: namespace.full_path
            }
          end

          it 'creates a namespace filter', :aggregate_failures do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
              name: 'created_instance_namespace_filter',
              author: current_user,
              scope: an_instance_of(Gitlab::Audit::InstanceScope),
              target: destination,
              message: "Created namespace filter for instance audit event streaming destination.",
              additional_details: {
                destination_name: destination.name,
                namespace: namespace.full_path
              }
            )).once.and_call_original

            expect { subject }
              .to change { AuditEventReader.count }.by(1)

            namespace_filters = destination.namespace_filters
            expect(namespace_filters.first.namespace).to eq(namespace)
            expect(namespace_filters.first.external_streaming_destination).to eq(destination)

            expect_graphql_errors_to_be_empty

            expect(mutation_response['errors']).to be_empty
            expect(mutation_response).to have_key('namespaceFilter')
            expect(mutation_response['namespaceFilter']['namespace']['fullPath']).to eq(namespace.full_path)
            expect(mutation_response['namespaceFilter']['externalStreamingDestination']['name'])
              .to eq(destination.name)
          end

          context 'when namespace filter for the given namespace already exists' do
            before do
              create(:audit_events_streaming_instance_namespace_filters,
                external_streaming_destination: destination,
                namespace: namespace
              )
            end

            it 'returns error' do
              expect { subject }.not_to change { AuditEvents::Instance::NamespaceFilter.count }

              expect(mutation_response['errors']).to match_array(['Namespace has already been taken'])
              expect(mutation_response['namespaceFilter']).to be_nil
            end
          end
        end

        context 'when given namespace path is invalid' do
          let(:input) do
            {
              destinationId: destination.to_gid,
              namespace_path: 'invalid_path'
            }
          end

          it 'returns error' do
            expect { subject }.not_to change { AuditEvents::Instance::NamespaceFilter.count }

            expect(graphql_errors)
              .to include(a_hash_including('message' => "namespace_path should be of group or project only."))
            expect(mutation_response).to be_nil
          end
        end

        context 'with sync functionality' do
          let_it_be_with_reload(:legacy_destination) { create(:instance_external_audit_event_destination) }
          let(:input) do
            {
              destinationId: destination.to_gid,
              namespacePath: namespace.full_path
            }
          end

          context 'when streaming destination has corresponding legacy destination' do
            before do
              destination.update_column(:legacy_destination_ref, legacy_destination.id)
              legacy_destination.update_column(:stream_destination_id, destination.id)
            end

            it 'calls sync method after successful operation' do
              expect_next_instance_of(Mutations::AuditEvents::Instance::NamespaceFilters::Create) do |instance|
                expect(instance).to receive(:sync_legacy_namespace_filter)
                                .with(destination, namespace)
              end

              subject
              expect_graphql_errors_to_be_empty
            end
          end
        end
      end

      context 'when group_path is passed in params' do
        it_behaves_like 'creation of namespace filters' do
          let_it_be(:namespace) { create(:group) }
        end
      end

      context 'when project_path is passed in params' do
        it_behaves_like 'creation of namespace filters' do
          let_it_be(:project) { create(:project, group: create(:group)) }
          let_it_be(:namespace) { project.project_namespace }
        end
      end

      context 'when namespace_path is invalid' do
        let(:input) do
          {
            destinationId: destination.to_gid,
            namespace_path: 'invalid_path'
          }
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ['namespace_path should be of group or project only.']
      end
    end

    context 'when current user is not instance admin' do
      let_it_be(:namespace_group) { create(:group) }
      let(:input) do
        {
          destinationId: destination.to_gid,
          namespacePath: namespace_group.full_path
        }
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    let_it_be(:namespace_group) { create(:group) }
    let(:input) do
      {
        destinationId: destination.to_gid,
        namespacePath: namespace_group.full_path
      }
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:admin) }
    let_it_be(:namespace_group) { create(:group) }

    let(:input) do
      {
        destinationId: destination.to_gid,
        namespacePath: namespace_group.full_path
      }
    end

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { :instance }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
