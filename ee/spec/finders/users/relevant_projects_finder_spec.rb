# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::RelevantProjectsFinder, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  # projects that may be included in the results
  let_it_be(:public_project_1) do
    group = create(:group, :public)
    create(:project, :public, group: group, path: 'gitlab', name: 'Gitlab')
  end

  let_it_be(:public_project_2) do
    group = create(:group, :public)
    create(:project, :public, group: group, path: 'gitlab-docs', name: 'Documentation Project')
  end

  let_it_be(:authorized_project_1) do
    group = create(:group, developers: [user])
    create(:project, developers: [:user], group: group, path: 'gitlab-aigw', name: 'Gitlab AIGW')
  end

  let_it_be(:authorized_project_2) do
    group = create(:group, developers: [user])
    create(:project, developers: [:user], group: group, path: 'test-project', name: 'Test Project')
  end
  # end setup projects that may be included in the results

  # projects that are always excluded from the results
  let_it_be(:archived_project) { create(:project, :archived, developers: [:user]) }
  let_it_be(:hidden_project) { create(:project, :hidden, developers: [:user]) }
  let_it_be(:pending_delete_project) { create(:project, pending_delete: true, developers: [:user]) }
  let_it_be(:other_user_project) { create(:project, developers: [create(:user)]) }
  let_it_be(:public_forked_project) do
    create(:project, :public).tap do |forked_project|
      fork_network = create(:fork_network, root_project: public_project_1)
      create(:fork_network_member, project: forked_project, fork_network: fork_network)
    end
  end
  # end setup projects that are always excluded from the results

  let(:params) { {} }

  let(:finder) { described_class.new(user, params: params) }

  subject(:results) { finder.execute.all }

  it 'returns authorized project' do
    expect(results).to eq([authorized_project_2, authorized_project_1])
  end

  context 'when user is nil' do
    let(:finder) { described_class.new(nil, params: params) }

    it { is_expected.to be_empty }
  end

  context 'when include_public=true' do
    let(:params) { { include_public: true } }

    it 'returns author projects and public non-forked project' do
      expect(results).to eq([
        authorized_project_2,
        authorized_project_1,
        public_project_2,
        public_project_1
      ])
    end
  end

  context 'when namespace_ai_feature is set' do
    let(:params) do
      {
        namespace_ai_feature: :ai_features, # `:ai_features` is under ULTIMATE plans
        include_public: true
      }
    end

    context 'when on saas', :saas do
      before do
        create(:gitlab_subscription, :free, namespace: public_project_1.group)
        create(:gitlab_subscription, :gold, namespace: public_project_2.group)
        create(:gitlab_subscription, :bronze, namespace: authorized_project_1.group)
        create(:gitlab_subscription, :ultimate, namespace: authorized_project_2.group)
      end

      it 'filters on projects under namespaces with AI-supported plans' do
        expect(results).to eq([authorized_project_2, public_project_2])
      end

      context 'when namespace_ai_feature param is not provided' do
        let(:params) { { include_public: true } }

        it "does not filter based on the projects' namespace's plans" do
          expect(results).to eq([
            authorized_project_2,
            authorized_project_1,
            public_project_2,
            public_project_1
          ])
        end
      end
    end

    context 'when not on saas' do
      it "does not filter based on the projects' namespace's plans" do
        expect(::Namespace).not_to receive(:with_ai_supported_plan)

        expect(results).to eq([
          authorized_project_2,
          authorized_project_1,
          public_project_2,
          public_project_1
        ])
      end
    end
  end

  context 'when search term is given' do
    let(:params) { { search: 'gitlab', include_public: true } }

    it 'filters on search term and sorts by similarity' do
      expect(results).to eq([
        public_project_1,
        authorized_project_1,
        public_project_2
      ])
    end

    context 'when search term length is less than 3' do
      let(:params) { { search: 'gi', include_public: true } }

      it { is_expected.to be_empty }
    end
  end

  describe 'relevance_category options' do
    context 'when relevance_category=:recently_contributed', :freeze_time do
      before do
        create(:event, :pushed, project: public_project_1, author: user, created_at: 2.months.ago)
        create(:event, :pushed, project: public_project_2, author: user, created_at: 2.weeks.ago)
        create(:event, :pushed, project: authorized_project_2, author: user, created_at: 1.week.ago)
        create(:event, :pushed, project: authorized_project_1, author: user, created_at: 1.day.ago)
      end

      let(:params) { { relevance_category: :recently_contributed, include_public: true } }

      it 'filters to user-contributed projects in the last month, ordered by latest contributed' do
        expect(results).to eq([
          authorized_project_1,
          authorized_project_2,
          public_project_2
        ])
      end

      context 'when search term is given' do
        let(:params) { { relevance_category: :recently_contributed, include_public: true, search: 'gitlab' } }

        it 'filters on search term and sorts by similarity' do
          expect(results).to eq([
            authorized_project_1,
            public_project_2
          ])
        end
      end
    end

    context 'when relevance_category=:recently_visited' do
      before do
        create(:project_visit, target_project: public_project_1, target_user: user, visited_at: 2.months.ago)
        create(:project_visit, target_project: public_project_2, target_user: user, visited_at: 2.weeks.ago)
        create(:project_visit, target_project: authorized_project_2, target_user: user, visited_at: 1.week.ago)
        create(:project_visit, target_project: authorized_project_1, target_user: user, visited_at: 1.day.ago)
      end

      let(:params) { { relevance_category: :recently_visited, include_public: true } }

      it 'filters to user-visited projects in the last month, ordered by latest visited' do
        expect(results).to eq([
          authorized_project_1,
          authorized_project_2,
          public_project_2
        ])
      end

      context 'when search term is given' do
        let(:params) { { relevance_category: :recently_visited, include_public: true, search: 'gitlab' } }

        it 'filters on search term and sorts by similarity' do
          expect(results).to eq([
            authorized_project_1,
            public_project_2
          ])
        end
      end
    end

    context 'when relevance_category is unexpected' do
      before do
        create(:project_visit, target_project: public_project_1, target_user: user, visited_at: 3.weeks.ago)
        create(:project_visit, target_project: public_project_2, target_user: user, visited_at: 2.weeks.ago)
        create(:event, :pushed, project: authorized_project_2, author: user, created_at: 1.week.ago)
        create(:event, :pushed, project: authorized_project_1, author: user, created_at: 1.day.ago)
      end

      let(:params) { { relevance_category: :starred, include_public: true } }

      it 'returns an empty project list' do
        expect(results).to be_empty
      end
    end
  end
end
