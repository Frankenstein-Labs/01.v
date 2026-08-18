# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a namespace filter for instance level external audit event destinations', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:destination) { create(:audit_events_instance_external_streaming_destination) }
  let_it_be(:filter) do
    create(:audit_events_streaming_instance_namespace_filters, external_streaming_destination: destination,
      namespace: group)
  end

  let(:mutation) { graphql_mutation(:audit_events_instance_destination_namespace_filter_delete, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_instance_destination_namespace_filter_delete) }

  let(:input) do
    { namespaceFilterId: filter.to_gid }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is instance admin' do
      let_it_be(:current_user) { create(:admin) }

      context 'when namespace filter id is valid' do
        it 'deletes the filter', :aggregate_failures do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
            name: 'deleted_instance_namespace_filter',
            author: current_user,
            scope: an_instance_of(Gitlab::Audit::InstanceScope),
            target: destination,
            message: "Deleted namespace filter for instance audit event streaming destination."))
                                                             .once.and_call_original

          expect { mutate }.to change { AuditEvents::Instance::NamespaceFilter.count }.by(-1)

          expect(destination.reload.namespace_filters).to be_empty
          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['namespaceFilter']).to be_nil
        end

        context 'with sync functionality' do
          let(:legacy_destination) { create(:instance_external_audit_event_destination) }

          context 'when streaming destination has corresponding legacy destination' do
            before do
              destination.update_column(:legacy_destination_ref, legacy_destination.id)
            end

            it 'calls sync method after successful deletion' do
              expect_next_instance_of(Mutations::AuditEvents::Instance::NamespaceFilters::Delete) do |instance|
                expect(instance).to receive(:sync_delete_legacy_namespace_filter)
                              .with(destination)
              end

              mutate

              expect_graphql_errors_to_be_empty
              expect(mutation_response['errors']).to be_empty
            end
          end

          context 'when streaming destination has no legacy destination' do
            it 'calls sync method but it does nothing internally' do
              expect_next_instance_of(Mutations::AuditEvents::Instance::NamespaceFilters::Delete) do |instance|
                expect(instance).to receive(:sync_delete_legacy_namespace_filter)
                              .with(destination)
                              .and_call_original
              end

              mutate

              expect_graphql_errors_to_be_empty
              expect(mutation_response['errors']).to be_empty
            end
          end
        end
      end

      context 'when namespace filter id is invalid' do
        let(:input) do
          { namespaceFilterId: 'gid://gitlab/AuditEvents::Instance::NamespaceFilter/invalid_id' }
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end

    context 'when current user is not instance admin' do
      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  context 'when feature is not licensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:admin) }

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
