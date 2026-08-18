# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'graphql queries', feature_category: :api do
  include GraphqlQueryComplexityHelper

  complexity_overrides = {
    # Project management: https://gitlab.com/gitlab-org/gitlab/-/issues/584292
    'app/assets/javascripts/boards/graphql/lists_issues.query.graphql' => 590,
    'app/assets/javascripts/work_items/graphql/notes/work_item_notes_by_iid.query.graphql' => 450,
    'ee/app/assets/javascripts/boards/graphql/lists_epics_with_color.query.graphql' => 370,
    'ee/app/assets/javascripts/iterations/queries/iteration_issues_with_label_filter.query.graphql' => 310,

    # Work item query has a conditional that includes a new field, but this is only when
    # a feature flag is on. These tests do not account for conditional fields so we
    # make the limit higher while we develop https://gitlab.com/gitlab-org/gitlab/-/issues/587972
    # The list query uses a slim features fragment (WorkItemsListFeatures) that only includes
    # fields needed for the list view, so this override should not need to increase as new
    # features are added to the full WorkItemFeatures fragment used in the detail view.
    'app/assets/javascripts/work_items/list/graphql/get_work_items_full.query.graphql' => 360,
    'ee/app/assets/javascripts/work_items/list/graphql/get_work_items_full.query.graphql' => 360,
    'app/assets/javascripts/work_items/graphql/work_item_by_id.query.graphql' => 280,
    'app/assets/javascripts/work_items/graphql/work_item_by_iid.query.graphql' => 285,
    'app/assets/javascripts/work_items/graphql/add_linked_items.mutation.graphql' => 270,
    'app/assets/javascripts/work_items/graphql/create_work_item.mutation.graphql' => 275,
    'app/assets/javascripts/work_items/graphql/move_work_item.mutation.graphql' => 280,
    'app/assets/javascripts/work_items/graphql/update_work_item.mutation.graphql' => 275,
    'app/assets/javascripts/work_items/graphql/work_item_convert.mutation.graphql' => 275,
    'app/assets/javascripts/work_items/graphql/work_item_updated.subscription.graphql' => 275,

    # Code review: https://gitlab.com/gitlab-org/gitlab/-/issues/584293
    'app/assets/javascripts/ci/merge_requests/graphql/queries/get_merge_request_pipelines.query.graphql' => 604,
    'app/assets/javascripts/analytics/merge_request_analytics/graphql/queries/throughput_table.query.graphql' => 320,

    # False positive: the analyzer scores every @include facet at once, but only one is ever on.
    # MCP server: https://gitlab.com/gitlab-org/gitlab/-/issues/605878
    'app/graphql/queries/mcp/merge_requests/get_merge_request.query.graphql' => 260,

    # Package registry: https://gitlab.com/gitlab-org/gitlab/-/issues/584294
    'app/assets/javascripts/packages_and_registries/package_registry/graphql/queries/get_packages.query.graphql' => 277,

    # Adding `duoSastVrWorkflowEnabled` to the shared `VulnerabilityBaseFields`
    # fragment raised each of these limits by 10.
    # See: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/235353
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/group_vulnerabilities.query.graphql' => 320,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/instance_vulnerabilities.query.graphql' => 310,
    'ee/app/assets/javascripts/security_dashboard/graphql/queries/project_vulnerabilities.query.graphql' => 350,

    # Security Platform Management: https://gitlab.com/gitlab-org/gitlab/-/issues/584297
    'ee/app/assets/javascripts/security_inventory/graphql/subgroups_and_projects.query.graphql' => 340,

    # Security Policies: PolicyScopeList fans out per-category attribute connections
    # (BusinessImpact, Application, BusinessUnit, Exposure for both including/excluding),
    # each selecting `count` so the UI can render a "+ N more" total while loading only
    # the first few nodes. Will collapse to a single field once
    # https://gitlab.com/gitlab-org/gitlab/-/issues/596686 ships.
    'ee/app/assets/javascripts/security_orchestration/graphql/queries/' \
      'group_security_policies.query.graphql' => 320,
    'ee/app/assets/javascripts/security_orchestration/graphql/queries/' \
      'project_security_policies.query.graphql' => 320,

    # Organizations: https://gitlab.com/gitlab-org/gitlab/-/issues/584299
    # This is a false-positive as the two large fields (contributedProjects and starredProjects) are
    # activated conditionally. This has a much lower complexity score in practice.
    'app/assets/javascripts/projects/your_work/graphql/queries/user_projects.query.graphql' => 263,

    # Pipeline execution: https://gitlab.com/gitlab-org/gitlab/-/issues/584301
    'app/assets/javascripts/ci/pipelines_page/graphql/queries/get_pipelines.query.graphql' => 315,
    'app/assets/javascripts/ci/commit/graphql/queries/get_commit_pipelines.query.graphql' => 271
  }

  describe 'complexity' do
    Gitlab::Graphql::Queries.all.each do |definition| # rubocop:disable Rails/FindEach -- Not an ActiveRecord relation
      relative_path = definition.file.delete_prefix("#{Rails.root}/") # rubocop:disable Rails/FilePath -- Can't be used to append '/'

      describe relative_path do
        it 'does not exceed complexity limit' do
          limit = complexity_overrides.fetch(relative_path, GitlabSchema::AUTHENTICATED_MAX_COMPLEXITY)

          expect(definition.complexity(GitlabSchema)).to be < limit
        end
      end
    end
  end

  # The work items list queries include a features field behind @include(if: $useWorkItemFeatures).
  # When the work_item_features_field feature flag is enabled globally, unauthenticated users
  # will also have the features field included, so we need to ensure the query complexity stays
  # within the unauthenticated limit i.e. < DEFAULT_MAX_COMPLEXITY (200).
  describe 'work items list query complexity with workItem.features field enabled' do
    %w[
      app/assets/javascripts/work_items/list/graphql/get_work_items_full.query.graphql
      ee/app/assets/javascripts/work_items/list/graphql/get_work_items_full.query.graphql
    ].each do |query_path|
      describe query_path do
        let(:definition) { Gitlab::Graphql::Queries.find(Rails.root.join(query_path)).first }

        def query_complexity(query_text, variables)
          query = GraphQL::Query.new(GitlabSchema, query_text, variables: variables)
          GraphQL::Analysis.analyze_query(query, [GraphQL::Analysis::QueryComplexity]).first
        end

        it 'does not exceed unauthenticated max complexity without features' do
          complexity = query_complexity(definition.text, { "useWorkItemFeatures" => false })

          expect(complexity).to be < GitlabSchema::DEFAULT_MAX_COMPLEXITY
        end

        it 'does not exceed unauthenticated max complexity with features at default page size' do
          complexity = query_complexity(definition.text, {
            "useWorkItemFeatures" => true,
            "firstPageSize" => 20
          })

          expect(complexity).to be < GitlabSchema::DEFAULT_MAX_COMPLEXITY
        end

        # This documents a known limitation while widgets are being migrated to use
        # the features field. The query currently dual-fetches both widgets and features,
        # which exceeds the unauthenticated complexity limit at higher page sizes.
        # Once all widgets are migrated and @skip(if: $useWorkItemFeatures) is added to
        # the widgets field, this test should be updated to expect complexity < limit.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/587972
        it 'exceeds unauthenticated max complexity with features at higher page sizes' do
          complexity = query_complexity(definition.text, {
            "useWorkItemFeatures" => true,
            "firstPageSize" => 50
          })

          expect(complexity).to be >= GitlabSchema::DEFAULT_MAX_COMPLEXITY
        end
      end
    end
  end

  # The work item detail queries include a features field behind @include(if: $useWorkItemFeatures).
  # When the work_item_features_field feature flag is enabled, the query complexity must stay within
  # the cap for both authenticated regular users and admins. This guards against regressions where
  # adding fields to the WorkItemFeatures fragment pushes complexity past the cap.
  #
  # Note: The query currently exceeds the unauthenticated max complexity (DEFAULT_MAX_COMPLEXITY)
  # because widgets[] is still dual-fetched alongside features[] for fields not yet @skip'd.
  # This is a known limitation that will be resolved once all widgets are migrated to features
  # and the widgets[] selection is removed entirely.
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/587972
  describe 'work item detail/mutation query complexity with workItem.features field enabled' do
    # `query_complexity_with_typename` injects `__typename` (as Apollo Client does at
    # runtime) so these guards reflect the real complexity the server evaluates. The raw
    # query text under-counts and hid real breaches (the detail query measured 240 here
    # but was 255 in production). We assert `<=` the limit since the server only rejects
    # queries that *exceed* it.
    #
    # Every document that returns a full work item payload is listed, since they all pull
    # in the same widgets/features fragments and therefore all sit close to the limit.
    %w[
      app/assets/javascripts/work_items/graphql/work_item_by_iid.query.graphql
      app/assets/javascripts/work_items/graphql/work_item_by_id.query.graphql
      app/assets/javascripts/work_items/graphql/create_work_item.mutation.graphql
      app/assets/javascripts/work_items/graphql/update_work_item.mutation.graphql
      app/assets/javascripts/work_items/graphql/work_item_convert.mutation.graphql
      app/assets/javascripts/work_items/graphql/move_work_item.mutation.graphql
      app/assets/javascripts/work_items/graphql/add_linked_items.mutation.graphql
      app/assets/javascripts/work_items/graphql/work_item_updated.subscription.graphql
    ].each do |query_path|
      describe query_path do
        let(:definition) { Gitlab::Graphql::Queries.find(Rails.root.join(query_path)).first }

        it 'does not exceed authenticated max complexity with features enabled' do
          complexity = query_complexity_with_typename(definition.text, { "useWorkItemFeatures" => true })

          expect(complexity).to be <= GitlabSchema::AUTHENTICATED_MAX_COMPLEXITY
        end

        it 'does not exceed admin max complexity with features enabled' do
          complexity = query_complexity_with_typename(definition.text, { "useWorkItemFeatures" => true })

          expect(complexity).to be <= GitlabSchema::ADMIN_MAX_COMPLEXITY
        end
      end
    end
  end

  complexity_overrides.each_key do |file|
    describe "complexity override for #{file}" do
      it 'references an existing file' do
        # Remove the file from the override list to pass this test.
        expect(File.exist?(Rails.root.join(file))).to be(true)
      end
    end
  end
end
