# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Epics::Update, feature_category: :team_planning do
  include GraphqlHelpers
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be_with_reload(:epic) { create(:epic, group: group) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:issue) { create(:issue, project: project) }

  subject(:mutation) { described_class.new(object: group, context: query_context, field: nil) }

  describe '#resolve' do
    subject { mutation.resolve(group_path: group.full_path, iid: epic.iid, title: 'new epic title') }

    context 'when the user is a group member' do
      context 'with guest role' do
        before do
          group.add_guest(current_user)
        end

        it_behaves_like 'epic mutation for user without access'
      end

      context 'with reporter role' do
        before do
          group.add_reporter(current_user)
          stub_licensed_features(epics: true)
        end

        it 'updates the epic' do
          expect(subject[:epic]).to eq(epic)
          expect(epic.reload.title).to eq('new epic title')
          expect(subject[:errors]).to be_empty
        end
      end
    end
  end
end
