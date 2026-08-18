# frozen_string_literal: true

# check search results respects read cross project permission for users
# use with legacy ClassProxy authorization methods
#
# requires the following to be defined in test context
#  - `record_1` - record for the scope being tested
#  - `record_2` - record for the scope being tested
RSpec.shared_examples 'no results when the user cannot read cross project' do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :public) }
  let_it_be(:project2, freeze: false) { create(:project, :public) }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    expect(Ability).to receive(:allowed?).with(user, :read_cross_project).and_return(false)
    record1
    record2
    ensure_elasticsearch_index!
  end

  it 'returns the record if a single project was passed', :sidekiq_inline do
    result = described_class.elastic_search(
      'test',
      options: {
        current_user: user,
        project_ids: [project.id],
        search_level: 'project'
      }
    )

    expect(result.records).to match_array [record1]
  end

  it 'does not return anything when trying to search cross project', :sidekiq_inline do
    result = described_class.elastic_search(
      'test',
      options: {
        current_user: user,
        project_ids: [project.id, project2.id],
        search_level: 'global'
      }
    )

    expect(result.records).to be_empty
  end
end

# check search results respects read cross project permission for users
# use with Search::Elastic::Filters authorization methods
#
# requires the following to be defined in test context
#  - `record_1` - record for the scope being tested
#  - `record_2` - record for the scope being tested
RSpec.shared_examples 'respects permission to read cross project' do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, :public, group: group) }
  let_it_be(:project2, freeze: false) { create(:project, :public) }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    expect(Ability).to receive(:allowed?).with(user, :read_cross_project).and_return(false)

    Elastic::ProcessInitialBookkeepingService.track!(record1, record2)
    ensure_elasticsearch_index!
  end

  context 'for global level' do
    it 'does not return anything when trying to search cross project', :sidekiq_inline do
      result = described_class.elastic_search(
        'test',
        options: {
          current_user: user,
          search_level: 'global'
        }
      )

      expect(result.records).to be_empty
    end
  end

  context 'for group level' do
    it 'does not return anything when trying to search cross project', :sidekiq_inline do
      result = described_class.elastic_search(
        'test',
        options: {
          current_user: user,
          group_ids: [group.id],
          search_level: 'group'
        }
      )

      expect(result.records).to be_empty
    end
  end

  context 'for project level' do
    it 'returns a record', :sidekiq_inline do
      result = described_class.elastic_search(
        'test',
        options: {
          current_user: user,
          project_ids: [project.id],
          search_level: 'project'
        }
      )

      expect(result.records).to match_array [record1]
    end
  end
end
