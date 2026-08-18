# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::CodeSuggestionUsageService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(
      current_user,
      namespace: container,
      from: from,
      to: to,
      languages: languages,
      ide_names: ide_names
    ).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:project_namespace) { project.reload.project_namespace }
  let_it_be(:user1) { create(:user, developer_of: group) }
  let_it_be(:user2) { create(:user, developer_of: subgroup) }
  let_it_be(:user3) { create(:user, developer_of: group) }
  let_it_be(:not_member) { create(:user) }
  let(:languages) { [] }
  let(:ide_names) { [] }

  let(:current_user) { user1 }
  let(:from) { Time.current }
  let(:to) { Time.current }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'common ai usage rate service' do
    # This shared examples requires the following variables
    # :expected_results
    # :expected_language_filtered_results

    context 'when the clickhouse is not available for analytics' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(container).and_return(false)
      end

      it 'returns service error' do
        expect(service_response).to be_error

        message = s_('AiAnalytics|the ClickHouse data store is not available')
        expect(service_response.message).to eq(message)
      end
    end

    context 'when the feature is available', :click_house, :freeze_time do
      let(:from) { 14.days.ago }
      let(:to) { 1.day.ago }

      context 'without data' do
        it 'returns 0' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq({
            code_contributors_count: 0,
            code_suggestions_contributors_count: 0,
            code_suggestions_accepted_count: 0,
            code_suggestions_shown_count: 0,
            # New fields
            accepted_count: 0,
            accepted_lines_of_code: 0,
            contributors_count: 0,
            ide_names: [],
            languages: [],
            shown_count: 0,
            shown_lines_of_code: 0
          })
        end
      end

      context 'with only few fields selected' do
        it 'returns only selected fields' do
          response = described_class.new(current_user,
            namespace: container,
            from: from,
            to: to,
            fields: %i[code_contributors_count foo]).execute

          expect(response.payload).to match(code_contributors_count: 0)
        end
      end

      context 'with no selected fields' do
        it 'returns empty stats hash' do
          response = described_class.new(current_user,
            namespace: container,
            from: from,
            to: to,
            fields: []).execute

          expect(response).to be_success
          expect(response.payload).to eq({})
        end
      end

      context 'with data' do
        before do
          clickhouse_fixture(:ai_usage_events, [
            # shown
            { user_id: user1.id, namespace_path: group.traversal_path(with_organization: false), event: 2,
              extras: { language: 'ruby', ide_name: 'ide_1', suggestion_size: 10 }, timestamp: to - 3.days },
            # accepted
            { user_id: user1.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 3,
              extras: { language: 'ruby', ide_name: 'ide_2', suggestion_size: 20 }, timestamp: to - 3.days + 1.second },
            # shown
            { user_id: user1.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 2,
              extras: { language: 'ruby', ide_name: 'ide_3', suggestion_size: 30 }, timestamp: to - 4.days },
            # shown
            { user_id: user2.id, namespace_path: subgroup.traversal_path(with_organization: false), event: 2,
              extras: { language: 'js', ide_name: 'ide_3', suggestion_size: 40 }, timestamp: to - 2.days },
            # shown
            { user_id: user2.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 2,
              extras: { language: 'rust', suggestion_size: 50 }, timestamp: to - 2.days },
            # shown
            { user_id: not_member.id, namespace_path: group.traversal_path(with_organization: false), event: 2,
              extras: { language: 'c++', suggestion_size: 60 }, timestamp: to - 2.days },
            # accepted
            { user_id: not_member.id, namespace_path: group.traversal_path(with_organization: false), event: 3,
              extras: { language: 'c', suggestion_size: 70 }, timestamp: to - 2.days + 1.second },
            # shown
            # Out of timeframe
            { user_id: user3.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 2,
              extras: { language: 'perl', suggestion_size: 80 }, timestamp: to + 2.days },
            # shown
            # Out of timeframe
            { user_id: user3.id, namespace_path: subgroup.traversal_path(with_organization: false), event: 2,
              extras: { language: 'php', suggestion_size: 90 }, timestamp: from - 2.days },
            # non-CS event
            { user_id: user2.id, namespace_path: project_namespace.traversal_path(with_organization: false), event: 6,
              extras: { language: 'rust', suggestion_size: 50 }, timestamp: to - 2.days }
          ])

          insert_events_into_click_house([
            build_stubbed(:event, :pushed, project: project, author: user1, created_at: to - 1.day),
            build_stubbed(:event, :pushed, project: project, author: user1, created_at: to - 2.days),
            build_stubbed(:event, :pushed, project: project, author: user2, created_at: to - 1.day),
            build_stubbed(:event, :pushed, project: project, author: user3, created_at: to - 1.day)
          ])
        end

        it 'returns matched code contributors AI usage stats' do
          expect(service_response).to be_success
          expect(service_response.payload).to match(expected_results)
        end

        context 'when using languages filter' do
          let(:languages) { %w[js rust] }

          it 'returns metrics filtered by languages used' do
            expect(service_response.payload).to match(expected_language_filtered_results)
          end
        end

        context 'when using IDE names filter' do
          let(:ide_names) { %w[ide_2 ide_3] }

          it 'returns metrics filtered by IDEs used' do
            expect(service_response.payload).to match(expected_ide_filtered_results)
          end
        end
      end
    end
  end

  context 'for group' do
    let_it_be(:container) { group }

    let(:expected_results) do
      {
        contributors_count: 3,
        code_contributors_count: 3,
        code_suggestions_contributors_count: 3,
        code_suggestions_accepted_count: 2,
        code_suggestions_shown_count: 5,
        shown_count: 5,
        accepted_count: 2,
        ide_names: contain_exactly("", "ide_3", "ide_2", "ide_1"),
        languages: contain_exactly("c", "js", "c++", "rust", "ruby"),
        shown_lines_of_code: 190,
        accepted_lines_of_code: 90
      }
    end

    let(:expected_language_filtered_results) do
      {
        code_contributors_count: 3,
        code_suggestions_contributors_count: 3,
        code_suggestions_accepted_count: 2,
        code_suggestions_shown_count: 5,
        contributors_count: 1,
        shown_count: 2,
        accepted_count: 0,
        ide_names: contain_exactly("", "ide_3"),
        languages: contain_exactly("js", "rust"),
        shown_lines_of_code: 90,
        accepted_lines_of_code: 0
      }
    end

    let(:expected_ide_filtered_results) do
      {
        code_contributors_count: 3,
        code_suggestions_contributors_count: 3,
        code_suggestions_accepted_count: 2,
        code_suggestions_shown_count: 5,
        contributors_count: 2,
        shown_count: 2,
        accepted_count: 1,
        ide_names: contain_exactly("ide_3", "ide_2"),
        languages: contain_exactly("js", "ruby"),
        shown_lines_of_code: 70,
        accepted_lines_of_code: 20
      }
    end

    it_behaves_like 'common ai usage rate service'
  end

  context 'for project' do
    let_it_be(:container) { project.project_namespace.reload }

    let(:expected_results) do
      {
        code_contributors_count: 3,
        code_suggestions_contributors_count: 2,
        code_suggestions_accepted_count: 1,
        code_suggestions_shown_count: 2,
        contributors_count: 2,
        shown_count: 2,
        accepted_count: 1,
        ide_names: contain_exactly("", "ide_3", "ide_2"),
        languages: contain_exactly("rust", "ruby"),
        shown_lines_of_code: 80,
        accepted_lines_of_code: 20
      }
    end

    let(:expected_language_filtered_results) do
      {
        code_contributors_count: 3,
        code_suggestions_contributors_count: 2,
        code_suggestions_accepted_count: 1,
        code_suggestions_shown_count: 2,
        contributors_count: 1,
        shown_count: 1,
        accepted_count: 0,
        ide_names: [""],
        languages: %w[rust],
        shown_lines_of_code: 50,
        accepted_lines_of_code: 0
      }
    end

    let(:expected_ide_filtered_results) do
      {
        code_contributors_count: 3,
        code_suggestions_contributors_count: 2,
        code_suggestions_accepted_count: 1,
        code_suggestions_shown_count: 2,
        contributors_count: 1,
        shown_count: 1,
        accepted_count: 1,
        ide_names: contain_exactly("ide_3", "ide_2"),
        languages: %w[ruby],
        shown_lines_of_code: 30,
        accepted_lines_of_code: 20
      }
    end

    it_behaves_like 'common ai usage rate service'
  end
end
