# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics::RequestParams, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group, owners: user) }
  let_it_be(:sub_group) { create(:group, parent: root_group, organization_id: root_group.organization_id) }
  let_it_be(:sub_group_project) { create(:project, namespace: sub_group) }
  let_it_be(:root_group_projects) { Array.new(2) { create(:project, namespace: root_group) } }

  let(:request_params) { described_class.new(params) }
  let(:project_ids) { root_group_projects.collect(&:id) }
  let(:namespace) { root_group }

  subject { request_params }

  context 'when Namespaces::ProjectNamespace is given' do
    it_behaves_like 'unlicensed cycle analytics request params' do
      let(:namespace) { sub_group_project.reload.project_namespace }
    end
  end

  context 'when licensed' do
    let(:params) do
      {
        created_after: '2019-01-01',
        created_before: '2019-03-01',
        project_ids: project_ids,
        namespace: namespace,
        current_user: user,
        weight: 1,
        epic_id: 2,
        iteration_id: 3,
        my_reaction_emoji: 'tumbsup'
      }
    end

    before do
      stub_licensed_features(cycle_analytics_for_groups: true)
    end

    it 'is valid' do
      expect(subject).to be_valid
    end

    describe '#to_data_collector_params' do
      subject(:data_collector_params) { described_class.new(params).to_data_collector_params }

      it 'contains also the licensed filters' do
        expect(data_collector_params.keys).to include(:weight, :epic_id, :iteration_id, :my_reaction_emoji)
      end

      context 'when negated filters are passed' do
        let(:params) do
          {
            created_after: '2019-01-01',
            created_before: '2019-03-01',
            namespace: namespace,
            current_user: user,
            not: {
              weight: 1,
              label_name: 'label',
              assignee_username: 'assignee'
            }
          }
        end

        it 'contains the negated filters' do
          expect(data_collector_params[:not]).to include(:weight, :label_name, :assignee_username)
        end
      end
    end

    describe '#resource_paths' do
      context 'for a group' do
        it 'contains the paths for the namespace' do
          paths = described_class.new(params).resource_paths
          base_path = "/groups/#{root_group.path}/-"

          expect(paths).to match(a_hash_including(
            milestones_path: "#{base_path}/milestones.json",
            labels_path: "#{base_path}/labels.json",
            new_value_stream_path: "#{base_path}/analytics/value_stream_analytics/value_streams/new",
            edit_value_stream_path: "#{base_path}/analytics/value_stream_analytics/value_streams/:id/edit"
          ))
        end
      end

      context 'for a project' do
        let(:params) do
          {
            created_after: '2019-01-01',
            created_before: '2019-03-01',
            namespace: root_group_projects.first.project_namespace,
            current_user: user
          }
        end

        it 'contains the paths for the namespace' do
          paths = described_class.new(params).resource_paths
          base_path = "/#{root_group.path}/#{root_group_projects.first.path}/-"

          expect(paths).to match(a_hash_including(
            milestones_path: "#{base_path}/milestones.json",
            labels_path: "#{base_path}/labels.json",
            new_value_stream_path: "#{base_path}/analytics/value_stream_analytics/value_streams/new",
            edit_value_stream_path: "#{base_path}/analytics/value_stream_analytics/value_streams/:id/edit"
          ))
        end
      end
    end

    describe 'optional `project_ids`' do
      context 'when `project_ids` is not empty' do
        def json_project(project)
          { id: project.to_gid.to_s,
            name: project.name,
            path_with_namespace: project.path_with_namespace,
            avatar_url: project.avatar_url }.to_json
        end

        context 'with a valid group' do
          it { expect(subject.project_ids).to eq(project_ids) }

          it 'contains every project of the group' do
            root_group_projects.each do |project|
              expect(subject.to_data_attributes[:projects]).to include(json_project(project))
            end
          end
        end

        context 'without a valid group' do
          before do
            params[:namespace] = nil
          end

          it { expect(subject.to_data_attributes[:projects]).to be_nil }
        end
      end

      context 'when `project_ids` is not an array' do
        before do
          params[:project_ids] = 1
        end

        it { expect(subject.project_ids).to eq([1]) }
      end

      context 'when `project_ids` is nil' do
        before do
          params[:project_ids] = nil
        end

        it { expect(subject.project_ids).to eq([]) }
      end

      context 'when `project_ids` is empty' do
        before do
          params[:project_ids] = []
        end

        it { expect(subject.project_ids).to eq([]) }
      end

      context 'is a subgroup project' do
        before do
          params[:project_ids] = sub_group_project.id
        end

        it { expect(subject.project_ids).to eq([sub_group_project.id]) }
      end
    end

    describe 'issuable filter params' do
      let_it_be(:stage) { create(:cycle_analytics_stage, namespace: root_group) }

      before do
        params.merge!(
          milestone_title: 'title',
          assignee_username: ['username1'],
          label_name: %w[label1 label2],
          author_username: 'author',
          stage_id: stage.id,
          value_stream: stage.value_stream,
          epic_id: 1,
          iteration_id: 2,
          my_reaction_emoji: AwardEmoji::THUMBS_UP,
          weight: 5
        )
      end

      subject { described_class.new(params).to_data_attributes }

      it "has the correct attributes" do
        expect(subject[:milestone]).to eq('title')
        expect(subject[:assignees]).to eq('["username1"]')
        expect(subject[:labels]).to eq('["label1","label2"]')
        expect(subject[:author]).to eq('author')
        expect(subject[:stage]).to eq(%({"id":#{stage.id},"title":"#{stage.name}"}))
        expect(subject[:epic_id]).to eq(1)
        expect(subject[:iteration_id]).to eq(2)
        expect(subject[:my_reaction_emoji]).to eq(AwardEmoji::THUMBS_UP)
        expect(subject[:weight]).to eq(5)
        expect(subject[:enable_vsd_link]).to eq('true')
      end

      context 'when adding negated filters' do
        it 'has the correct attributes' do
          params.delete(:weight)
          params[:not] = { weight: 3 }

          expect(subject).not_to have_key(:weight)
          expect(subject[:not][:weight]).to eq(3)
        end
      end
    end

    describe 'group-level data attributes' do
      subject(:attributes) { described_class.new(params).to_data_attributes }

      it 'includes the namespace attribute' do
        expect(attributes).to match(hash_including({
          namespace: {
            name: root_group.name,
            rest_api_request_path: "groups/#{root_group.full_path}",
            type: "Group",
            path: root_group.path
          }
        }))
      end

      describe '#to_data_attributes for a subgroup' do
        let(:namespace) { sub_group }

        it 'includes full_path but not path in the group hash' do
          group_attrs = attributes[:group]

          expect(group_attrs).to include(full_path: sub_group.full_path)
          expect(group_attrs).not_to have_key(:path)
        end
      end
    end

    describe 'aggregation params' do
      it 'exposes the aggregation params' do
        data_collector_params = subject.to_data_attributes

        expect(data_collector_params[:aggregation]).to eq({
          enabled: 'true',
          last_run_at: nil,
          next_run_at: nil
        })
      end
    end

    describe 'feature availablity data attributes' do
      subject(:value) { described_class.new(params).to_data_attributes }

      it 'enables all paid features' do
        is_expected.to match(a_hash_including(enable_tasks_by_type_chart: 'true',
          enable_customizable_stages: 'true',
          enable_projects_filter: 'true'))
      end

      context 'when Namespaces::ProjectNamespace is given' do
        before do
          stub_licensed_features(cycle_analytics_for_projects: true, group_level_analytics_dashboard: true)

          # The reload is needed because the project association with inverse_of is not loaded properly
          params[:namespace] = sub_group_project.project_namespace.reload
        end

        it 'disables the task by type chart and the projects filter' do
          is_expected.to match(a_hash_including(enable_tasks_by_type_chart: 'false',
            enable_customizable_stages: 'true',
            enable_projects_filter: 'false'))
        end

        describe 'use_aggregated_data_collector param' do
          subject(:value) { described_class.new(params).to_data_collector_params[:use_aggregated_data_collector] }

          it { is_expected.to be(true) }
        end

        describe 'enable_vsd_link attribute' do
          subject(:value) { described_class.new(params).to_data_attributes[:enable_vsd_link] }

          context "when user has access to the project's group" do
            it { is_expected.to eq('true') }
          end

          context "when user has no access to the project's group" do
            before do
              params[:current_user] = create(:user)
              params[:namespace].project.add_developer(params[:current_user])
            end

            it { is_expected.to eq('false') }
          end
        end
      end
    end
  end
end
