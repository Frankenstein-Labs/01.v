# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Boards::Update, feature_category: :planning_views do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:board) { create(:board, project: project, name: 'board name') }
  let_it_be(:label) { create(:label, project: project) }

  let(:mutation) { graphql_mutation(:update_board, params) }

  context 'when both labels and labelIds are given' do
    let(:params) { { id: board.to_global_id.to_s, labels: [label.name], label_ids: [label.to_global_id.to_s] } }

    it_behaves_like 'a mutation that returns top-level errors',
      errors: ['Only one of [labels, labelIds] arguments is allowed at the same time.']
  end
end
