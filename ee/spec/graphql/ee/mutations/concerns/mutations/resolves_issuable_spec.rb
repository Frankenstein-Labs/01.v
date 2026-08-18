# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ResolvesIssuable, feature_category: :portfolio_management do
  let_it_be(:mutation_class) do
    Class.new(Mutations::BaseMutation) do
      include Mutations::ResolvesIssuable
    end
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:epic) { create(:epic, group: group) }

  let(:mutation) { mutation_class.new(object: nil, context: query_context, field: nil) }

  context 'with epics' do
    let(:parent)   { issuable.group }
    let(:issuable) { epic }

    before do
      stub_licensed_features(epics: true)
    end

    it_behaves_like 'resolving an issuable in GraphQL', :epic
  end
end
