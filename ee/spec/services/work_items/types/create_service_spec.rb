# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Types::CreateService, feature_category: :team_planning do
  let_it_be(:organization) { create(:organization) }
  let_it_be_with_reload(:group) { create(:group, organization: organization) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }
  let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

  let(:container) { group }
  let(:params) { { name: 'Custom Type', icon_name: 'bug' } }
  let(:expected_error_message) { 'Work item types can only be modified at the root group level' }
  let(:valid_icon_names) { ::WorkItems::TypesFramework::Custom::Type.icon_names.keys.sort.join(', ') }

  subject(:service) { described_class.new(container: container, current_user: user, params: params) }

  before do
    stub_saas_features(namespace_scoped_work_item_types: true)
    stub_licensed_features(work_item_status: true)
  end

  RSpec.shared_examples 'returns error response' do
    it 'returns error' do
      result = service.execute

      expect(result).to be_error
      expect(result.message).to eq(expected_error_message)
    end
  end

  RSpec.shared_examples 'creates custom type successfully' do
    it 'persists custom_type and returns success with work item type' do
      result = service.execute

      custom_type = WorkItems::TypesFramework::Custom::Type.last
      expect(custom_type.send(expected_parent_key)).to eq(container.id)
      expect(custom_type.send(expected_nil_key)).to be_nil

      expect(result).to be_success
      expect(result.payload[:work_item_type]).to be_a(WorkItems::TypesFramework::Custom::Type)
      expect(result.payload[:work_item_type].name).to eq('Custom Type')
      expect(result.payload[:work_item_type].icon_name).to eq('bug')
      expect(result.payload[:resource_parent]).to eq(container)
    end
  end

  describe '#execute' do
    context 'with root group container' do
      let(:container) { group }
      let(:expected_parent_key) { :namespace_id }
      let(:expected_nil_key) { :organization_id }

      it_behaves_like 'creates custom type successfully'

      it 'tracks create_work_item_type event', :clean_gitlab_redis_shared_state do
        expect { service.execute }
          .to trigger_internal_events('create_work_item_type')
          .with(user: user, namespace: group, additional_properties: { label: 'Custom Type' })
          .and increment_usage_metrics(
            'counts.count_total_create_work_item_type',
            'counts.count_total_create_work_item_type_weekly',
            'counts.count_total_create_work_item_type_monthly',
            'redis_hll_counters.count_distinct_namespace_id_from_create_work_item_type_weekly',
            'redis_hll_counters.count_distinct_namespace_id_from_create_work_item_type_monthly'
          )
      end
    end

    context 'when container is a lazy loaded object that responds to sync' do
      let(:container) { double(sync: group) } # rubocop:disable RSpec/VerifiedDoubles -- mock only

      it 'resolves the lazy container and creates custom type' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:resource_parent]).to eq(group)
      end
    end

    context 'with organization container' do
      let(:container) { organization }

      it_behaves_like 'returns error response'
    end

    context 'with subgroup container' do
      let(:container) { subgroup }

      it_behaves_like 'returns error response'
    end

    context 'with project container' do
      let(:container) { project }

      it_behaves_like 'returns error response'
    end

    context 'when container is nil' do
      let(:container) { nil }

      it_behaves_like 'returns error response'
    end

    context 'when icon_name is not present' do
      let(:params) { { name: 'Custom Type' } }
      let(:expected_error_message) do
        "Icon name is not valid. Valid icon names are: #{valid_icon_names} and Icon name can't be blank"
      end

      it_behaves_like 'returns error response'
    end

    context 'when icon_name is invalid' do
      let(:params) { { name: 'Custom Type', icon_name: 'invalid_icon' } }
      let(:expected_error_message) { "Icon name is not valid. Valid icon names are: #{valid_icon_names}" }

      it_behaves_like 'returns error response'
    end

    context 'when work item type has validation errors' do
      let(:params) { { name: '', icon_name: 'bug' } }
      let(:expected_error_message) { "Name can't be blank" }

      it_behaves_like 'returns error response'
    end

    context 'when enabled_by_default_for_new_namespaces is provided' do
      let(:params) { { name: 'Custom Type', icon_name: 'bug', enabled_by_default_for_new_namespaces: true } }
      let(:result) { service.execute }
      let(:expected_work_item_type) { WorkItems::TypesFramework::Custom::Type.last }
      let(:expected_namespace_id) { group.id }
      let(:expected_organization_id) { nil }

      it_behaves_like 'upserts visibility default'

      context 'when set to false' do
        let(:params) { { name: 'Custom Type', icon_name: 'bug', enabled_by_default_for_new_namespaces: false } }

        it_behaves_like 'upserts visibility default with enabled false'
      end
    end

    context 'when enabled_by_default_for_new_namespaces is not provided' do
      let(:params) { { name: 'Custom Type', icon_name: 'bug' } }
      let(:result) { service.execute }

      it_behaves_like 'does not create a visibility default record'
    end

    context 'when converting from a system-defined type' do
      let(:params) do
        { name: 'Custom Issue', icon_name: 'bug',
          converted_from_system_defined_type_identifier: 1 }
      end

      it 'does not track create_work_item_type event' do
        expect { service.execute }.not_to trigger_internal_events('create_work_item_type')
      end
    end

    context 'when creation fails' do
      let(:params) { { name: '', icon_name: 'bug' } }

      it 'does not track create_work_item_type event' do
        expect { service.execute }.not_to trigger_internal_events('create_work_item_type')
      end
    end

    context 'with custom lifecycle attachment' do
      context 'when namespace uses system-defined lifecycles' do
        let(:container) { group }

        it 'does not create TypeCustomLifecycle records' do
          expect { service.execute }.not_to change { WorkItems::TypeCustomLifecycle.count }
        end
      end

      context 'when namespace uses custom lifecycles' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }
        let(:container) { group }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: issue_type.id,
            lifecycle: custom_lifecycle,
            namespace: group
          )
        end

        it 'attaches the new custom type to the custom lifecycle' do
          result = nil
          expect { result = service.execute }.to change { WorkItems::TypeCustomLifecycle.count }.by(1)

          work_item_type = result.payload[:work_item_type]
          type_lifecycle = WorkItems::TypeCustomLifecycle.find_by(work_item_type_id: work_item_type.id)

          expect(type_lifecycle).to be_present
          expect(type_lifecycle.lifecycle).to eq(custom_lifecycle)
          expect(type_lifecycle.namespace).to eq(group)
        end

        context 'when provider cache is pre-warmed within the same request', :request_store do
          it 'still attaches the new custom type to the custom lifecycle' do
            # Simulate a prior call in the same request that builds the Provider's
            # SafeRequestStore cache before the new custom type exists.
            provider = WorkItems::TypesFramework::Provider.new(group)
            provider.all

            cache_key = "work_items_types_provider:#{group.class.base_class.name}:#{group.id}"
            expect(Gitlab::SafeRequestStore.exist?(cache_key)).to be(true)

            result = nil
            expect { result = service.execute }.to change { WorkItems::TypeCustomLifecycle.count }.by(1)

            expect(result).to be_success

            work_item_type = result.payload[:work_item_type]
            type_lifecycle = WorkItems::TypeCustomLifecycle.find_by(work_item_type_id: work_item_type.id)

            expect(type_lifecycle).to be_present
            expect(type_lifecycle.lifecycle).to eq(custom_lifecycle)
            expect(type_lifecycle.namespace).to eq(group)
          end
        end

        context 'when custom type is converted from a system-defined type' do
          let(:params) do
            { name: 'Custom Task', icon_name: 'work-item-task',
              converted_from_system_defined_type_identifier: task_type.id }
          end

          it 'skips lifecycle attachment since converted types inherit from system-defined type' do
            result = nil
            expect { result = service.execute }.not_to change { WorkItems::TypeCustomLifecycle.count }

            work_item_type = result.payload[:work_item_type]
            type_lifecycle = WorkItems::TypeCustomLifecycle.find_by(work_item_type_id: work_item_type.id)

            expect(type_lifecycle).to be_nil
          end
        end
      end

      context 'when namespace has custom lifecycle but Issue type is not attached to it' do
        let_it_be(:task_only_lifecycle) { create(:work_item_custom_lifecycle, namespace: group, name: 'Tasks Only') }
        let(:container) { group }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: task_type.id,
            lifecycle: task_only_lifecycle,
            namespace: group
          )
        end

        it 'falls back to the first available custom lifecycle in the namespace' do
          result = nil
          expect { result = service.execute }.to change { WorkItems::TypeCustomLifecycle.count }.by(1)

          work_item_type = result.payload[:work_item_type]
          type_lifecycle = WorkItems::TypeCustomLifecycle.find_by(work_item_type_id: work_item_type.id)

          expect(type_lifecycle).to be_present
          expect(type_lifecycle.lifecycle).to eq(task_only_lifecycle)
          expect(type_lifecycle.namespace).to eq(group)
        end
      end
    end

    context 'when transaction rollback occurs' do
      context 'when attach_to_custom_lifecycle_for_namespace fails' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }
        let(:container) { group }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: issue_type.id,
            lifecycle: custom_lifecycle,
            namespace: group
          )

          allow(WorkItems::TypeCustomLifecycle).to receive(:create!).and_raise(StandardError, 'Lifecycle error')
        end

        it 'rolls back custom type creation' do
          expect { service.execute }.not_to change { WorkItems::TypesFramework::Custom::Type.count }
        end

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Lifecycle error')
        end
      end
    end

    context 'on self-managed' do
      let(:expected_error_message) { 'Work item types can only be modified at the organization level' }

      before do
        stub_saas_features(namespace_scoped_work_item_types: false)
      end

      context 'with root group container' do
        let(:container) { group }

        it_behaves_like 'returns error response'
      end

      context 'with subgroup container' do
        let(:container) { subgroup }

        it_behaves_like 'returns error response'
      end

      context 'with project container' do
        let(:container) { project }

        it_behaves_like 'returns error response'
      end

      context 'with organization container' do
        let(:container) { organization }
        let(:expected_parent_key) { :organization_id }
        let(:expected_nil_key) { :namespace_id }

        it_behaves_like 'creates custom type successfully'

        it 'tracks create_work_item_type event', :clean_gitlab_redis_shared_state do
          expect { service.execute }
            .to trigger_internal_events('create_work_item_type')
            .with(user: user, additional_properties: { label: 'Custom Type' })
            .and increment_usage_metrics(
              'counts.count_total_create_work_item_type',
              'counts.count_total_create_work_item_type_weekly',
              'counts.count_total_create_work_item_type_monthly'
            )
        end

        context 'when enabled_by_default_for_new_namespaces is provided' do
          let(:params) { { name: 'Custom Type', icon_name: 'bug', enabled_by_default_for_new_namespaces: true } }
          let(:result) { service.execute }
          let(:expected_work_item_type) { WorkItems::TypesFramework::Custom::Type.last }
          let(:expected_namespace_id) { nil }
          let(:expected_organization_id) { organization.id }

          it_behaves_like 'upserts visibility default'
        end

        context 'when organization has multiple root groups' do
          let_it_be(:group_with_custom_lifecycle) { create(:group, organization: organization) }
          let_it_be(:another_group_with_custom_lifecycle) { create(:group, organization: organization) }
          let_it_be(:group_without_custom_lifecycle) { create(:group, organization: organization) }

          let_it_be(:custom_lifecycle_1) { create(:work_item_custom_lifecycle, namespace: group_with_custom_lifecycle) }
          let_it_be(:custom_lifecycle_2) do
            create(:work_item_custom_lifecycle, namespace: another_group_with_custom_lifecycle)
          end

          context 'when groups have custom lifecycles attached' do
            before do
              create(:work_item_type_custom_lifecycle,
                work_item_type_id: issue_type.id,
                lifecycle: custom_lifecycle_1,
                namespace: group_with_custom_lifecycle
              )
              create(:work_item_type_custom_lifecycle,
                work_item_type_id: issue_type.id,
                lifecycle: custom_lifecycle_2,
                namespace: another_group_with_custom_lifecycle
              )
            end

            it 'attaches the new custom type to all namespaces with custom lifecycles' do
              result = nil
              expect { result = service.execute }.to change { WorkItems::TypeCustomLifecycle.count }.by(2)

              work_item_type = result.payload[:work_item_type]
              type_lifecycles = WorkItems::TypeCustomLifecycle.where(work_item_type_id: work_item_type.id)

              expect(type_lifecycles.count).to eq(2)
              expect(type_lifecycles.pluck(:namespace_id)).to match_array([
                group_with_custom_lifecycle.id,
                another_group_with_custom_lifecycle.id
              ])
            end

            it 'does not attach to namespaces without custom lifecycles' do
              result = service.execute

              work_item_type = result.payload[:work_item_type]
              type_lifecycle = WorkItems::TypeCustomLifecycle.find_by(
                work_item_type_id: work_item_type.id,
                namespace_id: group_without_custom_lifecycle.id
              )

              expect(type_lifecycle).to be_nil
            end

            context 'when processing groups in batches' do
              before do
                # Create a SECOND type_custom_lifecycle for group_with_custom_lifecycle
                # (the first one was created in the parent before block for issue_type)
                create(:work_item_type_custom_lifecycle,
                  work_item_type_id: task_type.id,
                  lifecycle: custom_lifecycle_1,
                  namespace: group_with_custom_lifecycle
                )

                stub_const("#{described_class}::LIFECYCLE_BATCH_SIZE", 1)
              end

              it 'does not create duplicate records for the same namespace' do
                result = nil

                expect { result = service.execute }.to change { WorkItems::TypeCustomLifecycle.count }.by(2)

                work_item_type = result.payload[:work_item_type]
                type_lifecycles = WorkItems::TypeCustomLifecycle.where(work_item_type_id: work_item_type.id)

                # It should create 2 records, one for each namespace that has custom lifecycles
                expect(type_lifecycles.count).to eq(2)
                expect(type_lifecycles.pluck(:namespace_id)).to match_array([
                  group_with_custom_lifecycle.id,
                  another_group_with_custom_lifecycle.id
                ])
              end

              it 'skips batches where no groups have custom lifecycles' do
                # There are 3 groups in the organization. With LIFECYCLE_BATCH_SIZE = 1, each group
                # is processed in its own batch. The third group (group_without_custom_lifecycle) has
                # no type_custom_lifecycles, so insert_all! is only called twice for the other two groups.
                expect(WorkItems::TypeCustomLifecycle).to receive(:insert_all!).twice.and_call_original

                service.execute
              end
            end
          end

          context 'when the groups do not have custom lifecycles' do
            it 'skips insert_all! when records array is empty' do
              expect(WorkItems::TypeCustomLifecycle).not_to receive(:insert_all!)

              service.execute
            end
          end
        end

        context 'when transaction rollback occurs' do
          context 'when attach_to_custom_lifecycle_for_organization fails' do
            let_it_be(:group_with_lifecycle) { create(:group, organization: organization) }
            let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: group_with_lifecycle) }
            let(:container) { organization }

            before do
              create(:work_item_type_custom_lifecycle,
                work_item_type_id: issue_type.id,
                lifecycle: custom_lifecycle,
                namespace: group_with_lifecycle
              )

              allow(WorkItems::TypeCustomLifecycle).to receive(:insert_all!).and_raise(StandardError,
                'Bulk insert error')
            end

            it 'rolls back custom type creation' do
              expect { service.execute }.not_to change { WorkItems::TypesFramework::Custom::Type.count }
            end

            it 'does not create any lifecycle records' do
              expect { service.execute }.not_to change { WorkItems::TypeCustomLifecycle.count }
            end

            it 'returns error response' do
              result = service.execute

              expect(result).to be_error
              expect(result.message).to eq('Bulk insert error')
            end
          end
        end
      end

      context 'when container is nil' do
        let(:container) { nil }

        it_behaves_like 'returns error response'
      end
    end
  end
end
