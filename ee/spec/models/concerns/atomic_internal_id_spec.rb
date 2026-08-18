# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AtomicInternalId, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }

  context 'when multiple models share the same usage' do
    # we have Epic, Issue and WorkItem models share the same usage type: :issues
    # so we check that iid is incremented when instances of any of the 2 models are created.
    it 'increments the iid on any model using the share usage' do
      issue = build(:issue, :group_level, namespace: group)
      epic = build(:epic, group: group)
      work_item = build(:work_item, :group_level, namespace: group)

      expect { issue.save! }.to change {
        InternalId.find_by(namespace: group, usage: :issues)&.last_value
      }.from(nil).to(1)

      # saving an epic updates the same internal_ids record as for the group level issue
      expect { epic.save! }.to change {
        InternalId.find_by(namespace: group, usage: :issues)&.last_value
      }.from(1).to(3)

      expect { work_item.save! }.to change {
        InternalId.find_by(namespace: group, usage: :issues)&.last_value
      }.from(3).to(4)
    end
  end
end
