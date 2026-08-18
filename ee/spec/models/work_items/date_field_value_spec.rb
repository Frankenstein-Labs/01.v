# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DateFieldValue, feature_category: :team_planning do
  subject(:date_field_value) { build(:work_item_date_field_value) }

  it_behaves_like 'a work item custom field value', factory: :work_item_date_field_value

  describe 'validations' do
    it { is_expected.to validate_presence_of(:value) }

    it 'validates uniqueness of custom_field and work item' do
      # Prevent errors when validate_uniqueness_of creates duplicate records without going through our model hooks
      date_field_value.namespace = create(:group)

      is_expected.to validate_uniqueness_of(:custom_field).scoped_to(:work_item_id)
    end
  end
end
