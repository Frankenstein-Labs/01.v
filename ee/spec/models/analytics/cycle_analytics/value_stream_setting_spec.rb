# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ValueStreamSetting, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:value_stream_setting) { create(:cycle_analytics_value_stream_setting) }

  describe 'associations' do
    it { is_expected.to belong_to(:value_stream) }
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    it do
      is_expected.not_to allow_value(Array.new(described_class::MAX_PROJECT_IDS_FILTER + 1, 1))
        .for(:project_ids_filter)
        .with_message('Maximum projects allowed in the filter is 100')
    end

    it { is_expected.to allow_value(Array.new(described_class::MAX_PROJECT_IDS_FILTER, 1)).for(:project_ids_filter) }

    context 'for project_ids_filter' do
      let(:value_stream_setting) do
        build(
          :cycle_analytics_value_stream_setting,
          value_stream: value_stream,
          project_ids_filter: [1]
        )
      end

      context 'when value stream belongs to a project' do
        let_it_be(:value_stream) do
          create(:cycle_analytics_value_stream, namespace: create(:project).project_namespace)
        end

        it 'is invalid' do
          expect(value_stream_setting).not_to be_valid
          expect(value_stream_setting.errors[:project_ids_filter])
            .to include('Can only be present for group level value streams')
        end
      end

      context 'when value stream belongs to a group' do
        let_it_be(:value_stream) do
          create(:cycle_analytics_value_stream, namespace: group)
        end

        it 'is valid' do
          expect(value_stream_setting).to be_valid
        end

        context 'and has ids from projects outside group hierarchy' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:group_project) { create(:project, group: group) }
          let_it_be(:subgroup_project) { create(:project, group: subgroup) }
          let_it_be(:outsider_project) { create(:project) }

          let(:ids) { [group_project, subgroup_project, outsider_project].map(&:id) }

          it 'returns ids only from projects in the hierarchy' do
            value_stream_setting.update!(project_ids_filter: ids)

            expect(value_stream_setting.project_ids_filter).to match_array([group_project.id, subgroup_project.id])
          end
        end
      end
    end
  end
end
