# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::MembersTypeCombinator, feature_category: :system_access do
  include_context 'with group members shared context'

  let(:requested_group) { sub_sub_sub_group_1 }
  let(:group_members) do
    [shared_maintainer_5, shared_maintainer_6]
  end

  let(:inherited_members) do
    [group_owner_1, sub_group_1_owner_2, group_developer_3, sub_sub_group_owner_4, sub_sub_group_owner_5]
  end

  subject(:process_group) { described_class.new(requested_group).execute(group_members, inherited_members) }

  it 'returns the members with the higher access level' do
    expected_result = [group_owner_1, sub_group_1_owner_2, group_developer_3, sub_sub_group_owner_4,
      sub_sub_group_owner_5, shared_maintainer_6]

    expect(process_group).to match_array(expected_result)
  end
end
