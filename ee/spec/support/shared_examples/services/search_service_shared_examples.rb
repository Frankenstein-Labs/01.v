# frozen_string_literal: true

# check access for search visibility using permissions tables in
# spec/support/shared_contexts/policies/project_policy_table_shared_context.rb
#
# The shared examples checks access when user has access to the project and group separately
# `group_access` can be provided to not check access through group, direct access
# `project_access` can be provided to not check access through project, direct access,
# `group_access_shared_group` can be provided to not check access through group, shared group
# `project_access_shared_group` can be provided to not check access through project, shared group
# `project_feature_setup` can be provided to not run the project feature access setup
#
# requires the following to be defined in test context
#  - `user` - user built with access to the projects
#  - `user_in_group` - user built with access to the groups
#  - `shared_with_group` - group shared with the project/group under test
#  - `user_in_shared_group` - user built with access to shared_with_group
#  - `group` - group to check access through
#  - `projects` - list of projects to update `feature_access_level`
#  - `project_level` - project visibility level
#  - `admin_mode` - whether admin mode is enabled
#  - `feature_access_level` - a single value or an array of feature access level changes to update
#  - `search_level` - used for Search::GroupService
#  - `search` - the search term
#  - `scope` - the scope of the search results
#  - `expected_count` - the expected search result count
RSpec.shared_examples 'search respects visibility' do |group_access: true,
  project_access: true, group_access_shared_group: true, project_access_shared_group: true, project_feature_setup: true|
  before do
    set_project_visibility_and_feature_access_level if project_feature_setup && project_access
    set_group_visibility_level if group_access

    ensure_elasticsearch_index! if ::Gitlab::CurrentSettings.elasticsearch_indexing?
    projects.each { |p| zoekt_ensure_project_indexed!(p) } if ::Gitlab::CurrentSettings.zoekt_indexing_enabled?
  end

  # sidekiq needed for ElasticAssociationIndexerWorker
  # :aggregate_failures metadata wraps the entire example; the nested aggregate_failures blocks
  # are purely for labeling failures with which access path broke.
  it 'respects visibility across access levels', :sidekiq_inline, :aggregate_failures do
    # ensure that at least 1 check is run to avoid risk of a silent pass if no check is hit
    checks_run = 0

    # Check access at project level
    if project_access
      checks_run += 1
      enable_admin_mode!(user) if admin_mode

      expect_search_results(user, scope, expected_count: expected_count, context: 'project level') do |u|
        execute_search(u)
      end
    end

    # Check access at group level
    if group_access
      checks_run += 1
      enable_admin_mode!(user_in_group) if admin_mode

      expect_search_results(user_in_group, scope, expected_count: expected_count, context: 'group level') do |u|
        execute_search(u)
      end
    end

    # Check access at project level through a shared group
    if project_access_shared_group
      checks_run += 1
      project_group_link = nil
      begin
        project_group_link = if Gitlab::Access.sym_options_with_owner.key?(membership)
                               create(:project_group_link,
                                 group_access: Gitlab::Access.sym_options_with_owner[membership],
                                 project: project,
                                 group: shared_with_group
                               )
                             end

        zoekt_ensure_namespace_indexed!(shared_with_group) if ::Gitlab::CurrentSettings.zoekt_indexing_enabled?

        enable_admin_mode!(user_in_shared_group) if admin_mode

        expect_search_results(user_in_shared_group, scope, expected_count: expected_count,
          context: 'project level through shared group') do |u|
          execute_search(u)
        end
      ensure
        project_group_link&.destroy!
      end
    end

    # Check access at group level through a shared group
    if group_access_shared_group
      checks_run += 1
      group_group_link = nil
      begin
        group_group_link = if Gitlab::Access.sym_options_with_owner.key?(membership)
                             create(:group_group_link,
                               group_access: Gitlab::Access.sym_options_with_owner[membership],
                               shared_group: group,
                               shared_with_group: shared_with_group
                             )
                           end

        zoekt_ensure_namespace_indexed!(shared_with_group) if ::Gitlab::CurrentSettings.zoekt_indexing_enabled?

        enable_admin_mode!(user_in_shared_group) if admin_mode

        # ensure project authorizations are updated
        group.refresh_members_authorized_projects

        expect_search_results(user_in_shared_group, scope, expected_count: expected_count,
          context: 'group level through shared group') do |u|
          execute_search(u)
        end
      ensure
        group_group_link&.destroy!
      end
    end

    expect(checks_run).to be > 0, "No access level was checked — verify the permission table row flags"
  end

  private

  def execute_search(user)
    if described_class.eql?(Search::GlobalService)
      described_class.new(user, search: search, scope: scope).execute
    else
      described_class.new(user, search_level, search: search, scope: scope).execute
    end
  end

  def set_group_visibility_level
    group.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))
  end

  def set_project_visibility_and_feature_access_level
    projects.each do |project|
      update_feature_access_level(
        project,
        feature_access_level,
        visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s)
      )
    end
  end
