# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ProjectMemberBulkUpdate', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :project_member_bulk_update }

  context 'with promotion management feature' do
    let_it_be_with_refind(:source) { create(:project) }
    let(:source_id_key) { 'project_id' }
    let(:response_member_field) { "projectMembers" }

    it_behaves_like 'promotion management for members bulk update'
  end
end
