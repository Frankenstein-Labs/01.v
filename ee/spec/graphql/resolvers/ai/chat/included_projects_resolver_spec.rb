# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Chat::IncludedProjectsResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let_it_be(:public_visited_project) do
    group = create(:group, :public)
    project = create(:project, :public, group: group, path: 'gitlab', name: 'Gitlab')
    create(:project_visit, target_project: project, target_user: current_user, visited_at: 1.week.ago)
    project
  end

  let_it_be(:public_contributed_project) do
    group = create(:group, :public)
    project = create(:project, :public, group: group, path: 'gitlab-docs', name: 'Gitlab Docs')
    create(:event, :pushed, project: project, author: current_user, created_at: 1.week.ago)
    project
  end

  let_it_be(:authorized_project) do
    group = create(:group, developers: [current_user])
    create(:project, developers: [:user], group: group, path: 'gitlab-handbook', name: 'Gitlab Handbook')
  end

  let_it_be(:authorized_visited_project) do
    group = create(:group, developers: [current_user])
    project = create(:project, developers: [:user], group: group, path: 'gitlab-lsp', name: 'Language Server')
    create(:project_visit, target_project: project, target_user: current_user, visited_at: 1.day.ago)
    project
  end

  let_it_be(:authorized_contributed_project) do
    group = create(:group, developers: [current_user])
    project = create(:project, developers: [:user], group: group, path: 'gitlab-aigw', name: 'AI Gateway')
    create(:event, :pushed, project: project, author: current_user, created_at: 1.day.ago)
    project
  end

  # projects that are always excluded from the results
  let_it_be(:archived_project) { create(:project, :archived, developers: [:current_user]) }
  let_it_be(:other_user_project) { create(:project, developers: [create(:user)]) }
  let_it_be(:public_unseen_project) { create(:project, :public) }
  let_it_be(:public_forked_project) do
    create(:project, :public).tap do |forked_project|
      fork_network = create(:fork_network, root_project: public_visited_project)
      create(:fork_network_member, project: forked_project, fork_network: fork_network)
    end
  end
  # end setup projects that are always excluded from the results

  describe '#resolve' do
    let(:args) { {} }

    subject(:result) { resolve(described_class, obj: nil, args: args, ctx: { current_user: current_user }).items }

    it 'returns the projects sorted by relevance category' do
      expect(result).to eq([
        authorized_contributed_project,
        public_contributed_project,
        authorized_visited_project,
        public_visited_project,
        authorized_project
      ])
    end

    context 'when search term is given' do
      let(:args) { { search: 'gitlab' } }

      it 'returns the projects sorted by relevance category and similarity' do
        expect(result).to eq([
          public_contributed_project,
          authorized_contributed_project,
          public_visited_project,
          authorized_visited_project,
          authorized_project
        ])
      end
    end

    context 'when found results are greater than maximum required results count' do
      before do
        stub_const("#{described_class}::MAX_RESULTS_COUNT", 3)
      end

      it 'returns projects up to the maximum required count' do
        expect(result).to eq([
          authorized_contributed_project,
          public_contributed_project,
          authorized_visited_project
        ])
      end
    end

    context 'when on saas', :saas do
      before do
        create(:gitlab_subscription, :gold, namespace: public_visited_project.group)
        create(:gitlab_subscription, :bronze, namespace: authorized_visited_project.group)
        create(:gitlab_subscription, :premium, namespace: authorized_contributed_project.group)
        create(:gitlab_subscription, :ultimate, namespace: authorized_project.group)
      end

      it 'returns projects under namespaces with AI-supported plans' do
        expect(result).to eq([
          authorized_contributed_project,
          public_visited_project,
          authorized_project
        ])
      end
    end
  end
end