end

# check access for search visibility using a custom role with GUEST access and read_code ability
# requires the following to be defined in test context
#  - `group` - the group to check access through
#  - `project` - the project to test access through
#  - `search_level` - used for Search::GroupService
#  - `search` - the search term
#  - `scope` - the scope of the search results
RSpec.shared_examples 'supports custom role access :read_code access' do
  let(:user_with_role) { create(:user) }
  let_it_be(:read_code_role, freeze: false) { create(:member_role, :guest, :read_code, namespace: group) }

  before do
    stub_licensed_features(custom_roles: true)

    # project must be private to test out authorization, private groups require reporter level to view code
    project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

    ensure_elasticsearch_index! if ::Gitlab::CurrentSettings.elasticsearch_indexing?
    zoekt_ensure_project_indexed!(project) if ::Gitlab::CurrentSettings.zoekt_indexing_enabled?
  end

  context 'with access at group level' do
    it 'respects visibility', :sidekiq_inline do
      expect_search_results(user_with_role, scope, expected_count: 0) do |u|
        if described_class.eql?(Search::GlobalService)
          described_class.new(u, search: search, scope: scope).execute
        else
          described_class.new(u, search_level, search: search, scope: scope).execute
        end
      end

      # user role must be guest to test out custom role granting access to private project
      create(:group_member, :guest, member_role: read_code_role, user: user_with_role, source: group)

      # ensure project authorizations are updated
      group.refresh_members_authorized_projects

      expect_search_results(user_with_role, scope, expected_count: 1) do |u|
        if described_class.eql?(Search::GlobalService)
          described_class.new(u, search: search, scope: scope).execute
        else
          described_class.new(u, search_level, search: search, scope: scope).execute
        end
      end
    end
  end

  context 'when access at project level' do
    it 'respects visibility', :sidekiq_inline do
      expect_search_results(user_with_role, scope, expected_count: 0) do |u|
        if described_class.eql?(Search::GlobalService)
          described_class.new(u, search: search, scope: scope).execute
        else
          described_class.new(u, search_level, search: search, scope: scope).execute
        end
      end

      # user role must be guest to test out custom role granting access to private project
      create(:project_member, :guest, project: project, user: user_with_role, member_role: read_code_role)

      expect_search_results(user_with_role, scope, expected_count: 1) do |u|
        if described_class.eql?(Search::GlobalService)
          described_class.new(u, search: search, scope: scope).execute
        else
          described_class.new(u, search_level, search: search, scope: scope).execute
        end
      end
    end
  end
end

