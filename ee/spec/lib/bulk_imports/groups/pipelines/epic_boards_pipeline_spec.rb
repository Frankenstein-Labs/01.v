# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Groups::Pipelines::EpicBoardsPipeline, feature_category: :importers do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:group_label) { create(:group_label, group: group) }
  let_it_be_with_reload(:bulk_import) { create(:bulk_import, user: user) }
  let_it_be_with_reload(:entity) do
    create(
      :bulk_import_entity,
      group: group,
      bulk_import: bulk_import,
      source_full_path: 'source/full/path',
      destination_slug: 'My-Destination-Group',
      destination_namespace: group.full_path
    )
  end

  let(:epic_board_data) do
    {
      "name" => "Test Board",
      "epic_lists" => [
        {
          "list_type" => "backlog",
          "position" => 0
        },
        {
          "list_type" => "closed",
          "position" => 1
        },
        {
          "list_type" => "label",
          "position" => 2,
          "label" => {
            "title" => "Label 1",
            "type" => "GroupLabel",
            "group_id" => group.id
          }
        },
        {
          "list_type" => "label",
          "position" => 3,
          "label" => {
            "title" => group_label.title,
            "created_at" => group_label.created_at,
            "description" => group_label.description,
            "type" => "GroupLabel",
            "group_id" => group.id
          }
        }
      ]
    }
  end

  let(:tracker) { create(:bulk_import_tracker, entity: entity) }
  let(:context) { BulkImports::Pipeline::Context.new(tracker) }

  subject(:pipeline) { described_class.new(context) }

  before_all do
    group.add_owner(user)
  end

  before do
    allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
      allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: epic_board_data))
    end
    allow(pipeline).to receive(:set_source_objects_counter)
  end

  describe '#run' do
    it 'imports epic boards into destination group' do
      expect { pipeline.run }.to change { ::Boards::EpicBoard.count }.by(1)

      epic_board = group.epic_boards.find_by(name: epic_board_data["name"])

      expect(epic_board).to be_present
      expect(epic_board.group.id).to eq(group.id)
      expect(epic_board.epic_lists.map(&:list_type).sort).to match_array(%w[backlog closed label label])
      expect(epic_board.epic_lists.map(&:title)).to match_array(['Open', 'Closed', 'Label 1', group_label.title])
    end
  end
end
