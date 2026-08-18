# frozen_string_literal: true

RSpec.shared_examples Ai::Catalog::Items::BaseDestroyService do
  let_it_be(:project, freeze: false) { create(:project, :in_group) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:admin, freeze: false) { create(:admin) }

  let(:params) { { item: item } }
  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  subject(:execute_service) { service.execute }

  shared_examples 'returns insufficient permissions error' do
    it 'returns insufficient permissions error' do
      result = execute_service

      expect(result).to be_error
      expect(result.errors).to contain_exactly('You have insufficient permissions')
    end

    it 'does not destroy any items' do
      expect { execute_service }.not_to change { Ai::Catalog::Item.count }
    end
  end

  shared_examples 'hard deletes the item' do
    it 'destroys the item successfully' do
      expect { execute_service }.to change { Ai::Catalog::Item.count }.by(-1)
    end

    it 'destroys item versions' do
      expect { execute_service }.to change { Ai::Catalog::ItemVersion.count }.by(-1)
    end

    it 'triggers delete_ai_catalog_item', :clean_gitlab_redis_shared_state do
      expect { execute_service }
        .to trigger_internal_events('delete_ai_catalog_item')
        .with(user: user, project: project, additional_properties: expected_delete_event_properties)
        .and increment_usage_metrics('counts.count_total_delete_ai_catalog_item')
    end

    it 'returns success response' do
      result = execute_service

      expect(result.success?).to be(true)
    end
  end

  shared_examples 'soft deletes the item' do
    it 'soft deletes the item' do
      expect { execute_service }.to change { item.deleted_at }.from(nil)
    end

    it 'does not destroy the item' do
      expect { execute_service }.not_to change { Ai::Catalog::Item.count }
    end

    it 'does not destroy item versions' do
      expect { execute_service }.not_to change { Ai::Catalog::ItemVersion.count }
    end

    it 'triggers delete_ai_catalog_item', :clean_gitlab_redis_shared_state do
      expect { execute_service }
        .to trigger_internal_events('delete_ai_catalog_item')
        .with(user: user, project: project, additional_properties: expected_delete_event_properties)
        .and increment_usage_metrics('counts.count_total_delete_ai_catalog_item')
    end

    it 'returns success response' do
      result = execute_service

      expect(result.success?).to be(true)
    end
  end

  shared_examples 'a successful request' do
    it_behaves_like 'hard deletes the item'

    context 'when item is only being used by the project' do
      before do
        create(:ai_catalog_item_consumer, item: item, project: project)
      end

      it_behaves_like 'hard deletes the item'
    end

    context 'when item is being used by other projects' do
      before do
        create(:ai_catalog_item_consumer, item: item, project: create(:project))
      end

      it_behaves_like 'soft deletes the item'

      context 'with `force_hard_delete` param', :enable_admin_mode do
        let(:params) { super().merge(force_hard_delete: true) }

        it_behaves_like 'returns insufficient permissions error'

        context 'when the user is an admin' do
          let(:user) { admin }
          let(:expected_delete_event_properties) { super().merge(hard_deleted: 'true') }

          it_behaves_like 'hard deletes the item'

          it 'destroys the item consumers' do
            expect { execute_service }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
          end
        end
      end
    end
  end

  describe '#execute' do
    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when item is nil' do
        let(:params) { { item: nil } }

        it_behaves_like 'returns insufficient permissions error'
      end

      context 'when item is nil but user has permissions' do
        let(:params) { { item: nil } }

        before do
          allow(service).to receive(:allowed?).and_return(true)
        end

        it 'returns not found error' do
          result = execute_service

          expect(result).to be_error
          expect(result.errors).to contain_exactly(not_found_error)
        end
      end

      context 'when item exists' do
        it_behaves_like 'a successful request'

        it 'creates an audit event on successful destroy', :aggregate_failures do
          event_name = "delete_ai_catalog_#{item.item_type}"

          expect { execute_service }.to change { AuditEventReader.count }.by(1)

          audit_event = AuditEventReader.last

          expect(audit_event).to have_attributes(
            author: user,
            entity_type: 'Project',
            entity_id: project.id,
            target_details: "#{item.name} (ID: #{item.id})"
          )
          expect(audit_event.details).to include(
            custom_message: "Deleted AI #{item.human_item_type}",
            event_name: event_name,
            target_type: 'Ai::Catalog::Item'
          )
        end

        context 'when item is being used by both the project and another project' do
          let_it_be(:other_project, freeze: false) { create(:project) }

          before do
            create(:ai_catalog_item_consumer, item: item, project: other_project)
            create(:ai_catalog_item_consumer, item: item, project: project)
          end

          it "deletes just the project's consumer record, and soft deletes the item" do
            expect { execute_service }.to change { item.deleted_at }.from(nil)

            expect(other_project.configured_ai_catalog_items.size).to eq(1)
            expect(project.configured_ai_catalog_items).to be_empty
          end
        end

        context 'when an error happens when deleting the consumer' do
          before do
            create(:ai_catalog_item_consumer, item: item, project: project)

            allow_next_instance_of(Ai::Catalog::ItemConsumers::DestroyService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Failure'))
            end
          end

          it 'does not destroy the item' do
            expect { execute_service }.not_to change { Ai::Catalog::Item.count }
          end

          it 'returns error response' do
            result = execute_service

            expect(result).to be_error
            expect(result.errors).to contain_exactly('Failure')
          end
        end

        context 'when item is a dependency of other items (has item_version_dependency)' do
          before do
            create(:ai_catalog_item_version_dependency, dependency_id: item.id)
          end

          it_behaves_like 'soft deletes the item'

          context 'with `force_hard_delete` param', :enable_admin_mode do
            let(:params) { super().merge(force_hard_delete: true) }

            it_behaves_like 'returns insufficient permissions error'

            context 'when the user is an admin' do
              let(:user) { admin }
              let(:expected_delete_event_properties) { super().merge(hard_deleted: 'true') }

              it_behaves_like 'hard deletes the item'

              it 'destroys the version dependencies' do
                expect { execute_service }.to change { Ai::Catalog::ItemVersionDependency.count }.by(-1)
              end
            end
          end
        end
      end

      context 'when item destruction fails' do
        before do
          allow(item).to receive(:destroy).and_return(false)
          item.errors.add(:base, 'Item cannot be destroyed')
        end

        it 'does not destroy the item' do
          expect { execute_service }.not_to change { Ai::Catalog::Item.count }
        end

        it 'returns error response' do
          result = execute_service

          expect(result).to be_error
          expect(result.errors).to contain_exactly('Item cannot be destroyed')
        end

        it 'does not create an audit event' do
          expect { execute_service }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'returns insufficient permissions error'
    end

    if described_class < Ai::Catalog::Items::BaseDestroyService
      context 'when catalog item is the wrong type' do
        let_it_be(:item, freeze: false) { incorrect_item_type }

        before_all do
          project.add_maintainer(user)
        end

        it 'returns not found error' do
          result = execute_service

          expect(result).to be_error
          expect(result.errors).to contain_exactly(not_found_error)
        end

        it 'does not destroy any items' do
          expect { execute_service }.not_to change { Ai::Catalog::Item.count }
        end

        it 'does not destroy any item versions' do
          expect { execute_service }.not_to change { Ai::Catalog::ItemVersion.count }
        end

        it 'does not trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
          expect { execute_service }
            .not_to trigger_internal_events('delete_ai_catalog_item')
        end
      end
    end
  end
end
