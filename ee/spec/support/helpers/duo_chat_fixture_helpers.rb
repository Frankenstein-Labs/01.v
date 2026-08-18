# frozen_string_literal: true

module DuoChatFixtureHelpers
  def restore_epic(epic)
    return if Epic.exists?(epic[:data][:id])

    # Create ancestor epics
    restore_epic(epic_fixtures.find { |e| e[:data][:id] == epic[:data][:parent_id] }) if epic[:data][:parent_id]

    # Create the epic's group and the group's direct ancestors.
    root_group = epic[:namespace_hierarchy].first
    parent = if Group.exists?(root_group[:id])
               Group.find(root_group[:id])
             else
               create(:group_with_plan, id: root_group[:id], name: root_group[:name], path: root_group[:path],
                 plan: :ultimate_plan)
             end

    epic[:namespace_hierarchy][1..].each do |namespace|
      parent = if Group.exists?(namespace[:id])
                 Group.find(namespace[:id])
               else
                 create(:group, id: namespace[:id], name: namespace[:name], path: namespace[:path], parent: parent)
               end
    end

    # Create sourcing milestones
    sourcing_milestones = [epic[:start_date_sourcing_milestone], epic[:due_date_sourcing_milestone]].compact
    sourcing_milestones.each { |milestone| create(:milestone, **milestone) unless Milestone.exists?(milestone[:id]) }

    # Create labels
    create_labels(epic)

    # Create epic
    created_epic = create(:epic, **epic[:data].except(:start_date_sourcing_epic_id, :due_date_sourcing_epic_id))

    # Create notes
    epic[:notes].each { |note_attrs| create(:note, **note_attrs) }

    created_epic
  end

  # rubocop: disable Metrics/AbcSize
  def restore_issue(issue)
    return if Issue.exists?(issue[:data][:id])

    # Create the parent/ancestor groups for the issue's project
    root_group = issue[:namespace_hierarchy].first
    parent = if Group.exists?(root_group[:id])
               Group.find(root_group[:id])
             else
               create(:group_with_plan, id: root_group[:id], name: root_group[:name], path: root_group[:path],
                 plan: :ultimate_plan)
             end

    issue[:namespace_hierarchy][1..-2].each do |namespace|
      parent = if Group.exists?(namespace[:id])
                 Group.find(namespace[:id])
               else
                 create(:group, id: namespace[:id], name: namespace[:name], path: namespace[:path], parent: parent)
               end
    end

    #  project is the leaf node in a hierarchy so it should be last entry.
    project = issue[:namespace_hierarchy].last

    # Create the issue's project
    unless Project.exists?(project[:id])
      create(:project,
        id: project[:id],
        name: project[:name],
        project_namespace_id: project[:project_namespace_id],
        path: project[:path],
        group: parent
      )
    end

    # Create milestone
    create(:milestone, **issue[:milestone]) if issue[:milestone] && !Milestone.exists?(issue[:milestone][:id])

    # Create iteration
    if issue[:iteration]
      unless Iterations::Cadence.exists?(issue[:iterations_cadence][:id])
        create(:iterations_cadence, **issue[:iterations_cadence].except(:start_date)).tap do |cadence|
          cadence.update_attribute(:start_date, issue[:iterations_cadence][:start_date])
        end
      end

      create(:iteration, **issue[:iteration]) unless Iteration.exists?(issue[:iteration][:id])
    end

    # Create labels
    create_labels(issue)

    # Create issue
    issue_attrs = issue[:data].merge!({
      work_item_type_id: build(:work_item_system_defined_type, :issue).id
    })
    created_issue = create(:issue, **issue_attrs)

    # Create notes
    issue[:notes].each { |note_attrs| create(:note, **note_attrs) }

    created_issue
  end
  # rubocop: enable Metrics/AbcSize

  def create_labels(issuable)
    issuable[:labels]
      .map { |label_attrs| label_attrs.except(:author) }
      .each do |label_attrs|
        # The label might have been created already from another fixture.
        label = label_attrs[:group_id] ? :group_label : :label
        create(label, **label_attrs) unless Label.exists?(label_attrs[:id])
      end
  end

  def create_users(issuable)
    users_to_create = issuable[:note_authors]
      .append(issuable[:author])
      .uniq { |author| author[:id] }
      # The user might have been created already from another fixture.
      .reject { |author| User.exists?(author[:id]) }

    users_to_create.each do |user_attrs|
      # The current User model prohibits a special character (e.g., _ or -) as the trailing character -
      # but usernames that violate the constraint exist in production.
      create(:user, id: user_attrs[:id], name: user_attrs[:name])
        .tap { |user| user.update_attribute(:username, user_attrs[:username]) }
    end
  end

  def load_fixture(object_type)
    fixture_dir = Rails.root.join('ee/spec/fixtures/llm')
    fixture_path = File.join(fixture_dir, object_type)

    Dir.entries(fixture_path)
      .select { |f| f.match(/.json/) }
      .map { |f| File.join(fixture_path, f) }
      .map { |f| Gitlab::Json.parse(File.read(f)) }
      .map(&:deep_symbolize_keys)
  end

  def vertex_embedding_fixture
    load_fixture('embeddings').first[:embedding].map(&:to_f)
  end
end
