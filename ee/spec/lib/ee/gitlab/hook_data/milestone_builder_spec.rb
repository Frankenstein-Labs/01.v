# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::HookData::MilestoneBuilder, feature_category: :webhooks do
  let_it_be(:milestone) { create(:milestone) }

  let(:builder) { described_class.new(milestone) }

  describe '.safe_hook_attributes' do
    subject(:safe_attribute_keys) { described_class.safe_hook_attributes }

    it 'includes safe attribute' do
      expected_safe_attribute_keys = %i[
        id
        iid
        title
        description
        state
        created_at
        updated_at
        due_date
        start_date
        project_id
        group_id
      ].freeze

      expect(safe_attribute_keys).to match_array(expected_safe_attribute_keys)
    end
  end
end