RSpec.shared_examples 'EE search service shared examples' do |normal_results, elasticsearch_results|
  let(:params) { { search: '*' } }

  describe '#use_elasticsearch?' do
    it 'delegates to Gitlab::CurrentSettings.search_using_elasticsearch?' do
      expect(Gitlab::CurrentSettings)
        .to receive(:search_using_elasticsearch?)
        .with(scope: scope)
        .and_return(:value)

      expect(service.use_elasticsearch?).to eq(:value)
    end
  end

  describe '#execute' do
    subject { service.execute }

    it 'returns an Elastic result object when elasticsearch is enabled' do
      expect(Gitlab::CurrentSettings)
        .to receive(:search_using_elasticsearch?)
        .with(scope: scope)
        .at_least(:once)
        .and_return(true)

      is_expected.to be_a(elasticsearch_results)
    end

    it 'returns an ordinary result object when elasticsearch is disabled' do
      expect(Gitlab::CurrentSettings)
        .to receive(:search_using_elasticsearch?)
        .with(scope: scope)
        .at_least(:once)
        .and_return(false)

      is_expected.to be_a(normal_results)
    end

    describe 'advanced syntax queries for all scopes', :elastic, :sidekiq_inline do
      queries = [
        '"display bug"',
        'bug -display',
        'bug display | sound',
        'bug | (display +sound)',
        'bug find_by_*',
        'argument \-last'
      ]

      scopes = if elasticsearch_results == ::Search::Elastic::SnippetSearchResults
                 %w[
                   snippet_titles
                 ]
               else
                 %w[
                   merge_requests
                   notes
                   commits
                   blobs
                   projects
                   issues
                   wiki_blobs
                   milestones
                 ]
               end

      queries.each do |query|
        scopes.each do |scope|
          context "with query #{query} and scope #{scope}" do
            let(:params) { { search: query, scope: scope } }

            it "allows advanced query" do
              allow(Gitlab::CurrentSettings)
                .to receive(:search_using_elasticsearch?)
                .and_return(true)

              ensure_elasticsearch_index!

              results = subject
              expect(results.objects(scope)).to be_kind_of(Enumerable)
            end
          end
        end
      end
    end
  end
end

RSpec.shared_examples 'can search by title for miscellaneous cases' do |type|
  let_it_be(:searched_project, freeze: false) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:searched_group, freeze: false) { create(:group, :public) }
  let(:records_count) { 2 }

  def create_records!(type)
    case type
    when 'epics'
      create_list(:work_item, records_count, :group_level, :epic_with_legacy_epic, namespace: searched_group)
    when 'issues'
      create_list(:issue, records_count, project: searched_project)
    when 'merge_requests'
      records = []
      records_count.times { |i| records << create(:merge_request, source_branch: i, source_project: searched_project) }
      records
    end
  end

  def results(type, query)
    case type
    when 'epics'
      described_class.new(user, query, group: searched_group)
    else
      described_class.new(user, query)
    end
  end

  # rubocop:disable RSpec/InstanceVariable -- Want to reuse the @records
  before do
    @records = create_records!(type)
  end

  it 'handles plural words through algorithmic stemming', :aggregate_failures do
    @records[0].update!(title: 'remove :title attribute from submit buttons to prevent un-styled tooltips')
    @records[1].update!(title: 'smarter submit behavior for buttons groups')
    ensure_elasticsearch_index!
    results = results(type, 'button')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has umlauts', :aggregate_failures do
    @records[0].update!(title: 'köln')
    @records[1].update!(title: 'kǒln')
    ensure_elasticsearch_index!
    results = results(type, 'koln')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has dots', :aggregate_failures do
    @records[0].update!(title: 'with.dot.title')
    @records[1].update!(title: 'there is.dot')
    ensure_elasticsearch_index!
    results = results(type, 'dot')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has underscore', :aggregate_failures do
    @records[0].update!(title: 'with_underscore_text')
    @records[1].update!(title: 'some_underscore')
    ensure_elasticsearch_index!
    results = results(type, 'underscore')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has camelcase', :aggregate_failures do
    @records[0].update!(title: 'withCamelcaseTitle')
    @records[1].update!(title: 'CamelcaseText')
    ensure_elasticsearch_index!
    results = results(type, 'Camelcase')
    expect(results.objects(type)).to match_array(@records)
  end
  # rubocop:enable RSpec/InstanceVariable
end

