# frozen_string_literal: true

RSpec.shared_examples 'a query filtered by hidden' do
  context 'when user can admin all resources' do
    before do
      allow(user).to receive(:can_admin_all_resources?).and_return(true)
    end

    it 'does not apply hidden filters' do
      assert_names_in_query(subject, without: %w[filters:not_hidden])
    end
  end

  context 'when user cannot admin all resources' do
    it 'applies hidden filters' do
      assert_names_in_query(subject, with: %w[filters:not_hidden])
    end
  end
end

RSpec.shared_examples 'a query filtered by archived' do
  context 'when include_archived is set to true' do
    let(:options) { base_options.merge(include_archived: true) }

    it 'does not apply non-archived filter' do
      assert_names_in_query(subject, without: %w[filters:non_archived])
    end
  end

  context 'when include_archived is not set' do
    it 'applies non archived filters' do
      assert_names_in_query(subject, with: %w[filters:non_archived])
    end
  end
end

RSpec.shared_examples 'a query filtered by state' do
  context 'when state option is not provided' do
    it 'does not apply state filters' do
      assert_names_in_query(subject, without: %w[filters:state])
    end
  end

  context 'when state option is provided' do
    let(:options) { base_options.merge(state: 'opened') }

    it 'applies state filters' do
      assert_names_in_query(subject, with: %w[filters:state])
    end
  end
end

RSpec.shared_examples 'a query filtered by author' do
  it 'does not apply author filters by default' do
    assert_names_in_query(build, without: %w[filters:author filters:not_author])
  end

  context 'when author_username option is provided' do
    let(:options) { base_options.merge(author_username: user.username) }

    it 'applies the filter' do
      assert_names_in_query(build, with: %w[filters:author])
    end
  end

  context 'when not_author_username option is provided' do
    let(:options) { base_options.merge(not_author_username: user.username) }

    it 'applies the filter' do
      assert_names_in_query(build, with: %w[filters:not_author])
    end
  end
end

RSpec.shared_examples 'a query filtered by labels' do
  it 'does not include labels filter by default' do
    assert_names_in_query(build, without: %w[filters:label_ids])
  end

  context 'when label_name option is provided' do
    let(:options) { base_options.merge(label_name: [label.name]) }

    it 'applies label filters' do
      assert_names_in_query(build, with: %w[filters:label_ids])
    end
  end
end

# requires authorized_project and private_project project defined in caller
RSpec.shared_examples 'a query filtered by confidentiality' do
  let(:query_name_project_membership) { 'filters:confidentiality:projects:confidential:project:membership:id' }

  context 'when user has role which allows viewing confidential data' do
    it 'applies all confidential filters' do
      assert_names_in_query(subject,
        with: %W[
          filters:confidentiality:projects:non_confidential
          filters:confidentiality:projects:confidential
          filters:confidentiality:projects:confidential:as_author
          #{query_name_project_membership}
        ])
    end

    context 'for all projects in the query' do
      let(:project_ids) { [authorized_project.id] }

      it 'does not apply the confidential filters' do
        assert_names_in_query(subject, with: %W[
          filters:confidentiality:projects:confidential
          filters:confidentiality:projects:non_confidential
          filters:confidentiality:projects:confidential:as_author
          filters:confidentiality:projects:confidential:as_assignee
          #{query_name_project_membership}
        ])
      end
    end
  end

  context 'when user does not have role' do
    let(:project_ids) { [private_project.id] }

    it 'applies all confidential filters' do
      assert_names_in_query(subject, with: %W[
        filters:confidentiality:projects:non_confidential
        filters:confidentiality:projects:confidential
        filters:confidentiality:projects:confidential:as_author
        filters:confidentiality:projects:confidential:as_assignee
        #{query_name_project_membership}
      ])
    end
  end

  context 'when there is no user' do
    let(:user) { nil }
    let(:project_ids) { [private_project.id] }

    it 'only applies the non-confidential filter' do
      assert_names_in_query(subject, with: %w[filters:confidentiality:projects:non_confidential],
        without: %W[
          filters:confidentiality:projects:confidential
          filters:confidentiality:projects:confidential:as_author
          filters:confidentiality:projects:confidential:as_assignee
          #{query_name_project_membership}
        ])
    end
  end
end

# requires group, authorized_project and private_project project defined in caller
RSpec.shared_examples 'a query filtered by project authorization' do
  context 'for global search' do
    let(:options) do
      base_options.merge(search_level: :global, project_ids: [authorized_project.id, private_project.id])
    end

    it 'applies authorization filters' do
      assert_names_in_query(build, with: %w[filters:permissions:global:project_visibility_level:public_and_internal])
    end

    context 'when project_ids is passed :any' do
      let(:options) do
        base_options.merge(search_level: :global, project_ids: [authorized_project.id, private_project.id])
      end

      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:permissions:global:project_visibility_level:public_and_internal],
          without: %w[filters:level:group:project_visibility_level:public_and_internal
            filters:permissions:group
            filters:level:project
            filters:permissions:project])
      end
    end
  end

  context 'for group search' do
    let(:options) do
      base_options.merge(search_level: :group, group_ids: [group.id],
        project_ids: [authorized_project.id, private_project.id])
    end

    it 'applies authorization filters' do
      assert_names_in_query(build, with: %w[filters:level:group
        filters:permissions:group:project_visibility_level:public_and_internal],
        without: %w[filters:permissions:global:project_visibility_level:public_and_internal
          filters:level:project
          filters:permissions:project:project_visibility_level:public_and_internal])
    end
  end

  context 'for project search' do
    let(:options) do
      base_options.merge(search_level: :project, project_ids: [authorized_project.id], group_ids: [group.id])
    end

    it 'applies authorization filters' do
      assert_names_in_query(build, with: %w[filters:level:project
        filters:permissions:project:project_visibility_level:public_and_internal],
        without: %w[filters:permissions:global:project_visibility_level:public_and_internal
          filters:level:group
          filters:permissions:group:project_visibility_level:public_and_internal])
    end
  end
end
