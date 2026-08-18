# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Filters, :elastic_helpers, feature_category: :global_search do
  include_context 'with filters shared context'
  let_it_be_with_reload(:user) { create(:user) }

  describe '.by_source_branch' do
    subject(:by_source_branch) { described_class.by_source_branch(query_hash: query_hash, options: options) }

    context 'when options[:source_branch] and options[:not_source_branch] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:source_branch] and options[:not_source_branch] are both provided' do
      let(:options) { { source_branch: 'branch-1', not_source_branch: 'branch-2' } }
      let(:expected_filter) do
        [
          { bool:
            { should: [{ term: { source_branch: { _name: 'filters:source_branch', value: 'branch-1' } } },
              { bool: {
                must_not: {
                  term: { source_branch: { _name: 'filters:not_source_branch', value: 'branch-2' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:source_branch] is provided' do
      let(:options) { { source_branch: 'foo-bar-branch' } }
      let(:expected_filter) do
        [
          { bool:
            { should: [{ term: { source_branch: { _name: 'filters:source_branch', value: 'foo-bar-branch' } } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_source_branch] is provided' do
      let(:options) { { not_source_branch: 'hello-branch' } }
      let(:expected_filter) do
        [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { source_branch: { _name: 'filters:not_source_branch', value: 'hello-branch' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_target_branch' do
    subject(:by_target_branch) { described_class.by_target_branch(query_hash: query_hash, options: options) }

    context 'when options[:target_branch] and options[:not_target_branch] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:target_branch] and options[:not_target_branch] are both provided' do
      let(:options) { { target_branch: 'branch-1', not_target_branch: 'branch-2' } }
      let(:expected_filter) do
        [
          { bool:
            { should: [{ term: { target_branch: { _name: 'filters:target_branch', value: 'branch-1' } } },
              { bool: {
                must_not: {
                  term: { target_branch: { _name: 'filters:not_target_branch', value: 'branch-2' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:target_branch] is provided' do
      let(:options) { { target_branch: 'foo-bar-branch' } }
      let(:expected_filter) do
        [
          { bool:
            { should: [{ term: { target_branch: { _name: 'filters:target_branch', value: 'foo-bar-branch' } } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_target_branch] is provided' do
      let(:options) { { not_target_branch: 'hello-branch' } }
      let(:expected_filter) do
        [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { target_branch: { _name: 'filters:not_target_branch', value: 'hello-branch' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_milestone' do
    let_it_be(:milestone) { create(:milestone) }

    subject(:by_milestone) { described_class.by_milestone(query_hash: query_hash, options: options) }

    context 'when :milestone_title, :not_milestone_title, :none_milestones and :any_milestones options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:milestone_title] is provided' do
      let(:options) { { milestone_title: [milestone.title] } }
      let(:expected_filter) do
        [{ bool: { must: { terms: { _name: 'filters:milestone_title',
                                    milestone_title: [milestone.title] } } } }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_milestone_title] is provided' do
      let(:options) { { not_milestone_title: [milestone.title] } }
      let(:expected_filter) do
        [{ bool: { must_not: { terms: { _name: 'filters:not_milestone_title',
                                        milestone_title: [milestone.title] } } } }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:any_milestones] is provided' do
      let(:options) { { any_milestones: true } }
      let(:expected_filter) do
        [{ bool: { _name: 'filters:any_milestones',
                   must: { exists: { field: 'milestone_title' } } } }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:none_milestones] is provided' do
      let(:options) { { none_milestones: true } }
      let(:expected_filter) do
        [{ bool: { _name: 'filters:none_milestones',
                   must_not: { exists: { field: 'milestone_title' } } } }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:milestone_title] and options[:not_milestone_title] are both provided' do
      let_it_be(:another_milestone) { create(:milestone) }

      let(:options) { { milestone_title: [milestone.title], not_milestone_title: [another_milestone.title] } }
      let(:expected_filter) do
        [{
          bool: {
            must: {
              terms: {
                _name: "filters:milestone_title",
                milestone_title: [milestone.title]
              }
            }
          }
        }, {
          bool: {
            must_not: {
              terms: {
                _name: "filters:not_milestone_title",
                milestone_title: [another_milestone.title]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_milestone_state' do
    subject(:by_milestone_state) { described_class.by_milestone_state(query_hash: query_hash, options: options) }

    # milestone_state_filters holds [:upcoming, :started, :not_upcoming, :not_started]
    context 'when milestone_state_filters options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:milestone_state_filters] contains :upcoming' do
      let(:options) { { milestone_state_filters: [:upcoming] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: "filters:milestone_state_upcoming",
            must: [
              { term: { milestone_state: "active" } },
              { range: { milestone_start_date: { gt: "now/d" } } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:milestone_state_filters] contains :not_started' do
      let(:options) { { milestone_state_filters: [:not_started] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: "filters:milestone_state_not_started",
            must: [
              { term: { milestone_state: "active" } },
              { range: { milestone_start_date: { gt: "now/d" } } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:milestone_state_filters] contains :not_upcoming' do
      let(:options) { { milestone_state_filters: [:not_upcoming] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: "filters:milestone_state_not_upcoming",
            must: [
              { term: { milestone_state: "active" } },
              { range: { milestone_start_date: { lte: "now/d" } } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:milestone_state_filters] contains :started' do
      let(:options) { { milestone_state_filters: [:started] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: "filters:milestone_state_started",
            must: [
              { term: { milestone_state: "active" } },
              {
                bool: {
                  should: [
                    { range: { milestone_start_date: { lte: "now/d" } } },
                    { bool: { must_not: { exists: { field: "milestone_start_date" } } } }
                  ]
                }
              },
              {
                bool: {
                  should: [
                    { range: { milestone_due_date: { gte: "now/d" } } },
                    { bool: { must_not: { exists: { field: "milestone_due_date" } } } }
                  ]
                }
              }
            ],
            must_not: {
              bool: {
                must: [
                  { bool: { must_not: { exists: { field: "milestone_start_date" } } } },
                  { bool: { must_not: { exists: { field: "milestone_due_date" } } } }
                ]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_author' do
    let_it_be(:included_user) { user }
    let_it_be(:excluded_user) { create(:user) }

    subject(:by_author) { described_class.by_author(query_hash: query_hash, options: options) }

    context 'when options[:author_username] and options[:not_author_username] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:author_username] and options[:not_author_username] are both provided' do
      let(:options) { { author_username: included_user.username, not_author_username: excluded_user.username } }
      let(:expected_filter) do
        [
          { bool:
            { should: [{ term: { author_id: { _name: 'filters:author', value: included_user.id } } },
              { bool: {
                must_not: {
                  term: { author_id: { _name: 'filters:not_author', value: excluded_user.id } }
                }
              } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:author_username] is provided' do
      let(:options) { { author_username: included_user.username } }
      let(:expected_filter) do
        [
          { bool:
            { should: [{ term: { author_id: { _name: 'filters:author', value: included_user.id } } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_author_username] is provided' do
      let(:options) { { not_author_username: excluded_user.username } }
      let(:expected_filter) do
        [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { author_id: { _name: 'filters:not_author', value: excluded_user.id } }
                }
              } }],
              minimum_should_match: 1 } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_not_hidden' do
    subject(:by_not_hidden) { described_class.by_not_hidden(query_hash: query_hash, options: options) }

    context 'when options[:current_user] is empty' do
      let(:options) { {} }
      let(:expected_filter) do
        [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:current_user] is present' do
      let(:options) { { current_user: user } }

      context 'when user cannot read all resources' do
        let(:expected_filter) do
          [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]
        end

        it_behaves_like 'adds filter to query_hash'
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_forbidden_states' do
    subject(:by_forbidden_states) { described_class.by_forbidden_states(query_hash: query_hash, options: options) }

    context 'when options[:current_user] is not present' do
      let(:options) { {} }
      let(:expected_filter) do
        [{ term: { in_forbidden_state: { _name: 'filters:not_forbidden_state', value: false } } }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:current_user] is present' do
      let(:options) { { current_user: user } }

      context 'when user cannot read all resources' do
        let(:expected_filter) do
          [{ term: { in_forbidden_state: { _name: 'filters:not_forbidden_state', value: false } } }]
        end

        it_behaves_like 'adds filter to query_hash'
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_state' do
    subject(:by_state) { described_class.by_state(query_hash: query_hash, options: options) }

    context 'when options[:state] is empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] is all' do
      let(:options) { { state: 'all' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains an invalid search state' do
      let(:options) { { state: 'invalid' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains a valid search state' do
      let(:options) { { state: 'opened' } }
      let(:expected_filter) do
        [{ match: { state: { _name: 'filters:state', query: 'opened' } } }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_archived' do
    subject(:by_archived) { described_class.by_archived(query_hash: query_hash, options: options) }

    context 'when search_level not provided in options' do
      let(:options) { {} }

      it 'raises an exception' do
        expect { by_archived }.to raise_exception(ArgumentError)
      end
    end

    context 'when options[:include_archived] is empty or false' do
      let(:options) { { include_archived: false, search_level: 'group' } }
      let(:expected_filter) do
        [
          { bool: { _name: 'filters:non_archived',
                    should: [
                      { bool: { filter: { term: { archived: { value: false } } } } },
                      { bool: { must_not: { exists: { field: 'archived' } } } }
                    ] } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:search_level] is project' do
      let(:options) { { include_archived: false, search_level: 'project' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:include_archived] is true' do
      let(:options) { { include_archived: true, search_level: 'group' } }

      it_behaves_like 'does not modify the query_hash'

      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: true, search_level: 'project' } }

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_label_ids' do
    let_it_be(:label_title) { 'My label' }
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: sub_group) }
    # project label must be defined first or the title cannot match
    let_it_be(:project_label) { create(:label, project: project, title: label_title) }
    let_it_be(:project_2) { create(:project, group: group) }
    let_it_be(:project_label_2) { create(:label, project: project_2, title: label_title) }
    let_it_be(:group_label) { create(:group_label, group: group, title: label_title) }
    let_it_be(:another_label) { create(:label, project: project, title: 'Another label') }

    subject(:by_label_ids) { described_class.by_label_ids(query_hash: query_hash, options: options) }

    context 'when options[:label_name] is not provided' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:label_name] is provided' do
      let(:label_name) { [label_title] }
      let(:aggregation) { false }
      let(:count_only) { false }
      let(:group_ids) { nil }
      let(:project_ids) { nil }
      let(:options) do
        {
          label_name: label_name, search_level: search_level, count_only: count_only, aggregation: aggregation,
          group_ids: group_ids, project_ids: project_ids
        }
      end

      context 'when search_level invalid' do
        let(:search_level) { :not_supported }

        it 'raises an exception' do
          expect { by_label_ids }.to raise_exception(ArgumentError)
        end
      end

      context 'when search_level is not provided' do
        let(:options) { { label_name: label_name } }

        it 'raises an exception' do
          expect { by_label_ids }.to raise_exception(ArgumentError)
        end
      end

      context 'for global search' do
        let(:search_level) { :global }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:group_ids] is provided' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash with no group filtering' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end

          context 'when options[:project_ids] is provided' do
            let(:project_ids) { [project.id] }

            it 'adds the label_ids filter to query_hash' do
              expected_filter = [
                bool: {
                  must: [{
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  }]
                }
              ]

              expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
            end
          end
        end

        context 'when options[:project_ids] is provided' do
          using RSpec::Parameterized::TableSyntax

          let(:project_ids) { projects == :any ? projects : [projects.id] }

          where(:projects) do
            [:any, ref(:project), ref(:project_2)]
          end

          with_them do
            it 'adds the label_ids filter to query_hash with no project filtering' do
              expected_filter = [
                bool: {
                  must: [{
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  }]
                }
              ]

              expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
            end
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it 'applies the label filter even during aggregation queries' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        it 'adds the label_ids filter to query_hash' do
          expected_filter = [
            bool: {
              must: [{
                terms: {
                  _name: 'filters:label_ids',
                  label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                }
              }]
            }
          ]

          expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:search_level) { :group }
        let(:group_ids) { [sub_group.id] }
        let(:project_ids) { nil }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it 'applies the label filter even during aggregation queries' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when top level group is searched' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when subgroup is searched' do
          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'for project search' do
        let(:search_level) { :project }
        let(:group_ids) { nil }
        let(:project_ids) { [project.id] }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:group_ids] is provided' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash with no group filtering' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it 'applies the label filter even during aggregation queries' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        it 'adds the label_ids filter to query_hash' do
          expected_filter = [
            bool: {
              must: [{
                terms: {
                  _name: 'filters:label_ids',
                  label_ids: contain_exactly(group_label.id, project_label.id)
                }
              }]
            }
          ]

          expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when options[:labels] and options[:label_name] are provided' do
      let(:options) { { labels: [project_label.id], label_name: [label_title], search_level: :global } }

      it 'uses label_name option and adds the label_ids filter to query_hash' do
        expected_filter = [
          bool: {
            must: [{
              terms: {
                _name: 'filters:label_ids',
                label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
              }
            }]
          }
        ]

        expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
        expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
      end

      context 'when options[:count_only] is true' do
        let(:options) { { label_name: [label_title], count_only: true } }

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when options[:aggregation] is true' do
        let(:options) { { label_name: [label_title], aggregation: true, search_level: :global } }

        it 'applies the label filter even during aggregation queries' do
          expected_filter = [
            bool: {
              must: [{
                terms: {
                  _name: 'filters:label_ids',
                  label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                }
              }]
            }
          ]

          expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
        end
      end
    end
  end

  describe '.by_search_level_and_group_membership' do
    let_it_be_with_reload(:group) { create(:group, :private) }
    let(:base_options) { { current_user: user, search_level: 'global' } }
    let(:options) { base_options }

    subject(:by_search_level_and_group_membership) do
      described_class.by_search_level_and_group_membership(query_hash: query_hash, options: options)
    end

    context 'when no search_level is provided' do
      let(:base_options) { { current_user: user } }

      it 'raises an error' do
        expect { by_search_level_and_group_membership }.to raise_error(ArgumentError)
      end
    end

    context 'when invalid search_level is provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :foobar,
          features: :repository
        }
      end

      it 'raises an error' do
        expect { by_search_level_and_group_membership }.to raise_error(ArgumentError)
      end
    end

    context 'when read_cross_project is not allowed for user' do
      let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_search_level_and_group_membership' }
      let(:expected_query) do
        json = File.read(Rails.root.join(fixtures_path, fixture_file))
        # the traversal_id for the group the user has access to
        json.gsub!('__NAMESPACE_ANCESTRY__', namespace_ancestry) if defined?(namespace_ancestry)
        # the project for the project the user has access to
        json.gsub!('PROJECT_ID', project_id) if defined?(project_id)
        # group search: the traversal_id for the searched group
        json.gsub!('SEARCHED_GROUP', searched_group) if defined?(searched_group)
        # project search: the project_id for the searched project
        json.gsub!('SEARCHED_PROJECT', searched_project) if defined?(searched_project)
        ::Gitlab::Json.safe_parse(json).deep_symbolize_keys
      end

      let_it_be(:user) { create(:user) }
      let(:fixture_file) { 'global_search_user_no_read_cross_project.json' }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_cross_project).and_return(false)
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when user.can_read_all_resources? is true' do
      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      it 'adds a permissive filter for all visibility levels' do
        expected_filter = [
          {
            exists: {
              _name: 'filters:permissions:global:admin_all_groups:namespace_visibility_level:all',
              field: :namespace_visibility_level
            }
          }
        ]

        expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
        expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
        expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when user has GUEST permission for the group' do
      before_all do
        group.add_guest(user)
      end

      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }
        let_it_be(:another_group) { create(:group, :private, guests: user) }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
              ],
              should: [
                { prefix:
                  { traversal_ids:
                    { _name: 'filters:permissions:global:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry } } },
                { prefix:
                  { traversal_ids:
                    { _name: 'filters:permissions:global:ancestry_filter:descendants',
                      value: another_group.elastic_namespace_ancestry } } }
              ],
              minimum_should_match: 1
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
              ],
              should: [
                { prefix:
                  { traversal_ids:
                    { _name: 'filters:permissions:group:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry } } }
              ],
              minimum_should_match: 1
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when user is nil' do
      let(:base_options) { { current_user: nil, search_level: 'global' } }

      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }

        it 'shows only the public filter' do
          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:global:namespace_visibility_level:public',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows only the public filter' do
          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:group:namespace_visibility_level:public',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when user has no role in group or project' do
      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }

        it 'shows only the public and internal filters' do
          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows only the public and filters' do
          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [
                  { bool:
                    { filter: [
                      { terms:
                        { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                          namespace_visibility_level:
                            [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                    ] } }
                ],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when user has GUEST permission for a project in the group hierarchy' do
      let_it_be(:sub_group) { create(:group, :private, parent: group) }
      let_it_be(:project) { create(:project, :private, group: sub_group, guests: user) }

      context 'for global search' do
        let(:options) { base_options.merge(search_level: 'global') }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:global:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } },
                { terms:
                  { _name: 'filters:permissions:global:project:membership',
                    namespace_id: contain_exactly(group.id, sub_group.id) } }
              ]
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:permissions:global',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end

        context 'and user also has direct permission in a top level group' do
          before_all do
            group.add_guest(user)
          end

          it 'shows private filter for top level group and project namespace ancestors' do
            public_and_internal_filter =
              { bool:
                { filter: [
                  { terms:
                    { _name: 'filters:permissions:global:namespace_visibility_level:public_and_internal',
                      namespace_visibility_level:
                        [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                ] } }

            private_filter_top_level_group =
              { bool: {
                minimum_should_match: 1,
                must: [
                  { terms:
                    { _name: 'filters:permissions:global:namespace_visibility_level:private',
                      namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
                ],
                should: [
                  { prefix:
                    { traversal_ids: {
                      _name: 'filters:permissions:global:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry
                    } } }
                ]
              } }

            expected_filter = [
              { bool:
                { _name: 'filters:permissions:global',
                  should: contain_exactly(public_and_internal_filter,
                    private_filter_top_level_group),
                  minimum_should_match: 1 } }
            ]

            expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'for group search' do
        let(:options) { base_options.merge(search_level: 'group', group_ids: [group.id]) }

        it 'shows private filter' do
          public_and_internal_filter =
            { bool:
              { filter: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                    namespace_visibility_level:
                      [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
              ] } }

          private_filter =
            { bool: {
              must: [
                { terms:
                  { _name: 'filters:permissions:group:namespace_visibility_level:private',
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } },
                { terms:
                  { _name: 'filters:permissions:group:project:membership',
                    namespace_id: contain_exactly(group.id, sub_group.id) } }
              ]
            } }

          expected_filter = [
            { bool:
              { _name: 'filters:level:group',
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:level:group:ancestry_filter:descendants',
                        value: group.elastic_namespace_ancestry } } }
                ],
                minimum_should_match: 1 } },
            { bool:
              { _name: 'filters:permissions:group',
                should: [public_and_internal_filter, private_filter],
                minimum_should_match: 1 } }
          ]

          expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
          expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
        end

        context 'and user also has direct permission in a top level group' do
          before_all do
            group.add_guest(user)
          end

          it 'shows private filter for top level group only' do
            public_and_internal_filter =
              { bool:
                { filter: [
                  { terms:
                    { _name: 'filters:permissions:group:namespace_visibility_level:public_and_internal',
                      namespace_visibility_level:
                        [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL] } }
                ] } }

            private_filter =
              { bool: {
                minimum_should_match: 1,
                must: [
                  { terms:
                    { _name: 'filters:permissions:group:namespace_visibility_level:private',
                      namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE] } }
                ],
                should: [
                  { prefix:
                    { traversal_ids: {
                      _name: 'filters:permissions:group:ancestry_filter:descendants',
                      value: group.elastic_namespace_ancestry
                    } } }
                ]
              } }

            expected_filter = [
              { bool:
                { _name: 'filters:level:group',
                  should: [
                    { prefix:
                      { traversal_ids:
                        { _name: 'filters:level:group:ancestry_filter:descendants',
                          value: group.elastic_namespace_ancestry } } }
                  ],
                  minimum_should_match: 1 } },
              { bool:
                { _name: 'filters:permissions:group',
                  should: [public_and_internal_filter, private_filter],
                  minimum_should_match: 1 } }
            ]

            expect(by_search_level_and_group_membership.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :must_not)).to be_empty
            expect(by_search_level_and_group_membership.dig(:query, :bool, :should)).to be_empty
          end
        end
      end
    end
  end

  describe '.by_work_item_type_ids' do
    subject(:by_work_item_type_ids) { described_class.by_work_item_type_ids(query_hash: query_hash, options: options) }

    context 'when options[:work_item_type_ids] and options[:not_work_item_type_ids] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:work_item_type_ids] and options[:not_work_item_type_ids] are both provided' do
      let(:options) { { work_item_type_ids: [1], not_work_item_type_ids: [2] } }

      let(:expected_filter) do
        [
          { bool: {
            must: {
              terms: { work_item_type_id: [1], _name: 'filters:work_item_type_ids' }
            }
          } },
          { bool: { must_not: {
            terms: { work_item_type_id: [2], _name: 'filters:not_work_item_type_ids' }
          } } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:work_item_type_ids] is provided' do
      let(:options) { { work_item_type_ids: [1] } }
      let(:expected_filter) do
        [
          { bool: { must: {
            terms: { work_item_type_id: [1], _name: 'filters:work_item_type_ids' }
          } } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_work_item_type_ids] is provided' do
      let(:options) { { not_work_item_type_ids: [1] } }
      let(:expected_filter) do
        [
          { bool: { must_not: {
            terms: { work_item_type_id: [1], _name: 'filters:not_work_item_type_ids' }
          } } }
        ]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:aggregation] is true' do
      let(:options) { { aggregation: true, work_item_type_ids: [1], not_work_item_type_ids: [2] } }

      it_behaves_like 'does not modify the query_hash'
    end
  end

  describe '.by_type' do
    let(:options) { { doc_type: 'my_type' } }

    subject(:by_type) { described_class.by_type(query_hash: query_hash, options: options) }

    it 'adds the doc type filter to the query_hash' do
      expected_filter = [{ term: { type: { _name: 'filters:doc:is_a:my_type', value: 'my_type' } } }]

      expect(by_type.dig(:query, :bool, :filter)).to eq(expected_filter)
      expect(by_type.dig(:query, :bool, :must)).to be_empty
      expect(by_type.dig(:query, :bool, :must_not)).to be_empty
      expect(by_type.dig(:query, :bool, :should)).to be_empty
    end

    context 'when doc_type not provided in options' do
      let(:options) { {} }

      it 'raises an exception' do
        expect { by_type }.to raise_exception(ArgumentError)
      end
    end
  end

  # the feature `repository` and private project and group are used in these tests
  # to ensure coverage when features have different access requirements for private projects
  # `repository` requires access level of GUEST for public/internal projects and REPOSITORY for private projects
  describe '.by_search_level_and_membership' do
    using RSpec::Parameterized::TableSyntax

    subject(:by_search_level_and_membership) do
      described_class.by_search_level_and_membership(query_hash: query_hash, options: options)
    end

    let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_search_level_and_membership' }
    let(:expected_query) do
      json = File.read(Rails.root.join(fixtures_path, fixture_file))
      # the traversal_id for the group the user has access to
      json.gsub!('__NAMESPACE_ANCESTRY__', namespace_ancestry) if defined?(namespace_ancestry)
      # the traversal_id for the parent group the user has access to
      json.gsub!('__NAMESPACE_ANCESTRY_PARENT__', namespace_ancestry_parent) if defined?(namespace_ancestry_parent)
      # the traversal_id for the shared group the user has access to
      json.gsub!('__SHARED_NAMESPACE_ANCESTRY__', shared_namespace_ancestry) if defined?(shared_namespace_ancestry)
      # the project for the project the user has access to
      json.gsub!('PROJECT_ID', project_id.to_s) if defined?(project_id)
      # group search: the traversal_id for the searched group
      json.gsub!('SEARCHED_GROUP', searched_group) if defined?(searched_group)
      # project search: the project_id for the searched project
      json.gsub!('SEARCHED_PROJECT', searched_project.to_s) if defined?(searched_project)
      ::Gitlab::Json.parse(json).deep_symbolize_keys
    end

    let_it_be(:group) { create(:group, :public) }
    let_it_be(:subgroup) { create(:group, :private, parent: group) }
    let_it_be(:project) { create(:project, :private, group: subgroup) }

    let_it_be(:public_group) { create(:group, :public) }
    let_it_be(:public_project) { create(:project, :public, group: public_group) }

    context 'when invalid search_level is provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :foobar,
          features: :repository
        }
      end

      it 'raises an error' do
        expect { by_search_level_and_membership }.to raise_error(ArgumentError)
      end
    end

    context 'for global search' do
      let(:search_level) { :global }
      let(:options) do
        {
          current_user: user,
          project_ids: [],
          group_ids: [],
          search_level: search_level,
          features: :repository # repository has different requirements for private projects
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'global_search_user_no_access.json' }

        it { is_expected.to eq(expected_query) }
      end

      context 'when read_cross_project is not allowed for user' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'global_search_user_no_read_cross_project.json' }

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_cross_project).and_return(false)
        end

        it { is_expected.to eq(expected_query) }
      end

      context 'when user has access' do
        context 'in public group' do
          context 'with reporter role' do
            before_all do
              public_group.add_reporter(user)
            end

            let(:namespace_ancestry) { public_group.elastic_namespace_ancestry }
            let(:fixture_file) { 'global_search_user_access_to_group_as_reporter.json' }

            it { is_expected.to eq(expected_query) }
          end

          context 'with guest role' do
            before_all do
              public_group.add_guest(user)
            end

            let(:namespace_ancestry) { public_group.elastic_namespace_ancestry }
            let(:fixture_file) { 'global_search_user_access_to_public_group_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in public project' do
          context 'with reporter role' do
            before_all do
              public_project.add_reporter(user)
            end

            let(:project_id) { public_project.id.to_s }
            let(:fixture_file) { 'global_search_user_access_to_public_project_as_reporter.json' }

            it { is_expected.to eq(expected_query) }
          end

          context 'with guest role' do
            before_all do
              public_project.add_guest(user)
            end

            let(:project_id) { public_project.id.to_s }
            let(:fixture_file) { 'global_search_user_access_to_public_project_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in private group' do
          context 'with reporter role' do
            before_all do
              subgroup.add_reporter(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'global_search_user_access_to_group_as_reporter.json' }

            it { is_expected.to eq(expected_query) }
          end

          context 'with guest role' do
            before_all do
              subgroup.add_guest(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'global_search_user_access_to_group_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in private project' do
          context 'with reporter role' do
            before_all do
              project.add_reporter(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'global_search_user_access_to_project_as_reporter.json' }

            it { is_expected.to eq(expected_query) }
          end

          context 'with guest role' do
            before_all do
              project.add_guest(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'global_search_user_access_to_project_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in private group as guest with read_code custom role' do
          before do
            stub_licensed_features(custom_roles: true)

            read_code_role = create(:member_role, :guest, :read_code, namespace: group)
            create(:group_member, :guest, member_role: read_code_role, user: user, source: group)
          end

          let(:namespace_ancestry) { group.elastic_namespace_ancestry }
          let(:fixture_file) { 'global_search_user_access_to_group_with_custom_role.json' }

          it { is_expected.to eq(expected_query) }
        end

        context 'in private group when access is shared through another group', :sidekiq_inline do
          let_it_be(:subgroup) { create(:group, :private, parent: group) }
          let_it_be(:subproject) { create(:project, :private, namespace: subgroup) }
          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:shared_namespace_ancestry) { group_shared.elastic_namespace_ancestry }
          let(:namespace_ancestry_parent) { group.elastic_namespace_ancestry }
          let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
          let(:fixture_file) { 'global_search_user_access_to_group_with_shared_group.json' }

          before_all do
            # test access in a more complex auth structure
            create(:group_group_link, :guest, shared_group: group, shared_with_group: group_shared)
            create(:group_group_link, :reporter, shared_group: subgroup, shared_with_group: group_shared)
            # ensure project authorizations are updated
            group.refresh_members_authorized_projects
          end

          it 'matches the expected query' do
            actual_filter = by_search_level_and_membership.dig(:query, :bool, :filter)
            expected_filter = expected_query[:query][:bool][:filter]

            actual_should_queries = actual_filter.first[:bool][:should]
            expected_should_queries = expected_filter.first[:bool][:should]

            expect(actual_should_queries.length).to eq(expected_should_queries.length)

            # cannot use `eq` for the bool query filters that contain multiple namespaces to avoid order flakiness
            # use match_array for the filters that are populated and eq for filters which are null
            actual_should_queries.each_with_index do |actual_bool_query, idx|
              expected_bool_query = expected_should_queries[idx]

              compare_query_bool_fields(actual_bool_query[:bool], expected_bool_query[:bool])
            end
          end

          def compare_query_bool_fields(actual, expected)
            expected.each_key do |key|
              if expected[key].is_a?(Array)
                expect(actual[key]).to match_array(expected[key])
              else
                expect(actual[key]).to eq(expected[key])
              end
            end
          end
        end

        context 'in private project when access is shared through another group' do
          let_it_be(:subgroup) { create(:group, :private, parent: group) }
          let_it_be(:subproject) { create(:project, :private, namespace: subgroup) }
          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:project_id) { subproject.id.to_s }
          let(:namespace_ancestry) { group_shared.elastic_namespace_ancestry }
          let(:fixture_file) { 'global_search_user_access_to_project_with_shared_group.json' }

          before_all do
            # test access in a more complex auth structure
            create(:project_group_link, :guest, project: project, group: group_shared)
            create(:project_group_link, :reporter, project: subproject, group: group_shared)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:fixture_file) { 'global_search_admin.json' }

        it { is_expected.to eq(expected_query) }
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:fixture_file) { 'global_search_anonymous.json' }

        it { is_expected.to eq(expected_query) }
      end

      context 'when restrict_to_membership is true (e.g. project autocomplete)' do
        let(:options) do
          {
            current_user: user,
            project_ids: [],
            group_ids: [],
            search_level: search_level,
            restrict_to_membership: true
          }
        end

        context 'when the user has a membership' do
          let_it_be(:user) { create(:user) }
          let(:project_id) { project.id }
          let(:fixture_file) { 'global_search_autocomplete_project.json' }

          before_all do
            project.add_developer(user)
          end

          it { is_expected.to eq(expected_query) }
        end

        context 'when the user has no memberships' do
          let_it_be(:user) { create(:user) }
          let(:fixture_file) { 'global_search_autocomplete_project_no_membership.json' }

          it 'matches nothing instead of all documents' do
            is_expected.to eq(expected_query)
          end
        end
      end

      context 'when autocomplete is true but restrict_to_membership is not set (e.g. merge_request autocomplete)' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'global_search_autocomplete_merge_request.json' }

        let(:options) do
          {
            current_user: user,
            project_ids: [],
            group_ids: [],
            search_level: search_level,
            autocomplete: true
          }
        end

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'for group search' do
      let(:searched_group) { group.elastic_namespace_ancestry }
      let(:search_level) { :group }
      let(:options) do
        {
          current_user: user,
          project_ids: [],
          group_ids: [group.id],
          search_level: search_level,
          features: :repository,
          project_visibility_level_field: :visibility_level
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'group_search_user_no_access.json' }

        it { is_expected.to eq(expected_query) }
      end

      context 'when user has access' do
        context 'in private group' do
          context 'with reporter role' do
            before_all do
              subgroup.add_reporter(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'group_search_user_access_to_group_as_reporter.json' }

            it { is_expected.to eq(expected_query) }
          end

          context 'with guest role' do
            before_all do
              subgroup.add_guest(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'group_search_user_access_to_group_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in private project' do
          context 'with reporter role' do
            before_all do
              project.add_reporter(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'group_search_user_access_to_project_as_reporter.json' }

            it { is_expected.to eq(expected_query) }

            context 'and searching in the project namespace' do
              let(:fixture_file) { 'group_search_user_access_to_project_as_reporter.json' }
              let(:searched_group) { subgroup.elastic_namespace_ancestry }
              let(:options) do
                {
                  current_user: user,
                  project_ids: [],
                  group_ids: [subgroup.id],
                  search_level: search_level,
                  features: :repository,
                  project_visibility_level_field: :visibility_level
                }
              end

              it { is_expected.to eq(expected_query) }
            end
          end

          context 'with guest role' do
            before_all do
              project.add_guest(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'group_search_user_access_to_project_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in private group as guest with read_code custom role' do
          before do
            stub_licensed_features(custom_roles: true)

            read_code_role = create(:member_role, :guest, :read_code, namespace: group)
            create(:group_member, :guest, member_role: read_code_role, user: user, source: group)
          end

          let(:namespace_ancestry) { group.elastic_namespace_ancestry }
          let(:fixture_file) { 'group_search_user_access_to_group_with_custom_role.json' }

          it { is_expected.to eq(expected_query) }
        end

        context 'in private group when access is shared through another group' do
          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:shared_namespace_ancestry) { group_shared.elastic_namespace_ancestry }
          let(:namespace_ancestry) { group.elastic_namespace_ancestry }
          let(:fixture_file) { 'group_search_user_access_to_group_with_shared_group.json' }

          before_all do
            create(:group_group_link, :reporter, shared_group: group, shared_with_group: group_shared)
          end

          it { is_expected.to eq(expected_query) }
        end

        context 'in private project when access is shared through another group' do
          let(:fixture_file) { 'group_search_user_access_to_project_with_shared_group.json' }
          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:project_id) { project.id.to_s }

          before_all do
            create(:project_group_link, :reporter, project: project, group: group_shared)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:fixture_file) { 'group_search_admin.json' }

        it { is_expected.to eq(expected_query) }
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:fixture_file) { 'group_search_anonymous.json' }

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'for project search' do
      let(:searched_project) { project.id.to_s }
      let(:search_level) { :project }
      let(:options) do
        {
          current_user: user,
          project_ids: [project.id],
          group_ids: [group.id],
          search_level: search_level,
          features: :repository,
          project_visibility_level_field: :visibility_level
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:fixture_file) { 'project_search_user_no_access.json' }

        it { is_expected.to eq(expected_query) }
      end

      context 'when user has access' do
        context 'in private group' do
          context 'with reporter role' do
            before_all do
              subgroup.add_reporter(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'project_search_user_access_to_group_as_reporter.json' }

            it { is_expected.to eq(expected_query) }
          end

          context 'with guest role' do
            before_all do
              subgroup.add_guest(user)
            end

            let(:namespace_ancestry) { subgroup.elastic_namespace_ancestry }
            let(:fixture_file) { 'project_search_user_access_to_group_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in private project' do
          context 'with reporter role' do
            before_all do
              project.add_reporter(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'project_search_user_access_to_project_as_reporter.json' }

            it { is_expected.to eq(expected_query) }
          end

          context 'with guest role' do
            before_all do
              project.add_guest(user)
            end

            let(:project_id) { project.id.to_s }
            let(:fixture_file) { 'project_search_user_access_to_project_as_guest.json' }

            it { is_expected.to eq(expected_query) }
          end
        end

        context 'in private group as guest with read_code custom role' do
          before do
            stub_licensed_features(custom_roles: true)

            read_code_role = create(:member_role, :guest, :read_code, namespace: group)
            create(:group_member, :guest, member_role: read_code_role, user: user, source: group)
          end

          let(:namespace_ancestry) { project.namespace.elastic_namespace_ancestry }
          let(:fixture_file) { 'project_search_user_access_to_group_with_custom_role.json' }

          it { is_expected.to eq(expected_query) }
        end

        context 'in private group when access is shared through another group' do
          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:namespace_ancestry) { project.group.elastic_namespace_ancestry }
          let(:fixture_file) { 'project_search_user_access_to_group_with_shared_group.json' }

          before_all do
            create(:group_group_link, :reporter, shared_group: group, shared_with_group: group_shared)
          end

          it { is_expected.to eq(expected_query) }
        end

        context 'in private project when access is shared through another group' do
          let(:fixture_file) { 'project_search_user_access_to_project_with_shared_group.json' }

          let_it_be(:group_shared) { create(:group, :private, reporters: user) }
          let(:project_id) { project.id.to_s }

          before_all do
            create(:project_group_link, :reporter, project: project, group: group_shared)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:fixture_file) { 'project_search_admin.json' }

        it { is_expected.to eq(expected_query) }
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:fixture_file) { 'project_search_anonymous.json' }

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'when project_visibility_level_field is provided in options' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :global,
          features: :repository,
          project_visibility_level_field: :test_field_name
        }
      end

      let(:fixture_file) { 'global_search_anonymous_custom_project_visibility_level_field.json' }

      it { is_expected.to eq(expected_query) }
    end

    context 'when multiple features are provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :global,
          features: [:issues, :merge_requests, :repository, :snippets] # mimic notes queries
        }
      end

      let(:fixture_file) { 'global_search_anonymous_multiple_features.json' }

      it { is_expected.to eq(expected_query) }
    end
  end

  describe '.by_noteable_type' do
    # use a query (including highlight) like what NoteClassProxy uses
    let(:query_hash) do
      {
        query: {
          bool: {
            must: [],
            should: [],
            filter: []
          }
        },
        highlight: {
          fields: {
            note: {}
          },
          number_of_fragments: 0,
          pre_tags: [Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG],
          post_tags: [Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG]
        }
      }
    end

    context 'when search_level is global' do
      it 'returns the original query_hash without modifications' do
        options = { search_level: 'global' }

        result = described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(result).to eq(query_hash)
        expect(result).to be(query_hash)
      end
    end

    context 'when noteable_type is not provided' do
      it 'returns the original query_hash without modifications' do
        options = { search_level: 'project' }

        result = described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(result).to eq(query_hash)
        expect(result).to be(query_hash)
      end
    end

    context 'when invalid noteable_type is provided' do
      let(:options) { { search_level: 'project', noteable_type: 'Hello' } }

      it 'raises an error' do
        expect { described_class.by_noteable_type(query_hash: query_hash, options: options) }
          .to raise_error(ArgumentError)
      end
    end

    context 'when only valid noteable_type is provided' do
      let(:options) { { search_level: 'project', noteable_type: 'Issue' } }

      it 'keeps the highlight if set' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash).to have_key(:highlight)
      end

      it 'does not set _source to only include noteable_id' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash).not_to have_key(:_source)
      end

      it 'does not sets size' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash).not_to have_key(:size)
      end
    end

    context 'when valid noteable_type and related_ids_only is provided' do
      let(:options) { { search_level: 'project', noteable_type: 'Issue', related_ids_only: true } }

      it 'does not provide highlight' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash).not_to have_key(:highlight)
      end

      it 'sets _source to only include noteable_id' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash[:_source]).to eq(["noteable_id"])
      end

      it 'sets size to DEFAULT_RELATED_SIZE by default' do
        described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(query_hash[:size]).to eq(described_class::DEFAULT_RELATED_SIZE)
      end

      it 'uses custom related_size when provided' do
        custom_size = 50
        options_with_size = options.merge(related_size: custom_size)

        described_class.by_noteable_type(query_hash: query_hash, options: options_with_size)

        expect(query_hash[:size]).to eq(custom_size)
      end

      it 'creates a term filter with the noteable_type' do
        result = described_class.by_noteable_type(query_hash: query_hash, options: options)

        expect(result.dig(:query, :bool, :filter)).to eq([{
          term: {
            noteable_type: {
              _name: 'filters:related:issue',
              value: 'Issue'
            }
          }
        }])
      end
    end
  end

  describe '.by_assignees' do
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }
    let_it_be(:user3) { create(:user) }

    subject(:by_assignees) { described_class.by_assignees(query_hash: query_hash, options: options) }

    context 'when all assignee options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:assignee_ids] is provided' do
      let(:options) { { assignee_ids: [user1.id, user2.id] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:assignee_ids',
            must: [
              { term: { assignee_id: user1.id } },
              { term: { assignee_id: user2.id } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_assignee_ids] is provided' do
      let(:options) { { not_assignee_ids: [user1.id, user2.id] } }
      let(:expected_filter) do
        [{
          bool: {
            must_not: {
              terms: {
                _name: 'filters:not_assignee_ids',
                assignee_id: [user1.id, user2.id]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:or_assignee_ids] is provided' do
      let(:options) { { or_assignee_ids: [user1.id, user2.id] } }
      let(:expected_filter) do
        [{
          bool: {
            must: {
              terms: {
                _name: 'filters:or_assignee_ids',
                assignee_id: [user1.id, user2.id]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:any_assignees] is provided' do
      let(:options) { { any_assignees: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:any_assignees',
            must: { exists: { field: 'assignee_id' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:none_assignees] is provided' do
      let(:options) { { none_assignees: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:none_assignees',
            must_not: { exists: { field: 'assignee_id' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:assignee_ids] and options[:not_assignee_ids] are both provided' do
      let(:options) { { assignee_ids: [user1.id], not_assignee_ids: [user2.id, user3.id] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:assignee_ids',
            must: [
              { term: { assignee_id: user1.id } }
            ]
          }
        }, {
          bool: {
            must_not: {
              terms: {
                _name: 'filters:not_assignee_ids',
                assignee_id: [user2.id, user3.id]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_label_names' do
    subject(:by_label_names) { described_class.by_label_names(query_hash: query_hash, options: options) }

    context 'when all label name options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:label_names] is provided' do
      let(:options) { { label_names: ['workflow::complete', 'backend'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow::complete' } },
              { term: { label_names: 'backend' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:label_names] with wildcard is provided' do
      let(:options) { { label_names: ['workflow::*', 'frontend'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { prefix: { label_names: 'workflow::' } },
              { term: { label_names: 'frontend' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_label_names] is provided' do
      let(:options) { { not_label_names: ['workflow::in dev'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { term: { label_names: 'workflow::in dev' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_label_names] with wildcard is provided' do
      let(:options) { { not_label_names: ['group::*'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { prefix: { label_names: 'group::' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:or_label_names] is provided' do
      let(:options) { { or_label_names: ['workflow::complete', 'group::planner intelligence'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { term: { label_names: 'workflow::complete' } },
              { term: { label_names: 'group::planner intelligence' } }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:or_label_names] with wildcard is provided' do
      let(:options) { { or_label_names: ['workflow::*', 'backend'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { prefix: { label_names: 'workflow::' } },
              { term: { label_names: 'backend' } }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:any_label_names] is provided' do
      let(:options) { { any_label_names: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:any_label_names',
            must: { exists: { field: 'label_names' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:none_label_names] is provided' do
      let(:options) { { none_label_names: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:none_label_names',
            must_not: { exists: { field: 'label_names' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:label_names] and options[:not_label_names] are both provided' do
      let(:options) { { label_names: ['workflow::complete'], not_label_names: ['group::*'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow::complete' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { prefix: { label_names: 'group::' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when complex mixed options are provided' do
      let(:options) do
        {
          label_names: ['workflow::complete'],
          not_label_names: ['group::*'],
          or_label_names: ['workflow::*', 'frontend'],
          any_label_names: false,
          none_label_names: false
        }
      end

      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow::complete' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { prefix: { label_names: 'group::' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { prefix: { label_names: 'workflow::' } },
              { term: { label_names: 'frontend' } }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when mixed ANY with other filters is provided' do
      let(:options) do
        {
          any_label_names: true,
          not_label_names: ['workflow::in dev'],
          or_label_names: %w[frontend backend]
        }
      end

      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:not_label_names',
            must_not: [
              { term: { label_names: 'workflow::in dev' } }
            ]
          }
        }, {
          bool: {
            _name: 'filters:or_label_names',
            should: [
              { term: { label_names: 'frontend' } },
              { term: { label_names: 'backend' } }
            ],
            minimum_should_match: 1
          }
        }, {
          bool: {
            _name: 'filters:any_label_names',
            must: { exists: { field: 'label_names' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when label_names with incorrect wildcard patterns are provided' do
      let(:options) { { label_names: ['workflow*', 'backend::', '*workflow', '::workflow'] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:label_names',
            must: [
              { term: { label_names: 'workflow*' } },
              { term: { label_names: 'backend::' } },
              { term: { label_names: '*workflow' } },
              { term: { label_names: '::workflow' } }
            ]
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_weight' do
    subject(:by_weight) { described_class.by_weight(query_hash: query_hash, options: options) }

    context 'when all weight options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:weight] is provided' do
      let(:options) { { weight: 3 } }
      let(:expected_filter) do
        [{
          term: {
            weight: {
              _name: 'filters:weight',
              value: 3
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_weight] is provided' do
      let(:options) { { not_weight: 2 } }
      let(:expected_filter) do
        [{
          bool: {
            must_not: {
              term: {
                weight: {
                  _name: 'filters:not_weight',
                  value: 2
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:any_weight] is provided' do
      let(:options) { { any_weight: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:any_weight',
            must: { exists: { field: 'weight' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:none_weight] is provided' do
      let(:options) { { none_weight: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:none_weight',
            must_not: { exists: { field: 'weight' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_health_status' do
    subject(:by_health_status) { described_class.by_health_status(query_hash: query_hash, options: options) }

    context 'when all health_status options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:health_status] is provided' do
      let(:options) { { health_status: [1] } }
      let(:expected_filter) do
        [{
          bool: {
            must: {
              terms: {
                _name: 'filters:health_status',
                health_status: [1]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:not_health_status] is provided' do
      let(:options) { { not_health_status: [2] } }
      let(:expected_filter) do
        [{
          bool: {
            must_not: {
              terms: {
                _name: 'filters:not_health_status',
                health_status: [2]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:any_health_status] is provided' do
      let(:options) { { any_health_status: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:any_health_status',
            must: { exists: { field: 'health_status' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:none_health_status] is provided' do
      let(:options) { { none_health_status: true } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:none_health_status',
            must_not: { exists: { field: 'health_status' } }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_closed_at' do
    subject(:by_closed_at) { described_class.by_closed_at(query_hash: query_hash, options: options) }

    context 'when all closed_at options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:closed_after] is provided' do
      let(:options) { { closed_after: '2025-01-01T00:00:00Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:closed_after',
            must: {
              range: {
                'closed_at' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:closed_before] is provided' do
      let(:options) { { closed_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:closed_before',
            must: {
              range: {
                'closed_at' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when both options[:closed_after] and options[:closed_before] are provided' do
      let(:options) { { closed_after: '2025-01-01T00:00:00Z', closed_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:closed_after',
            must: {
              range: {
                'closed_at' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }, {
          bool: {
            _name: 'filters:closed_before',
            must: {
              range: {
                'closed_at' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_created_at' do
    subject(:by_created_at) { described_class.by_created_at(query_hash: query_hash, options: options) }

    context 'when all created_at options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:created_after] is provided' do
      let(:options) { { created_after: '2025-01-01T00:00:00Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:created_after',
            must: {
              range: {
                'created_at' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:created_before] is provided' do
      let(:options) { { created_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:created_before',
            must: {
              range: {
                'created_at' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when both options[:created_after] and options[:created_before] are provided' do
      let(:options) { { created_after: '2025-01-01T00:00:00Z', created_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:created_after',
            must: {
              range: {
                'created_at' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }, {
          bool: {
            _name: 'filters:created_before',
            must: {
              range: {
                'created_at' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_updated_at' do
    subject(:by_updated_at) { described_class.by_updated_at(query_hash: query_hash, options: options) }

    context 'when all updated_at options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:updated_after] is provided' do
      let(:options) { { updated_after: '2025-01-01T00:00:00Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:updated_after',
            must: {
              range: {
                'updated_at' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:updated_before] is provided' do
      let(:options) { { updated_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:updated_before',
            must: {
              range: {
                'updated_at' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when both options[:updated_after] and options[:updated_before] are provided' do
      let(:options) { { updated_after: '2025-01-01T00:00:00Z', updated_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:updated_after',
            must: {
              range: {
                'updated_at' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }, {
          bool: {
            _name: 'filters:updated_before',
            must: {
              range: {
                'updated_at' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_combined_search_level_and_membership' do
    let_it_be(:user) { create(:user) }
    let(:options) { { current_user: user, search_level: 'global' } }

    subject(:by_combined_search_level_and_membership) do
      described_class.by_combined_search_level_and_membership(query_hash: query_hash, options: options)
    end

    context 'when neither use_project_authorization nor use_group_authorization is provided' do
      it_behaves_like 'does not modify the query_hash'
    end

    context 'when use_project_authorization is true' do
      let(:options) { super().merge(use_project_authorization: true) }

      it 'calls by_search_level_and_membership with use_project_authorization options' do
        expect(described_class).to receive(:by_search_level_and_membership).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect { by_combined_search_level_and_membership }.not_to raise_error
      end

      it 'only adds project filters' do
        result = by_combined_search_level_and_membership
        expect(result.dig(:query, :bool, :filter)).to be_present
        assert_names_in_query(result, with: %w[filters:permissions:global:visibility_level:public_and_internal],
          without: %w[filters:permissions:global:namespace_visibility_level:public_and_internal])
      end
    end

    context 'when use_group_authorization is true' do
      let(:options) { super().merge(use_group_authorization: true) }

      it 'calls by_search_level_and_group_membership with use_group_authorization options' do
        expect(described_class).to receive(:by_search_level_and_group_membership).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect { by_combined_search_level_and_membership }.not_to raise_error
      end

      it 'only adds group filters' do
        result = by_combined_search_level_and_membership
        expect(result.dig(:query, :bool, :filter)).to be_present
        assert_names_in_query(result,
          with: %w[filters:permissions:global:namespace_visibility_level:public_and_internal],
          without: %w[filters:permissions:global:visibility_level:public_and_internal])
      end
    end

    context 'when both use_project_authorization and use_group_authorization are true' do
      let(:options) { super().merge(use_project_authorization: true, use_group_authorization: true) }

      it 'calls both underlying methods' do
        expect(described_class).to receive(:by_search_level_and_membership).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect(described_class).to receive(:by_search_level_and_group_membership).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect { by_combined_search_level_and_membership }.not_to raise_error
      end

      it 'creates a combined filter with should clauses' do
        result = by_combined_search_level_and_membership
        filter = result.dig(:query, :bool, :filter)

        expect(filter).to be_an(Array)
        expect(filter.first).to have_key(:bool)
        expect(filter.first[:bool]).to have_key(:should)
        expect(filter.first[:bool][:should].length).to eq(2)
        assert_names_in_query(filter, with: %w[
          filters:permissions:global:visibility_level:public_and_internal
          filters:permissions:global:namespace_visibility_level:public_and_internal
        ])
      end
    end
  end

  describe '.by_due_date' do
    subject(:by_due_date) { described_class.by_due_date(query_hash: query_hash, options: options) }

    context 'when all due_date options are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:due_after] is provided' do
      let(:options) { { due_after: '2025-01-01T00:00:00Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:due_after',
            must: {
              range: {
                'due_date' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:due_before] is provided' do
      let(:options) { { due_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:due_before',
            must: {
              range: {
                'due_date' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when both options[:due_after] and options[:due_before] are provided' do
      let(:options) { { due_after: '2025-01-01T00:00:00Z', due_before: '2025-12-31T23:59:59Z' } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:due_after',
            must: {
              range: {
                'due_date' => {
                  gte: '2025-01-01T00:00:00Z'
                }
              }
            }
          }
        }, {
          bool: {
            _name: 'filters:due_before',
            must: {
              range: {
                'due_date' => {
                  lte: '2025-12-31T23:59:59Z'
                }
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_iids' do
    subject(:by_iids) { described_class.by_iids(query_hash: query_hash, options: options) }

    context 'when iids option is empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when iids option is nil' do
      let(:options) { { iids: nil } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:iids] is provided with single iid' do
      let(:options) { { iids: [1] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:iids',
            filter: {
              terms: {
                'iid' => [1]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'when options[:iids] is provided with multiple iids' do
      let(:options) { { iids: [1, 2, 3] } }
      let(:expected_filter) do
        [{
          bool: {
            _name: 'filters:iids',
            filter: {
              terms: {
                'iid' => [1, 2, 3]
              }
            }
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end
  end

  describe '.by_user_accessible_namespaces' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:sub_sub_group) { create(:group, parent: sub_group) }
    let_it_be(:project) { create(:project, group: sub_sub_group) }

    subject(:by_user_accessible_namespaces) do
      described_class.by_user_accessible_namespaces(query_hash: query_hash, options: options)
    end

    context 'when search_level is not provided' do
      let(:options) { {} }

      it 'raises an error' do
        expect { by_user_accessible_namespaces }.to raise_error(ArgumentError)
      end
    end

    context 'when invalid search_level is provided' do
      let(:options) { { search_level: :invalid } }

      it 'raises an error' do
        expect { by_user_accessible_namespaces }.to raise_error(ArgumentError)
      end
    end

    context 'for global search without user' do
      let(:options) { { search_level: :global } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'for global search with user but no autocomplete' do
      let(:options) { { search_level: :global, current_user: user } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'for global search with user and autocomplete but no authorized groups or projects' do
      let(:options) { { search_level: :global, current_user: user, autocomplete: true } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'for global search with authorized groups' do
      before_all do
        group.add_developer(user)
      end

      let(:options) { { search_level: :global, current_user: user, autocomplete: true } }

      let(:expected_filter) do
        [{
          bool: {
            should: [
              {
                prefix: {
                  namespace_ancestry_ids: {
                    _name: 'namespace:ancestry_filter:descendants',
                    value: group.elastic_namespace_ancestry
                  }
                }
              }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'for global search with authorized projects' do
      before_all do
        project.add_developer(user)
      end

      let(:options) { { search_level: :global, current_user: user, autocomplete: true } }

      let(:expected_filter) do
        [{
          bool: {
            should: [
              {
                terms: {
                  namespace_ancestry_ids: contain_exactly(project.elastic_namespace_ancestry),
                  _name: 'namespace:ancestry_filter:ancestors'
                }
              }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'for group search in top-level group' do
      let(:options) { { search_level: :group, group_id: group.id } }

      let(:expected_filter) do
        [{
          bool: {
            should: [
              {
                prefix: {
                  namespace_ancestry_ids: {
                    _name: 'namespace:ancestry_filter:descendants',
                    value: group.elastic_namespace_ancestry
                  }
                }
              }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'for group search in sub group' do
      let(:options) { { search_level: :group, group_id: sub_sub_group.id } }

      let(:expected_filter) do
        [{
          bool: {
            should: [
              {
                prefix: {
                  namespace_ancestry_ids: {
                    _name: 'namespace:ancestry_filter:descendants',
                    value: sub_sub_group.elastic_namespace_ancestry
                  }
                }
              },
              {
                terms: {
                  namespace_ancestry_ids: contain_exactly(
                    group.elastic_namespace_ancestry,
                    sub_group.elastic_namespace_ancestry
                  ),
                  _name: 'namespace:ancestry_filter:ancestors'
                }
              }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'for group search when group does not exist' do
      let(:options) { { search_level: :group, group_id: non_existing_record_id } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'for project search' do
      let(:options) { { search_level: :project, project_id: project.id } }

      let(:expected_filter) do
        [{
          bool: {
            should: [
              {
                terms: {
                  namespace_ancestry_ids: contain_exactly(
                    group.elastic_namespace_ancestry,
                    sub_group.elastic_namespace_ancestry,
                    sub_sub_group.elastic_namespace_ancestry,
                    project.elastic_namespace_ancestry
                  ),
                  _name: 'namespace:ancestry_filter:ancestors'
                }
              }
            ],
            minimum_should_match: 1
          }
        }]
      end

      it_behaves_like 'adds filter to query_hash'
    end

    context 'for project search when project does not exist' do
      let(:options) { { search_level: :project, project_id: non_existing_record_id } }

      it_behaves_like 'does not modify the query_hash'
    end
  end
end