RSpec.shared_examples 'search respects confidentiality' do |group_access: true, project_access: true,
  group_access_shared_group: true, project_access_shared_group: true, project_feature_setup: true|
  include ProjectHelpers
  include UserHelpers

  before do
    set_project_visibility_and_feature_access_level if project_feature_setup && project_access
    set_group_visibility_level if group_access

    ensure_elasticsearch_index! if ::Gitlab::CurrentSettings.elasticsearch_indexing?
  end

  # sidekiq needed for ElasticAssociationIndexerWorker
  it 'respects visibility with access at project level', :sidekiq_inline do
    skip unless project_access

    user = create_user_from_membership(project, membership)
    confidential_user_as_assignee.update!(assignees: [user]) if user
    confidential_user_as_author.update!(author: user) if user

    enable_admin_mode!(user) if admin_mode

    items = [confidential, non_confidential, confidential_user_as_assignee]
    Elastic::ProcessInitialBookkeepingService.track!(*items)
    ensure_elasticsearch_index!

    expect_search_results(user, scope, expected_count: expected_count) do |user|
      if described_class.eql?(Search::GlobalService)
        described_class.new(user, search: search, scope: scope).execute
      else
        described_class.new(user, search_level, search: search, scope: scope).execute
      end
    end
  end

  it 'respects visibility with access at group level', :sidekiq_inline do
    skip unless group_access

    user_in_group = create_user_from_membership(group, membership)
    confidential_user_as_assignee.update!(assignees: [user_in_group]) if user_in_group
    confidential_user_as_author.update!(author: user_in_group) if user_in_group

    enable_admin_mode!(user_in_group) if admin_mode

    items = [confidential, non_confidential, confidential_user_as_assignee]
    Elastic::ProcessInitialBookkeepingService.track!(*items)
    ensure_elasticsearch_index!

    expect_search_results(user_in_group, scope, expected_count: expected_count) do |user|
      if described_class.eql?(Search::GlobalService)
        described_class.new(user, search: search, scope: scope).execute
      else
        described_class.new(user, search_level, search: search, scope: scope).execute
      end
    end
  end

  it 'respects visibility with access at project level through a shared group', :sidekiq_inline do
    skip unless project_access_shared_group

    shared_with_group = create(:group)
    user_in_shared_group = create_user_from_membership(shared_with_group, membership)
    confidential_user_as_assignee.update!(assignees: [user_in_shared_group]) if user_in_shared_group
    confidential_user_as_author.update!(author: user_in_shared_group) if user_in_shared_group

    items = [confidential, non_confidential, confidential_user_as_assignee]
    Elastic::ProcessInitialBookkeepingService.track!(*items)
    ensure_elasticsearch_index!

    if Gitlab::Access.sym_options_with_owner.key?(membership)
      create(:project_group_link,
        group_access: Gitlab::Access.sym_options_with_owner[membership],
        project: project,
        group: shared_with_group
      )
    end

    enable_admin_mode!(user_in_shared_group) if admin_mode

    expect_search_results(user_in_shared_group, scope, expected_count: expected_count) do |u|
      if described_class.eql?(Search::GlobalService)
        described_class.new(u, search: search, scope: scope).execute
      else
        described_class.new(u, search_level, search: search, scope: scope).execute
      end
    end
  end

  it 'respects visibility with access at group level through a shared group', :sidekiq_inline do
    skip unless group_access_shared_group

    shared_with_group = create(:group)
    user_in_shared_group = create_user_from_membership(shared_with_group, membership)
    confidential_user_as_assignee.update!(assignees: [user_in_shared_group]) if user_in_shared_group
    confidential_user_as_author.update!(author: user_in_shared_group) if user_in_shared_group

    items = [confidential, non_confidential, confidential_user_as_assignee]
    Elastic::ProcessInitialBookkeepingService.track!(*items)
    ensure_elasticsearch_index!

    if Gitlab::Access.sym_options_with_owner.key?(membership)
      create(:group_group_link,
        group_access: Gitlab::Access.sym_options_with_owner[membership],
        shared_group: group,
        shared_with_group: shared_with_group
      )
    end

    enable_admin_mode!(user_in_shared_group) if admin_mode

    # ensure project authorizations are updated
    group.refresh_members_authorized_projects

    expect_search_results(user_in_shared_group, scope, expected_count: expected_count) do |u|
      if described_class.eql?(Search::GlobalService)
        described_class.new(u, search: search, scope: scope).execute
      else
        described_class.new(u, search_level, search: search, scope: scope).execute
      end
    end
  end

  private

  def set_group_visibility_level
    group.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))
  end

  def set_project_visibility_and_feature_access_level
    projects.each do |project|
      update_feature_access_level(
        project,
        feature_access_level,
        visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s)
      )
    end
  end
end
