# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Lifecycles::AttachWorkItemTypeService, feature_category: :team_planning do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:system_defined_to_do_status) { build(:work_item_system_defined_status) }
  let(:work_item_type) { create(:work_item_system_defined_type, :issue) }
  let(:requirement_work_item_type) { create(:work_item_system_defined_type, :requirement) }
  let(:container) { group }
  let(:current_user) { user }
  let(:work_item_type_id) { work_item_type.to_gid }
  let(:lifecycle_id) { target_lifecycle.to_gid }

  let(:params) do
    {
      work_item_type_id: work_item_type_id,
      lifecycle_id: lifecycle_id
    }
  end

  subject(:result) do
    described_class.new(container: container, current_user: current_user, params: params).execute
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe '#execute' do
    let!(:target_lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }
    let!(:current_lifecycle) { create(:work_item_custom_lifecycle, :for_issues, namespace: group) }

    let(:lifecycle) { result.payload[:lifecycle] }

    shared_examples 'work item type successfully attached' do
      it 'returns success response' do
        expect(result).to be_success
        expect(lifecycle).to eq(target_lifecycle)
      end

      it 'attaches work item type to target lifecycle' do
        expect { result }.to change { target_lifecycle.reload.work_item_types.count }.by(1)

        target_lifecycle.reset
        current_lifecycle.reset

        expect(target_lifecycle.work_item_type_ids).to include(work_item_type.id)
        expect(target_lifecycle.updated_by).to eq(user)

        expect(current_lifecycle.work_item_type_ids).not_to include(work_item_type.id)
        expect(current_lifecycle.reset.updated_by).to eq(user)
      end

      it 'tracks attach work item type event', :clean_gitlab_redis_shared_state do
        expect { result }
          .to trigger_internal_events('attach_work_item_type_to_custom_lifecycle')
          .with(user: user, namespace: group, additional_properties: { label: work_item_type.name })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_namespace_id_from_attach_work_item_type_to_custom_lifecycle_monthly',
            'redis_hll_counters.count_distinct_namespace_id_from_attach_work_item_type_to_custom_lifecycle_weekly',
            'counts.count_total_attach_work_item_type_to_custom_lifecycle_monthly',
            'counts.count_total_attach_work_item_type_to_custom_lifecycle_weekly',
            'counts.count_total_attach_work_item_type_to_custom_lifecycle'
          )
      end
    end

    it_behaves_like 'work item type successfully attached'

    context 'when status of current lifecycle is in use' do
      let(:work_item) { create(:work_item, namespace: group) }
      let!(:current_status) do
        create(:work_item_current_status, work_item: work_item, custom_status: current_lifecycle.default_open_status)
      end

      context 'and is not in target lifecycle' do
        let(:expected_error_message) do
          "Cannot remove status '#{current_lifecycle.default_open_status.name}' from lifecycle " \
            "because it is in use and no mapping is provided"
        end

        it_behaves_like 'lifecycle service returns validation error'
      end

      context 'and is in target lifecycle' do
        before do
          create(:work_item_custom_lifecycle_status,
            lifecycle: target_lifecycle, status: current_lifecycle.default_open_status, namespace: group)
        end

        it_behaves_like 'work item type successfully attached'
      end
    end

    context 'when status mappings are provided' do
      let_it_be(:current_status) { create(:work_item_custom_status, namespace: group) }
      let_it_be(:target_status) { create(:work_item_custom_status, namespace: group) }
      let_it_be(:other_status) { create(:work_item_custom_status, namespace: group) }

      let(:mapping) { WorkItems::Statuses::Custom::Mapping.last }

      let(:params) do
        super().merge(
          status_mappings: [
            {
              old_status_id: current_status.to_gid,
              new_status_id: target_status.to_gid
            }
          ]
        )
      end

      before do
        create(:work_item_custom_lifecycle_status,
          lifecycle: current_lifecycle, status: current_status, namespace: group)
        create(:work_item_custom_lifecycle_status,
          lifecycle: target_lifecycle, status: target_status, namespace: group)
      end

      it_behaves_like 'work item type successfully attached'

      it 'creates unbounded mapping' do
        expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

        expect(mapping).to have_attributes(
          namespace_id: group.id,
          work_item_type_id: work_item_type.id,
          old_status_id: current_status.id,
          old_status_role: nil,
          new_status_id: target_status.id,
          valid_from: nil,
          valid_until: nil
        )
      end

      context 'when old status is default status' do
        let(:params) do
          super().merge(
            status_mappings: [
              {
                old_status_id: old_status.to_gid,
                new_status_id: new_status.to_gid
              }
            ]
          )
        end

        shared_examples 'attaches work item type with bounded mapping and old status role' do
          it_behaves_like 'work item type successfully attached'

          it 'creates bounded mapping with old status role', :freeze_time do
            expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

            expect(mapping).to have_attributes(
              namespace_id: group.id,
              work_item_type_id: work_item_type.id,
              old_status_id: old_status.id,
              old_status_role: old_status_role,
              new_status_id: new_status.id,
              valid_from: nil,
              valid_until: Time.current
            )
          end
        end

        context 'when default open status' do
          let(:old_status) { current_lifecycle.default_open_status }
          let(:new_status) { target_status }
          let(:old_status_role) { "open" }

          it_behaves_like 'attaches work item type with bounded mapping and old status role'
        end

        context 'when default closed status' do
          let(:old_status) { current_lifecycle.default_closed_status }
          let(:new_status) { target_lifecycle.default_closed_status }
          let(:old_status_role) { "closed" }

          it_behaves_like 'attaches work item type with bounded mapping and old status role'
        end

        context 'when default duplicate status' do
          let(:old_status) { current_lifecycle.default_duplicate_status }
          let(:new_status) { target_lifecycle.default_duplicate_status }
          let(:old_status_role) { "duplicate" }

          it_behaves_like 'attaches work item type with bounded mapping and old status role'
        end
      end

      context 'when old status exists in target lifecycle' do
        before do
          create(:work_item_custom_lifecycle_status,
            lifecycle: target_lifecycle, status: current_status, namespace: group)
        end

        it_behaves_like 'work item type successfully attached'

        it 'creates mapping with immediate cutoff', :freeze_time do
          expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

          expect(mapping).to have_attributes(
            namespace_id: group.id,
            work_item_type_id: work_item_type.id,
            old_status_id: current_status.id,
            old_status_role: nil,
            new_status_id: target_status.id,
            valid_from: nil,
            valid_until: Time.current
          )
        end
      end

      context 'with existing mapping from old status' do
        let!(:existing_mapping) do
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: work_item_type,
            old_status: current_status,
            new_status: other_status,
            valid_until: 5.days.ago
          )
        end

        it_behaves_like 'work item type successfully attached'

        it 'creates mapping with valid_from', :freeze_time do
          expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

          expect(mapping).to have_attributes(
            namespace_id: group.id,
            work_item_type_id: work_item_type.id,
            old_status_id: current_status.id,
            old_status_role: nil,
            new_status_id: target_status.id,
            valid_from: existing_mapping.valid_until,
            valid_until: nil
          )
        end

        context 'with existing unbounded mapping from old status' do
          let!(:existing_mapping) do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item_type,
              old_status: current_status,
              new_status: other_status
            )
          end

          it 'sets bounds for existing mapping and creates mapping with valid_from', :freeze_time do
            expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(1)

            expect(existing_mapping.reset).to have_attributes(
              valid_until: Time.current
            )

            expect(mapping).to have_attributes(
              namespace_id: group.id,
              work_item_type_id: work_item_type.id,
              old_status_id: current_status.id,
              old_status_role: nil,
              new_status_id: target_status.id,
              valid_from: existing_mapping.valid_until,
              valid_until: nil
            )
          end
        end
      end

      context 'when mapping chain would be created' do
        let!(:existing_mapping) do
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: work_item_type,
            old_status: other_status,
            new_status: current_status
          )
        end

        it_behaves_like 'work item type successfully attached'

        it 'prevents mapping chains by updating existing mapping' do
          expect { result }.to change { existing_mapping.reset.new_status_id }
            .from(current_status.id).to(target_status.id)
        end
      end

      context 'with invalid mapping' do
        let(:old_status_id) { current_status.to_gid }
        let(:new_status_id) { target_status.to_gid }
        let(:params) do
          super().merge(
            status_mappings: [
              {
                old_status_id: old_status_id,
                new_status_id: new_status_id
              }
            ]
          )
        end

        context 'with system-defined status' do
          let(:expected_error_message) { "Custom statuses need to be provided for mappings" }

          context 'for old status' do
            let(:old_status_id) { system_defined_to_do_status.to_gid }

            it_behaves_like 'lifecycle service returns validation error'
          end

          context 'for new status' do
            let(:new_status_id) { system_defined_to_do_status.to_gid }

            it_behaves_like 'lifecycle service returns validation error'
          end
        end

        context 'with non-existing old status' do
          let(:old_status_id) { GlobalID.parse('gid://gitlab/WorkItems::Statuses::Custom::Status/999999') }
          let(:expected_error_message) { "Status #{old_status_id} is not part of the lifecycle or doesn't exist." }

          it_behaves_like 'lifecycle service returns validation error'
        end

        context 'with non-existing new status' do
          let(:new_status_id) { GlobalID.parse('gid://gitlab/WorkItems::Statuses::Custom::Status/999999') }
          let(:expected_error_message) { "Couldn't find WorkItems::Statuses::Custom::Status with 'id'=999999" }

          it_behaves_like 'lifecycle service returns validation error'
        end
      end

      context 'when multiple mappings are provided' do
        let_it_be(:second_current_status) { create(:work_item_custom_status, namespace: group) }
        let_it_be(:second_target_status) { create(:work_item_custom_status, namespace: group) }

        let(:params) do
          super().merge(
            status_mappings: [
              {
                old_status_id: current_status.to_gid,
                new_status_id: target_status.to_gid
              },
              {
                old_status_id: second_current_status.to_gid,
                new_status_id: second_target_status.to_gid
              }
            ]
          )
        end

        before do
          create(:work_item_custom_lifecycle_status,
            lifecycle: current_lifecycle, status: second_current_status, namespace: group)
          create(:work_item_custom_lifecycle_status,
            lifecycle: target_lifecycle, status: second_target_status, namespace: group)
        end

        it_behaves_like 'work item type successfully attached'

        it 'creates mappings for all provided mappings' do
          expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(2)

          first_mapping, second_mapping = WorkItems::Statuses::Custom::Mapping.last(2)

          expect(first_mapping).to have_attributes(
            namespace_id: group.id,
            work_item_type_id: work_item_type.id,
            old_status_id: current_status.id,
            old_status_role: nil,
            new_status_id: target_status.id,
            valid_from: nil,
            valid_until: nil
          )

          expect(second_mapping).to have_attributes(
            namespace_id: group.id,
            work_item_type_id: work_item_type.id,
            old_status_id: second_current_status.id,
            old_status_role: nil,
            new_status_id: second_target_status.id,
            valid_from: nil,
            valid_until: nil
          )
        end

        context 'and point to the same target status' do
          let(:params) do
            super().merge(
              status_mappings: [
                {
                  old_status_id: current_status.to_gid,
                  new_status_id: target_status.to_gid
                },
                {
                  old_status_id: second_current_status.to_gid,
                  new_status_id: target_status.to_gid
                }
              ]
            )
          end

          it 'creates mappings for all provided mappings' do
            expect { result }.to change { WorkItems::Statuses::Custom::Mapping.count }.by(2)

            first_mapping, second_mapping = WorkItems::Statuses::Custom::Mapping.last(2)

            expect(first_mapping.new_status_id).to eq(target_status.id)
            expect(second_mapping.new_status_id).to eq(target_status.id)
          end
        end

        context 'and one is invalid' do
          let(:params) do
            super().merge(
              status_mappings: [
                {
                  old_status_id: current_status.to_gid,
                  new_status_id: target_status.to_gid
                },
                {
                  old_status_id: second_current_status.to_gid,
                  new_status_id: other_status.to_gid
                }
              ]
            )
          end

          let(:expected_error_message) do
            "Mapping target status '#{other_status.name}' " \
              "does not belong to the target lifecycle"
          end

          it_behaves_like 'lifecycle service returns validation error'

          it 'does not create mappings' do
            expect { result }.not_to change { WorkItems::Statuses::Custom::Mapping.count }
          end
        end
      end

      context 'when mapping statuses belong to different states' do
        let(:params) do
          super().merge(
            status_mappings: [
              {
                old_status_id: current_status.to_gid,
                new_status_id: target_lifecycle.default_closed_status.to_gid
              }
            ]
          )
        end

        let(:expected_error_message) do
          "Mapping statuses '#{current_status.name}' and '#{target_lifecycle.default_closed_status.name}' " \
            "must be of a category of the same state (open/closed)."
        end

        it_behaves_like 'lifecycle service returns validation error'
      end
    end

    context 'when namespace uses system-defined lifecycle' do
      let_it_be(:other_group) { create(:group, :private, maintainers: user) }

      let(:container) { other_group }
      let(:expected_error_message) { 'Work item types can only be attached to custom lifecycles.' }

      it_behaves_like 'lifecycle service returns validation error'
    end

    context 'when target lifecycle is system-defined lifecycle' do
      let(:lifecycle_id) { build(:work_item_system_defined_lifecycle).to_gid }
      let(:expected_error_message) { 'Work item types can only be attached to custom lifecycles.' }

      it_behaves_like 'lifecycle service returns validation error'
    end

    context 'when target lifecycle belongs to different group' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_group) }

      let(:lifecycle_id) { other_lifecycle.to_gid }
      let(:expected_error_message) { "You don't have permission to attach work item types to this lifecycle." }

      it_behaves_like 'lifecycle service returns validation error'
    end

    context 'when work item type does not support the status feature' do
      let(:work_item_type_id) { requirement_work_item_type.to_gid }

      let(:expected_error_message) { "Work item type doesn't support the status widget." }

      it_behaves_like 'lifecycle service returns validation error'
    end

    context 'when lifecycle_id is a self-reference to the current lifecycle' do
      let(:lifecycle_id) { current_lifecycle.to_gid }
      let(:expected_error_message) { "Work item type is already attached to this lifecycle." }

      it_behaves_like 'lifecycle service returns validation error'
    end

    context 'when work item type does not exist' do
      let(:work_item_type_id) { 'gid://gitlab/WorkItems::Type/999999' }
      let(:expected_error_message) { 'Work item type not found.' }

      it_behaves_like 'lifecycle service returns validation error'
    end

    context 'when lifecycle does not exist' do
      let(:lifecycle_id) { 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/999999' }
      let(:expected_error_message) { "Couldn't find WorkItems::Statuses::Custom::Lifecycle with 'id'=999999" }

      it_behaves_like 'lifecycle service returns validation error'
    end
  end
end
