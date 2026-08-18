# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of pending promotion members for a group', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:members) do
    create_list(:group_member, 2, group: group, access_level: Gitlab::Access::GUEST)
  end

  let(:parent_key) { "group" }
  let(:parent) { group }

  it_behaves_like 'graphql pending members approval list spec'
end
