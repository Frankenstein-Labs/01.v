# frozen_string_literal: true

# TODO: this needs to be migrated to using 2 gitlab instances
# however currently it's not possible to add license to the second source instance
module QA
  RSpec.describe "Manage", feature_category: :importers do
    include_context "with gitlab group migration"

    describe "Gitlab migration", :import, :orchestrated, requires_admin: 'creates a user via API' do
      context "with EE features" do
        let(:source_iteration) do
          create(:group_iteration,
            api_client: source_admin_api_client,
            group: source_group,
            description: "Import test iteration for group #{source_group.name}")
        end

        let(:source_epics) { source_group.work_item_epics }
        let(:imported_epics) { imported_group.work_item_epics }

        let(:label_one) do
          create(:group_label, api_client: source_admin_api_client, group: source_group, title: 'label one')
        end

        let(:label_two) do
          create(:group_label, api_client: source_admin_api_client, group: source_group, title: 'label two')
        end

        # Find epic by title
        #
        # @param [Array] epics
        # @param [String] title
        # @return [EE::Resource::WorkItemEpic]
        def find_epic(epics, title)
          epics.find { |epic| epic.title == title }
        end

        before do
          create(:license, license: Runtime::Env.ee_license, api_client: source_admin_api_client)

          parent_epic = create(:work_item_epic,
            api_client: source_admin_api_client,
            group: source_group,
            title: 'Parent epic')
          child_epic = create(:work_item_epic,
            :confidential,
            api_client: source_admin_api_client,
            group: source_group,
            title: 'Child epic',
            label_ids: [label_one.id, label_two.id],
            parent_id: parent_epic.id)

          child_epic.award_emoji("thumbsup")
          child_epic.award_emoji("thumbsdown")

          source_iteration
        end

        it 'imports group epics and iterations' do
          expect_group_import_finished_successfully

          imported_parent_epic = find_epic(imported_epics, 'Parent epic')
          imported_child_epic = find_epic(imported_epics, 'Child epic')
          imported_iteration = imported_group.reload!
            .iterations
            .find { |it| it.description == source_iteration.description }

          aggregate_failures do
            expect(imported_epics).to eq(source_epics)
            expect(imported_child_epic.parent_id).to eq(imported_parent_epic.id)

            expect(imported_iteration).to eq(source_iteration)
            expect(imported_iteration&.iid).to eq(source_iteration.iid)
            expect(imported_iteration&.created_at).to eq(source_iteration.created_at)
            expect(imported_iteration&.updated_at).to eq(source_iteration.updated_at)
          end
        end
      end
    end
  end
end
