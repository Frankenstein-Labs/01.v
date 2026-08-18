# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Attributes::BulkUpdate,
  feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }
  let_it_be(:root_namespace) { namespace.root_ancestor }

  let_it_be(:category) do
    create(:security_category, namespace: root_namespace, name: 'Test Category')
  end

  let_it_be(:attribute1) do
    create(:security_attribute, security_category: category, name: 'Critical',
      namespace: root_namespace)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: category, name: 'High',
      namespace: root_namespace)
  end

  let(:items) { [project1.to_global_id.to_s, project2.to_global_id.to_s] }
  let(:prepared_items) { GitlabSchema.parse_gids(items, expected_type: [Group, Project]) }
  let(:attributes) { [attribute1.to_global_id.to_s, attribute2.to_global_id.to_s] }

  let(:mutation) do
    described_class.new(object: nil, context: query_context, field: nil)
  end

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#resolve' do
    context 'when user does not have permission' do
      it 'raises access denied error' do
        expect { mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD') }
          .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when access is denied during service execution' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      it 'handles Gitlab::Access::AccessDeniedError and raises resource not available' do
        allow_next_instance_of(Security::Attributes::BulkUpdateService) do |service|
          allow(service).to receive(:execute).and_raise(Gitlab::Access::AccessDeniedError)
        end

        expect { mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD') }
          .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when user has permission' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      context 'with valid arguments' do
        it 'calls bulk update service with correct parameters' do
          expect(Security::Attributes::BulkUpdateService).to receive(:new)
            .with(
              group_ids: [],
              project_ids: [project1.id, project2.id],
              attribute_ids: [attribute1.id, attribute2.id],
              mode: 'ADD',
              current_user: current_user
            )
            .and_return(instance_double(Security::Attributes::BulkUpdateService,
              execute: ServiceResponse.success))

          result = mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD')

          expect(result[:errors]).to be_empty
        end

        it 'returns success when service succeeds' do
          allow_next_instance_of(Security::Attributes::BulkUpdateService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          result = mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD')

          expect(result[:errors]).to be_empty
        end

        it 'returns error when service fails' do
          error_message = 'Service failed'
          allow_next_instance_of(Security::Attributes::BulkUpdateService) do |service|
            allow(service).to receive(:execute)
              .and_return(ServiceResponse.error(message: error_message))
          end

          result = mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD')

          expect(result[:errors]).to include(error_message)
        end
      end

      context 'with REMOVE mode' do
        it 'passes correct mode to service' do
          expect(Security::Attributes::BulkUpdateService).to receive(:new)
            .with(
              group_ids: [],
              project_ids: [project1.id, project2.id],
              attribute_ids: [attribute1.id, attribute2.id],
              mode: 'REMOVE',
              current_user: current_user
            )
            .and_return(instance_double(Security::Attributes::BulkUpdateService,
              execute: ServiceResponse.success))

          mutation.resolve(items: prepared_items, attributes: attributes, mode: 'REMOVE')
        end
      end

      context 'with groups in items' do
        let(:items) { [namespace.to_global_id.to_s] }
        let(:prepared_items) { GitlabSchema.parse_gids(items, expected_type: [Group, Project]) }

        it 'passes group IDs to service' do
          expect(Security::Attributes::BulkUpdateService).to receive(:new)
            .with(
              group_ids: [namespace.id],
              project_ids: [],
              attribute_ids: [attribute1.id, attribute2.id],
              mode: 'ADD',
              current_user: current_user
            )
            .and_return(instance_double(Security::Attributes::BulkUpdateService,
              execute: ServiceResponse.success))

          result = mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD')

          expect(result[:errors]).to be_empty
        end
      end

      context 'with mixed groups and projects' do
        let(:items) { [namespace.to_global_id.to_s, project1.to_global_id.to_s] }
        let(:prepared_items) { GitlabSchema.parse_gids(items, expected_type: [Group, Project]) }

        it 'separates group and project IDs correctly' do
          expect(Security::Attributes::BulkUpdateService).to receive(:new)
            .with(
              group_ids: [namespace.id],
              project_ids: [project1.id],
              attribute_ids: [attribute1.id, attribute2.id],
              mode: 'ADD',
              current_user: current_user
            )
            .and_return(instance_double(Security::Attributes::BulkUpdateService,
              execute: ServiceResponse.success))

          result = mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD')

          expect(result[:errors]).to be_empty
        end
      end

      context 'with REPLACE mode' do
        it 'passes correct mode to service' do
          expect(Security::Attributes::BulkUpdateService).to receive(:new)
            .with(
              group_ids: [],
              project_ids: [project1.id, project2.id],
              attribute_ids: [attribute1.id, attribute2.id],
              mode: 'REPLACE',
              current_user: current_user
            )
            .and_return(instance_double(Security::Attributes::BulkUpdateService,
              execute: ServiceResponse.success))

          mutation.resolve(items: prepared_items, attributes: attributes, mode: 'REPLACE')
        end
      end

      context 'when validating arguments' do
        context 'when items is empty' do
          it 'raises validation error' do
            expect { mutation.resolve(items: [], attributes: attributes, mode: 'ADD') }
              .to raise_error(Gitlab::Graphql::Errors::ArgumentError, 'Items cannot be empty')
          end
        end

        context 'when attributes is empty' do
          it 'raises validation error' do
            expect { mutation.resolve(items: prepared_items, attributes: [], mode: 'ADD') }
              .to raise_error(Gitlab::Graphql::Errors::ArgumentError, 'Attributes cannot be empty')
          end
        end

        context 'when too many items provided' do
          let(:too_many_items) { Array.new(described_class::MAX_ITEMS + 1) { project1.to_global_id.to_s } }

          it 'raises validation error during prepare step' do
            # Test the prepare step directly since resolve bypasses it in unit tests
            prepare_proc = described_class.arguments['items'].prepare
            expect { prepare_proc.call(too_many_items, nil) }
              .to raise_error(Gitlab::Graphql::Errors::ArgumentError, 'Too many items (maximum: 100)')
          end
        end

        context 'when too many attributes provided' do
          let(:too_many_attributes) { Array.new(described_class::MAX_ATTRIBUTES + 1) { attribute1.to_global_id.to_s } }

          it 'raises validation error' do
            expect { mutation.resolve(items: prepared_items, attributes: too_many_attributes, mode: 'ADD') }
              .to raise_error(Gitlab::Graphql::Errors::ArgumentError, 'Too many attributes (maximum: 20)')
          end
        end

        context 'when attribute is soft deleted' do
          let(:deleted_attribute) do
            create(:security_attribute, security_category: category, name: 'Deleted',
              namespace: root_namespace, deleted_at: Time.current)
          end

          let(:attributes) { [deleted_attribute.to_global_id.to_s] }

          it 'returns a resource not available error' do
            expect { mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD') }
              .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable,
                "The resource that you are attempting to access does not exist \
                or you don't have permission to perform this action".squish
              )
          end
        end

        context 'when some attributes are soft deleted' do
          let(:deleted_attribute) do
            create(:security_attribute, security_category: category, name: 'Deleted',
              namespace: root_namespace, deleted_at: Time.current)
          end

          let(:attributes) { [attribute1.to_global_id.to_s, deleted_attribute.to_global_id.to_s] }

          it 'returns a resource not available error for the first deleted attribute' do
            expect { mutation.resolve(items: prepared_items, attributes: attributes, mode: 'ADD') }
              .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable,
                "The resource that you are attempting to access does not exist \
                or you don't have permission to perform this action".squish
              )
          end
        end
      end
    end
  end
end
