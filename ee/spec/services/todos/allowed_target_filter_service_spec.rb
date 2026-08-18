# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Todos::AllowedTargetFilterService, feature_category: :team_planning do
  let_it_be(:authorized_group) { create(:group, :private) }
  let_it_be(:authorized_project) { create(:project, group: authorized_group) }
  let_it_be(:unauthorized_group) { create(:group, :private) }
  let_it_be(:unauthorized_project) { create(:project, group: unauthorized_group) }
  let_it_be(:authorized_epic) { create(:epic, group: authorized_group) }
  let_it_be(:unauthorized_epic) { create(:epic, group: unauthorized_group) }

  let_it_be_with_reload(:user) { create(:user, developer_of: authorized_group) }

  let_it_be(:authorized_epic_todo) do
    create(:todo, group: authorized_group, project: authorized_project, target: authorized_epic, user: user)
  end

  let_it_be(:unauthorized_epic_todo) do
    create(:todo, group: unauthorized_group, project: unauthorized_project, target: unauthorized_epic, user: user)
  end

  describe '#execute' do
    subject(:execute_service) { described_class.new(Todo.all, user).execute }

    let(:authorized_todos) do
      [
        authorized_epic_todo
      ]
    end

    let(:unauthorized_todos) do
      [
        unauthorized_epic_todo
      ]
    end

    before do
      stub_licensed_features(epics: true)
    end

    it { is_expected.to match_array(authorized_todos) }

    describe 'namespace bans' do
      let_it_be(:authorized_issue) { create(:issue, project: authorized_project) }

      let_it_be(:authorized_issue_todo) do
        create(:todo, project: authorized_project, target: authorized_issue, user: user)
      end

      before do
        stub_licensed_features(unique_project_download_limit: true)
      end

      it { is_expected.to match_array([authorized_issue_todo]) }

      context 'when user is banned from the todo target\'s project\'s top-level group' do
        let_it_be(:ban) { create(:namespace_ban, user: user, namespace: authorized_group) }

        it { is_expected.to match_array([]) }
      end
    end
  end
end
