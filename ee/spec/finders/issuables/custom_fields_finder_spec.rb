# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFieldsFinder, feature_category: :team_planning do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let_it_be(:custom_field_1) { create(:custom_field, namespace: group, name: 'ZZZ Field') }
  let_it_be(:custom_field_2) { create(:custom_field, namespace: group, name: 'CCC') }
  let_it_be(:custom_field_archived) { create(:custom_field, :archived, namespace: group, name: 'AAA Field') }
  let_it_be(:other_custom_field) { create(:custom_field, namespace: create(:group), name: 'BBB') }

  let(:current_user) { guest }
  let(:params) { {} }

  subject(:custom_fields) { described_class.new(current_user, group: group, **params).execute }

  before do
    stub_licensed_features(custom_fields: true)
  end

  describe '.active_fields_for_work_item' do
    it 'calls the finder with the correct arguments' do
      work_item = create(:work_item, namespace: create(:group, :private, parent: group))

      expect(described_class).to receive(:new).with(
        nil,
        group: group,
        active: true,
        work_item_type_ids: [work_item.work_item_type_id],
        skip_permissions_check: true
      ).and_call_original

      described_class.active_fields_for_work_item(work_item)
    end
  end

  it 'returns custom fields of the group ordered by status and name' do
    expect(custom_fields).to eq([custom_field_2, custom_field_1, custom_field_archived])
  end

  context 'when filtering by active' do
    context 'when active = true' do
      let(:params) { { active: true } }

      it 'returns active fields only' do
        expect(custom_fields).to contain_exactly(custom_field_1, custom_field_2)
      end
    end

    context 'when active = false' do
      let(:params) { { active: false } }

      it 'returns archived fields only' do
        expect(custom_fields).to contain_exactly(custom_field_archived)
      end
    end
  end

  context 'when filtering by search term' do
    let(:params) { { search: 'field' } }

    it 'returns fields with matching name' do
      expect(custom_fields).to contain_exactly(custom_field_1, custom_field_archived)
    end
  end

  context 'when filtering by work item types' do
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

    before_all do
      create(:work_item_type_custom_field, custom_field: custom_field_1, work_item_type: issue_type)
      create(:work_item_type_custom_field, custom_field: custom_field_1, work_item_type: task_type)

      create(:work_item_type_custom_field, custom_field: custom_field_2, work_item_type: issue_type)
    end

    context 'with a single work item type ID' do
      let(:params) { { work_item_type_ids: [issue_type.id] } }

      it 'returns custom fields with matching work item type' do
        expect(custom_fields).to contain_exactly(custom_field_1, custom_field_2)
      end
    end

    context 'with multiple work item type IDs' do
      let(:params) { { work_item_type_ids: [issue_type.id, task_type.id] } }

      it 'returns custom fields that match any of the work item types' do
        expect(custom_fields).to contain_exactly(custom_field_1, custom_field_2)
      end
    end

    context 'with an empty array' do
      let(:params) { { work_item_type_ids: [] } }

      it 'returns custom fields that are not associated with any work item type' do
        expect(custom_fields).to contain_exactly(custom_field_archived)
      end
    end

    context 'with a converted custom work item type' do
      let_it_be(:converted_custom_type) do
        create(:work_item_custom_type, :converted_from_issue, namespace: group)
      end

      let_it_be(:custom_field_for_converted_type) do
        create(:custom_field, namespace: group, name: 'Converted Type Field')
      end

      before_all do
        create(
          :work_item_type_custom_field,
          custom_field: custom_field_for_converted_type,
          work_item_type_id: converted_custom_type.converted_from_system_defined_type_identifier,
          namespace: group
        )
      end

      it 'returns custom fields when querying by converted_from_system_defined_type_identifier' do
        params = { work_item_type_ids: [converted_custom_type.converted_from_system_defined_type_identifier] }
        result = described_class.new(current_user, group: group, **params).execute

        expect(result).to include(custom_field_for_converted_type)
      end

      it 'does not return custom fields when querying by the custom type AR id' do
        params = { work_item_type_ids: [converted_custom_type.id] }
        result = described_class.new(current_user, group: group, **params).execute

        expect(result).not_to include(custom_field_for_converted_type)
      end
    end
  end

  context "when filtering by field type" do
    let_it_be(:custom_field_number) { create(:custom_field, :number, namespace: group, name: 'number field') }

    context "when field type is nil" do
      let(:params) { {} }

      it 'returns all custom fields for the group' do
        expect(custom_fields).to contain_exactly(custom_field_1, custom_field_2, custom_field_archived,
          custom_field_number)
      end
    end

    context "when field is has a value" do
      let(:params) { { field_type: "number" } }

      it 'returns custom fields of type number' do
        expect(custom_fields).to contain_exactly(custom_field_number)
      end
    end
  end

  context 'when group is nil' do
    let(:group) { nil }

    it 'raises an exception' do
      expect { custom_fields }.to raise_error('group argument is missing')
    end
  end

  context 'when user does not have access' do
    let(:current_user) { create(:user) }

    it 'returns an empty result' do
      expect(custom_fields).to be_empty
    end
  end

  context 'when skip_permissions_check is true' do
    let(:current_user) { nil }
    let(:params) { { skip_permissions_check: true } }

    it 'returns custom fields regardless of user access' do
      expect(custom_fields).to eq([custom_field_2, custom_field_1, custom_field_archived])
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(custom_fields: false)
      end

      it 'returns an empty result' do
        expect(custom_fields).to be_empty
      end
    end
  end

  context 'when feature is not available' do
    before do
      stub_licensed_features(custom_fields: false)
    end

    it 'returns an empty result' do
      expect(custom_fields).to be_empty
    end
  end
end
