# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFields::UpdateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:custom_field) { create(:custom_field, namespace: group) }

  let(:params) { { name: 'new custom field name' } }
  let(:response) do
    described_class.new(custom_field: custom_field, current_user: user, params: params).execute
  end

  let(:updated_custom_field) { response.payload[:custom_field] }

  before do
    stub_licensed_features(custom_fields: true)
  end

  context 'with valid params' do
    it 'updates the custom field and sets updated_by' do
      expect(response).to be_success
      expect(updated_custom_field).to be_persisted
      expect(updated_custom_field.name).to eq('new custom field name')
      expect(updated_custom_field.updated_by_id).to eq(user.id)
    end
  end

  context 'with select field' do
    let(:custom_field) { create(:custom_field, namespace: group, field_type: 'single_select') }

    context 'when adding select options' do
      let(:params) { { select_options: [{ value: 'option1' }, { value: 'option2' }] } }

      it 'updates the custom field with the options' do
        expect(response).to be_success
        expect(updated_custom_field).to be_persisted
        expect(updated_custom_field.select_options).to match([
          have_attributes(id: a_kind_of(Integer), value: 'option1', position: 0),
          have_attributes(id: a_kind_of(Integer), value: 'option2', position: 1)
        ])
        expect(updated_custom_field.updated_by_id).to eq(user.id)
      end
    end

    context 'with existing select options' do
      let!(:option1) { create(:custom_field_select_option, custom_field: custom_field, position: 0) }
      let!(:option2) { create(:custom_field_select_option, custom_field: custom_field, position: 1) }

      before do
        custom_field.select_options.reload
      end

      context 'when reordering the options' do
        let(:params) { { select_options: [option2.slice(:id, :value), option1.slice(:id, :value)] } }

        it 'updates the positions of the options' do
          expect(response).to be_success
          expect(updated_custom_field).to be_persisted
          expect(updated_custom_field.select_options).to match([
            have_attributes(id: option2.id, position: 0),
            have_attributes(id: option1.id, position: 1)
          ])
          expect(updated_custom_field.updated_by_id).to eq(user.id)
        end
      end

      context 'when select_options param is not provided' do
        let(:params) { { name: 'new field name' } }

        it 'does not remove the select options' do
          expect(response).to be_success
          expect(updated_custom_field).to be_persisted
          expect(updated_custom_field.name).to eq('new field name')
          expect(updated_custom_field.select_options).to match([
            have_attributes(id: option1.id, position: 0),
            have_attributes(id: option2.id, position: 1)
          ])
        end
      end

      context 'when adding and removing options' do
        let(:params) { { select_options: [{ value: 'new option' }, option1.slice(:id, :value)] } }

        it 'updates the options and sets the correct positions' do
          expect(response).to be_success
          expect(updated_custom_field).to be_persisted
          expect(updated_custom_field.select_options).to match([
            have_attributes(id: a_kind_of(Integer), value: 'new option', position: 0),
            have_attributes(id: option1.id, position: 1)
          ])
          expect(updated_custom_field.updated_by_id).to eq(user.id)
          expect(Issuables::CustomFieldSelectOption.exists?(option2.id)).to be(false)
        end
      end

      context 'when given option ID is invalid' do
        let(:other_field_option) { create(:custom_field_select_option) }

        let(:params) { { name: 'new field name', select_options: [{ id: other_field_option.id, value: 'option2' }] } }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to eq("Select option ID #{other_field_option.id} is invalid.")

          expect(custom_field.reload.name).not_to eq('new field name')
        end
      end

      context 'when updated option is invalid' do
        let(:params) { { select_options: [option1.slice(:id, :value), { id: option2.id, value: option1.value }] } }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to include('Select options value has already been taken')
        end
      end
    end
  end

  context 'with work item types' do
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

    context 'when adding work item types' do
      let(:params) { { work_item_type_ids: [task_type.id, issue_type.id] } }

      it 'updates the custom field with the work item types' do
        expect(response).to be_success
        expect(updated_custom_field).to be_persisted
        expect(updated_custom_field.work_item_types).to match([
          have_attributes(id: issue_type.id),
          have_attributes(id: task_type.id)
        ])
        expect(updated_custom_field.updated_by_id).to eq(user.id)
      end

      it 'tracks update_custom_field_in_group_settings event', :clean_gitlab_redis_shared_state do
        expect { response }
          .to trigger_internal_events('update_custom_field_in_group_settings')
          .with(namespace: group, user: user,
            additional_properties: {
              label: custom_field.field_type,
              property: [task_type.id, issue_type.id].sort.join(','),
              field_name: custom_field.name
            })
          .and increment_usage_metrics(
            'counts.count_total_update_custom_field_in_group_settings',
            'counts.count_total_update_custom_field_in_group_settings_weekly',
            'counts.count_total_update_custom_field_in_group_settings_monthly',
            'redis_hll_counters.count_distinct_namespace_id_from_update_custom_field_in_group_settings_weekly',
            'redis_hll_counters.count_distinct_namespace_id_from_update_custom_field_in_group_settings_monthly'
          )
      end

      context 'when a work item type is over the limit' do
        before do
          stub_const('Issuables::CustomField::MAX_ACTIVE_FIELDS_PER_TYPE', 2)

          create_list(:custom_field, 2, namespace: group, work_item_types: [issue_type])
        end

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly(
            "Work item type #{issue_type.name} can only have a maximum of 2 active custom fields."
          )
        end
      end
    end

    context 'with existing work item types' do
      before do
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: issue_type)
      end

      context 'when work_item_type_ids param is not provided' do
        let(:params) { { name: 'new field name' } }

        it 'does not remove the work item types' do
          expect(response).to be_success
          expect(updated_custom_field).to be_persisted
          expect(updated_custom_field.name).to eq('new field name')
          expect(updated_custom_field.reload.work_item_types).to match([
            have_attributes(id: issue_type.id)
          ])
        end

        it 'does not track update_custom_field_in_group_settings event' do
          expect { response }.not_to trigger_internal_events('update_custom_field_in_group_settings')
        end
      end

      context 'when replacing work item types' do
        let(:params) { { work_item_type_ids: [task_type.id] } }

        it 'updates the custom field with the work item types' do
          expect(response).to be_success
          expect(updated_custom_field).to be_persisted
          expect(updated_custom_field.work_item_types).to match([
            have_attributes(id: task_type.id)
          ])
          expect(updated_custom_field.updated_by_id).to eq(user.id)
        end

        it 'tracks update_custom_field_in_group_settings event' do
          expect { response }
            .to trigger_internal_events('update_custom_field_in_group_settings')
            .with(namespace: group, user: user,
              additional_properties: {
                label: custom_field.field_type,
                property: task_type.id.to_s,
                field_name: custom_field.name
              })
        end
      end
    end
  end

  context 'when there are no changes' do
    let(:params) { { name: custom_field.name } }

    it 'does not set updated_by' do
      expect(response).to be_success
      expect(updated_custom_field.updated_by_id).to be_nil
    end
  end

  context 'when user does not have access' do
    let(:user) { create(:user, guest_of: group) }

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to eq(described_class::NotAuthorizedError.message)
    end
  end

  context 'when there are model validation errors' do
    let(:params) { { name: 'a' * 256 } }

    it 'returns the validation error' do
      expect(response).to be_error
      expect(response.message).to include('Name is too long (maximum is 255 characters)')
    end
  end
end
