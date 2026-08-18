# frozen_string_literal: true

require "spec_helper"

RSpec.describe Types::Namespaces::LinkPaths::ProjectNamespaceLinksType, feature_category: :shared do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  subject(:type) { described_class.resolve_type(namespace, {}) }

  it_behaves_like "expose all link paths fields for the namespace" do
    let(:type_specific_fields) do
      %i[newWorkItemEmailAddress releasesPath projectImportJiraPath rssPath calendarPath exportCsvPath]
    end
  end

  shared_examples "project namespace link paths values" do
    it_behaves_like "common namespace link paths values"
    it_behaves_like "new trial path behavior" do
      let(:expected_namespace_id) { group.id }
    end

    where(:field, :value) do
      :epics_list | lazy { "/groups/#{group.full_path}/-/epics" }
      :group_issues | lazy { "/groups/#{group.full_path}/-/issues" }
      :labels_fetch | lazy do
        "/#{project.full_path}/-/labels.json?include_ancestor_groups=true&only_group_labels=true"
      end
    end

    with_them do
      it { expect(resolve_field(field, namespace, current_user: user)).to eq(value) }
    end

    it 'returns work_items settings path' do
      expect(resolve_field(:issues_settings, namespace, current_user: user))
        .to eq("/groups/#{namespace.root_ancestor.full_path}/-/settings/work_items")
    end
  end

  context "when fetching public project" do
    let_it_be(:group) { create(:group, :nested, :public) }
    let_it_be(:project) { create(:project, :public, group: group) }
    let_it_be(:namespace) { project.project_namespace }

    it_behaves_like "project namespace link paths values"
  end

  context "when fetching private project" do
    let_it_be(:group) { create(:group, :nested, :private) }
    let_it_be(:project) { create(:project, :private, group: group) }
    let_it_be(:namespace) { project.project_namespace }

    context "when user is not a member of the project" do
      it_behaves_like "project namespace link paths values"
    end

    context "when user is a member of the project" do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like "project namespace link paths values"
    end
  end
end
