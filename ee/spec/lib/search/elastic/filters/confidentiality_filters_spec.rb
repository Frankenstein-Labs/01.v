# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Filters::ConfidentialityFilters, :elastic_helpers,
  feature_category: :global_search do
  include_context 'with filters shared context'
  let_it_be_with_reload(:user) { create(:user) }

  let(:test_klass) do
    Class.new do
      include Search::Elastic::Filters::ConfidentialityFilters
    end
  end

  let(:expected_query) do
    json = File.read(Rails.root.join(fixtures_path, fixture_file))
    # the traversal_id for the group the user has access to
    json.gsub!('__NAMESPACE_ANCESTRY__', namespace_ancestry) if defined?(namespace_ancestry)
    # the traversal_id for the shared group the user has access to
    json.gsub!('__SHARED_NAMESPACE_ANCESTRY__', shared_namespace_ancestry) if defined?(shared_namespace_ancestry)
    # the id for the group the user has access to
    json.gsub!('__NAMESPACE_ID__', namespace_id.to_s) if defined?(namespace_id)
    # the traversal_id for the shared group the user has access to
    json.gsub!('__SHARED_NAMESPACE_ID__', shared_namespace_id.to_s) if defined?(shared_namespace_id)
    # the id for the project the user has access to
    json.gsub!('__PROJECT_ID__', project_id.to_s) if defined?(project_id)
    # the id for the user
    json.gsub!('__USER_ID__', user_id.to_s) if defined?(user_id)

    ::Gitlab::Json.parse(json).deep_symbolize_keys
  end

  describe '.by_group_level_confidentiality' do
    let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_group_level_confidentiality' }

    let(:base_options) do
      {
        current_user: user,
        search_level: 'global',
        min_access_level_confidential_public_internal: ::Gitlab::Access::GUEST,
        min_access_level_confidential: ::Gitlab::Access::PLANNER
      }
    end

    let(:options) { base_options }

    subject(:by_group_level_confidentiality) do
      test_klass.by_group_level_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when options[:confidential] is not passed or not true/false' do
      context 'when user.can_read_all_resources? is true' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when user has the role set in option :min_access_level_confidential for group' do
        context 'for a top level group' do
          let(:fixture_file) { 'user_access_to_group_with_confidential_access.json' }
          let_it_be(:group) { create(:group, :private, planners: user) }
          let(:namespace_ancestry) { group.elastic_namespace_ancestry }
          let(:user_id) { user.id }

          it { is_expected.to eq(expected_query) }
        end

        context 'for a sub group' do
          let(:fixture_file) { 'user_access_to_group_with_confidential_access.json' }

          let_it_be(:parent_group) { create(:group, :private) }
          let_it_be(:group) { create(:group, :private, parent: parent_group, planners: user) }
          let(:namespace_ancestry) { group.elastic_namespace_ancestry }
          let(:user_id) { user.id }

          it { is_expected.to eq(expected_query) }
        end

        context 'for group through shared group permission' do
          let(:fixture_file) { 'user_access_to_group_through_shared_group_with_confidential_access.json' }

          let_it_be(:shared_group) { create(:group, :private, planners: user) }
          let_it_be(:group) { create(:group) }
          let_it_be(:group_link) do
            create(:group_group_link, :planner, shared_group: group, shared_with_group: shared_group)
          end

          let(:user_id) { user.id }
          let(:shared_namespace_ancestry) { shared_group.elastic_namespace_ancestry }
          let(:namespace_ancestry) { group.elastic_namespace_ancestry }

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when current_user is nil' do
        let(:fixture_file) { 'anonymous_user.json' }
        let(:options) { base_options.merge(current_user: nil) }

        it { is_expected.to eq(expected_query) }
      end

      context 'when current_user does not have any role which allows private group access' do
        let(:fixture_file) { 'user_no_confidential_access.json' }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }

        context 'and user is external' do
          let(:fixture_file) { 'user_no_confidential_access.json' }

          before do
            allow(user).to receive(:external?).and_return(true)
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when user has GUEST permission for a project in the group hierarchy' do
        let(:fixture_file) { 'user_access_to_project_with_non_confidential_access.json' }

        let_it_be(:group) { create(:group, :private) }
        let_it_be(:sub_group) { create(:group, :private, parent: group) }
        let_it_be(:project) { create(:project, :private, group: sub_group, guests: user) }
        let(:namespace_id) { group.id }
        let(:shared_namespace_id) { sub_group.id }
        let(:user_id) { user.id }
        let(:namespace_ancestry) { sub_group.elastic_namespace_ancestry }

        it { is_expected.to eq(expected_query) }

        context 'and user also has GUEST permission to the top level group' do
          let(:fixture_file) { 'user_access_to_group_and_project_with_non_confidential_access.json' }
          let(:namespace_ancestry) { group.elastic_namespace_ancestry }

          before_all do
            group.add_guest(user)
          end

          it { is_expected.to eq(expected_query) }
        end
      end
    end

    context 'when options[:confidential] is set' do
      let(:options) { base_options.merge(confidential: true) }

      context 'when user.can_read_all_resources? is true' do
        let(:fixture_file) { 'admin_user_with_confidential_selected.json' }

        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it { is_expected.to eq(expected_query) }
      end

      context 'when current_user is nil' do
        let(:fixture_file) { 'anonymous_user_with_confidential_selected.json' }
        let(:user) { nil }

        it { is_expected.to eq(expected_query) }
      end

      context 'when current_user has no access' do
        let(:fixture_file) { 'user_no_confidential_access_with_confidential_selected.json' }

        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }
      end

      context 'when current_user has any level of access' do
        let(:fixture_file) { 'user_access_to_group_with_confidential_access_with_confidential_selected.json' }

        let_it_be(:group) { create(:group, :private, planners: user) }
        let(:namespace_ancestry) { group.elastic_namespace_ancestry }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }
      end
    end
  end

  describe '.by_project_confidentiality' do
    let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_project_level_confidentiality' }

    let_it_be(:authorized_group) { create(:group, developers: [user]) }
    let_it_be(:authorized_project) { create(:project, group: authorized_group, developers: [user]) }
    let_it_be(:private_group) { create(:group, :private) }
    let_it_be(:private_project) { create(:project, :private, group: private_group) }

    subject(:by_project_confidentiality) do
      test_klass.by_project_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when options[:confidential] is not passed or not true/false' do
      let(:base_options) do
        {
          min_access_level_confidential_public_internal: ::Gitlab::Access::GUEST,
          min_access_level_confidential: ::Gitlab::Access::PLANNER,
          current_user: user,
          search_level: 'global'
        }
      end

      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end

      context 'for global search' do
        let(:fixture_file) { 'user_with_access.json' }
        let(:project_id) { authorized_project.id }
        let(:namespace_ancestry) { authorized_group.elastic_namespace_ancestry }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }

        context 'when user does not have access' do
          let(:user) { create(:user) }
          let(:fixture_file) { 'user_no_access.json' }
          let(:user_id) { user.id }
          let(:options) { base_options.merge(search_level: 'global') }

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'for group search' do
        context 'when user has access' do
          let(:fixture_file) { 'user_with_access.json' }
          let(:options) { base_options.merge(search_level: 'group', group_ids: [authorized_group.id]) }
          let(:user_id) { user.id }
          let(:project_id) { authorized_project.id }
          let(:namespace_ancestry) { authorized_group.elastic_namespace_ancestry }

          it { is_expected.to eq(expected_query) }
        end

        context 'when user does not have access' do
          let(:fixture_file) { 'user_no_access.json' }
          let(:user_id) { user.id }
          let(:options) { base_options.merge(search_level: 'group', group_ids: [private_group.id]) }

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'for project search' do
        context 'when user has access' do
          let(:fixture_file) { 'user_with_access.json' }
          let(:options) do
            base_options.merge(search_level: 'project',
              project_ids: [authorized_project.id], group_ids: [authorized_group.id])
          end

          let(:user_id) { user.id }
          let(:project_id) { authorized_project.id }
          let(:namespace_ancestry) { authorized_group.elastic_namespace_ancestry }

          it { is_expected.to eq(expected_query) }
        end

        context 'when user does not have access' do
          let(:fixture_file) { 'user_no_access.json' }
          let(:user_id) { user.id }
          let(:options) do
            base_options.merge(search_level: 'project',
              project_ids: [private_project.id], group_ids: [private_group.id])
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when options[:current_user] is empty' do
        let(:fixture_file) { 'anonymous_user.json' }
        let(:options) { base_options.merge(current_user: nil) }

        it { is_expected.to eq(expected_query) }
      end
    end

    context 'when options[:confidential] is passed' do
      let(:base_options) do
        {
          current_user: user,
          confidential: true,
          search_level: 'global',
          min_access_level_confidential_public_internal: ::Gitlab::Access::GUEST,
          min_access_level_confidential: ::Gitlab::Access::PLANNER
        }
      end

      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        let(:fixture_file) { 'admin_user.json' }

        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it { is_expected.to eq(expected_query) }
      end

      context 'for global search' do
        let(:fixture_file) { 'user_with_access_with_confidential_selected.json' }
        let(:project_id) { authorized_project.id }
        let(:namespace_ancestry) { authorized_group.elastic_namespace_ancestry }
        let(:user_id) { user.id }

        it { is_expected.to eq(expected_query) }

        context 'when user does not have access' do
          let(:user) { create(:user) }
          let(:fixture_file) { 'user_no_access_with_confidential_selected.json' }
          let(:user_id) { user.id }
          let(:options) { base_options.merge(search_level: 'global') }

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'for group search' do
        context 'when user has access' do
          let(:fixture_file) { 'user_with_access_with_confidential_selected.json' }
          let(:options) { base_options.merge(search_level: 'group', group_ids: [authorized_group.id]) }
          let(:user_id) { user.id }
          let(:project_id) { authorized_project.id }
          let(:namespace_ancestry) { authorized_group.elastic_namespace_ancestry }

          it { is_expected.to eq(expected_query) }
        end

        context 'when user does not have access' do
          let(:fixture_file) { 'user_no_access_with_confidential_selected.json' }
          let(:user_id) { user.id }
          let(:options) { base_options.merge(search_level: 'group', group_ids: [private_group.id]) }

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'for project search' do
        context 'when user has access' do
          let(:fixture_file) { 'user_with_access_with_confidential_selected.json' }
          let(:options) do
            base_options.merge(search_level: 'project',
              project_ids: [authorized_project.id], group_ids: [authorized_group.id])
          end

          let(:user_id) { user.id }
          let(:project_id) { authorized_project.id }
          let(:namespace_ancestry) { authorized_group.elastic_namespace_ancestry }

          it { is_expected.to eq(expected_query) }
        end

        context 'when user does not have access' do
          let(:fixture_file) { 'user_no_access_with_confidential_selected.json' }
          let(:user_id) { user.id }
          let(:options) do
            base_options.merge(search_level: 'project',
              project_ids: [private_project.id], group_ids: [private_group.id])
          end

          it { is_expected.to eq(expected_query) }
        end
      end

      context 'when options[:current_user] is empty' do
        let(:fixture_file) { 'anonymous_user_with_confidentiality_selected.json' }
        let(:options) { base_options.merge(current_user: nil) }

        it { is_expected.to eq(expected_query) }
      end
    end
  end

  describe '.by_combined_confidentiality' do
    let(:options) do
      {
        min_access_level_confidential_public_internal: ::Gitlab::Access::GUEST,
        min_access_level_confidential: ::Gitlab::Access::PLANNER,
        search_level: :global,
        current_user: user
      }
    end

    let_it_be(:authorized_project) { create(:project, developers: user) }

    subject(:by_combined_confidentiality) do
      test_klass.by_combined_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when neither use_project_authorization nor use_group_authorization is provided' do
      it_behaves_like 'does not modify the query_hash'
    end

    context 'when use_project_authorization is true' do
      let(:options) { super().merge(use_project_authorization: true) }

      it 'calls by_project_confidentiality with use_project_authorization options' do
        expect(test_klass).to receive(:by_project_confidentiality).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect { by_combined_confidentiality }.not_to raise_error
      end

      it 'only adds project filters' do
        filter = by_combined_confidentiality.dig(:query, :bool, :filter)
        expect(filter).to be_present

        assert_names_in_query(filter,
          with: %w[filters:confidentiality:projects:non_confidential
            filters:confidentiality:projects:confidential
            filters:confidentiality:projects:private:project:member],
          without: %w[filters:confidentiality:groups:non_confidential
            filters:confidentiality:groups:confidential
            filters:confidentiality:groups:private:ancestry_filter:descendants])
      end
    end

    context 'when use_group_authorization is true' do
      let(:options) do
        super().merge(use_group_authorization: true,
          min_access_level_confidential_public_internal: ::Gitlab::Access::GUEST,
          min_access_level_confidential: ::Gitlab::Access::PLANNER)
      end

      it 'calls by_group_level_confidentiality with use_group_authorization options' do
        expect(test_klass).to receive(:by_group_level_confidentiality).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect { by_combined_confidentiality }.not_to raise_error
      end

      it 'removes features from group options' do
        options_with_features = options.merge(use_group_authorization: true, features: [:issues])

        expect(test_klass).to receive(:by_group_level_confidentiality).once do |args|
          expect(args[:options]).not_to have_key(:features)
        end

        test_klass.by_combined_confidentiality(query_hash: query_hash, options: options_with_features)
      end

      it 'only adds group filters' do
        filter = by_combined_confidentiality.dig(:query, :bool, :filter)
        expect(filter).to be_present

        assert_names_in_query(filter,
          with: %w[filters:confidentiality:groups:non_confidential
            filters:confidentiality:groups:confidential
            filters:confidentiality:groups:private:ancestry_filter:descendants],
          without: %w[
            filters:confidentiality:projects:non_confidential
            filters:confidentiality:projects:confidential
            filters:confidentiality:projects:confidential:as_author
            filters:confidentiality:projects:project:member
            filters:confidentiality:projects:confidential:as_assignee
          ]
        )
      end
    end

    context 'when both use_project_authorization and use_group_authorization are true' do
      let(:options) do
        super().merge(use_project_authorization: true, use_group_authorization: true,
          min_access_level_confidential_public_internal: ::Gitlab::Access::GUEST)
      end

      it 'calls both underlying methods' do
        expect(test_klass).to receive(:by_project_confidentiality).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect(test_klass).to receive(:by_group_level_confidentiality).once
          .with(hash_including(query_hash: kind_of(Search::Elastic::BoolExpr),
            options: hash_including(filter_path: [:filter])))
          .and_call_original

        expect { by_combined_confidentiality }.not_to raise_error
      end

      it 'creates a combined filter with should clauses' do
        result = by_combined_confidentiality
        filter = result.dig(:query, :bool, :filter)

        expect(filter).to be_an(Array)
        expect(filter.first).to have_key(:bool)
        expect(filter.first[:bool]).to have_key(:should)
        expect(filter.first[:bool][:should].length).to eq(2)
        assert_names_in_query(filter, with: %w[
          filters:confidentiality:projects:non_confidential
          filters:confidentiality:projects:confidential
          filters:confidentiality:projects:private:project:member
          filters:confidentiality:groups:non_confidential
          filters:confidentiality:groups:confidential
          filters:confidentiality:groups:private:ancestry_filter:descendants
        ])
      end
    end
  end

  describe '.by_note_confidentiality' do
    let(:fixtures_path) { 'ee/spec/fixtures/search/elastic/filters/by_note_confidentiality' }

    let_it_be(:authorized_group) { create(:group, reporters: [user]) }
    let_it_be(:authorized_project) { create(:project, group: authorized_group, reporters: [user]) }

    let(:base_options) do
      {
        current_user: user,
        search_level: 'global',
        min_access_level_confidential: ::Gitlab::Access::REPORTER,
        min_access_level_confidential_public_internal: ::Gitlab::Access::REPORTER
      }
    end

    let(:options) { base_options }

    subject(:by_note_confidentiality) do
      test_klass.by_note_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when user.can_read_all_resources? is true' do
      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when current_user is nil' do
      let(:fixture_file) { 'anonymous_user.json' }
      let(:options) { base_options.merge(current_user: nil) }

      it { is_expected.to eq(expected_query) }
    end

    context 'when current_user has access' do
      let(:fixture_file) { 'user_with_access.json' }
      let(:user_id) { user.id }
      let(:project_id) { authorized_project.id }
      let(:namespace_ancestry) { authorized_group.elastic_namespace_ancestry }

      it { is_expected.to eq(expected_query) }
    end

    context 'when current_user has no access to any projects' do
      let(:fixture_file) { 'user_no_access.json' }
      let(:user) { create(:user) }
      let(:user_id) { user.id }

      it { is_expected.to eq(expected_query) }
    end
  end
end
