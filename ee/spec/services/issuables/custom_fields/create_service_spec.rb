# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFields::CreateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:params) { { name: 'my custom field', field_type: 'text' } }
  let(:response) { described_class.new(group: group, current_user: user, params: params).execute }
  let(:custom_field) { response.payload[:custom_field] }

  before do
    stub_licensed_features(custom_fields: true)
  end

  context 'with valid params' do
    it 'creates a custom field and sets created_by' do
      expect(response).to be_success
      expect(custom_field).to be_persisted
      expect(custom_field.name).to eq('my custom field')
      expect(custom_field.field_type).to eq('text')
      expect(custom_field.created_by_id).to eq(user.id)
    end

    it "triggers an internal event" do
      expect do
        response.payload[:custom_field]
      end.to trigger_internal_events('create_custom_field_in_group_settings').with(
        namespace: group,
        user: user,
        additional_properties: { label: params[:field_type], property: '', field_name: params[:name] }
      )
    end

    it 'does not track update_custom_field_in_group_settings event' do
      expect { response }.not_to trigger_internal_events('update_custom_field_in_group_settings')
    end

    context 'when setting select options' do
      let(:params) do
        {
          name: 'my custom field',
          field_type: 'single_select',
          select_options: [
            { value: 'option1' },
            { value: 'option2' }
          ]
        }
      end

      it 'creates the custom field with the options' do
        expect(response).to be_success
        expect(custom_field).to be_persisted
        expect(custom_field.select_options).to match([
          have_attributes(id: a_kind_of(Integer), value: 'option1', position: 0),
          have_attributes(id: a_kind_of(Integer), value: 'option2', position: 1)
        ])
      end

      context 'when there are duplicate options' do
        let(:params) do
          {
            name: 'my custom field',
            field_type: 'single_select',
            select_options: [
              { value: 'option1' },
              { value: 'option1' }
            ]
          }
        end

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly('Select options value has already been taken')
        end
      end
    end

    context 'when setting work item types' do
      let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
      let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

      let(:params) do
        {
          name: 'my custom field',
          field_type: 'single_select',
          work_item_type_ids: [
            task_type.id,
            issue_type.id
          ]
        }
      end

      it 'creates the custom field and associates with the work item types' do
        expect(response).to be_success
        expect(custom_field).to be_persisted
        expect(custom_field.work_item_types).to match([
          have_attributes(id: issue_type.id),
          have_attributes(id: task_type.id)
        ])
      end

      it 'tracks create event with work_item_type_ids in property' do
        expect { response }
          .to trigger_internal_events('create_custom_field_in_group_settings')
          .with(namespace: group, user: user,
            additional_properties: {
              label: 'single_select',
              property: [issue_type.id, task_type.id].sort.join(','),
              field_name: 'my custom field'
            })
      end

      it 'does not track update_custom_field_in_group_settings event' do
        expect { response }.not_to trigger_internal_events('update_custom_field_in_group_settings')
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
  end

  context 'when user does not have access' do
    let(:user) { create(:user, guest_of: group) }

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to eq(described_class::NotAuthorizedError.message)
    end
  end

  context 'when there are model validation errors' do
    let(:params) { { name: 'a' * 256, field_type: 'text' } }

    it 'returns the validation error' do
      expect(response).to be_error
      expect(response.message).to include('Name is too long (maximum is 255 characters)')
    end
  end

  context 'when select option is invalid' do
    let(:params) do
      { name: 'Select field', field_type: 'single_select', select_options: [{ value: 'a' * 256 }] }
    end

    it 'returns the validation error' do
      expect(response).to be_error
      expect(response.message).to include('Select options value is too long (maximum is 255 characters)')
    end
  end
end
