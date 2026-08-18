# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of pending promotion members for a project', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:members) do
    create_list(:project_member, 2, project: project, access_level: Gitlab::Access::GUEST)
  end

  let(:parent_key) { "project" }
  let(:parent) { project }

  it_behaves_like 'graphql pending members approval list spec'
end
