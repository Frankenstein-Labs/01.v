# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Group::MaxIidsSaver, feature_category: :importers do
  let_it_be(:group, freeze: true) { create(:group) }
  let(:shared) { instance_double(Gitlab::ImportExport::Shared, export_path: export_path, error: nil) }
  let(:export_path) { Dir.mktmpdir('ee_group_max_iids_saver_spec') }
  let(:saver) { described_class.new(group: group, shared: shared) }

  before_all do
    create(:epic, group: group, iid: 3)
    create(:epic, group: group, iid: 9)
    create(:iteration, group: group, iid: 2)
    create(:iteration, group: group, iid: 8)
  end

  after do
    FileUtils.rm_rf(export_path)
  end

  describe '.resource_queries' do
    subject(:resource_queries) { described_class.resource_queries.keys }

    it 'includes EE group-scoped resource types' do
      expect(resource_queries).to include(:epics, :iterations)
    end
  end

  describe '#save' do
    subject(:save_result) { saver.save } # rubocop:disable Rails/SaveBang -- not an ActiveRecord save

    it 'writes the correct max IID for epics and iterations' do
      expect(save_result).to be true

      content = Gitlab::Json.safe_parse(File.read(File.join(export_path, 'max_iids.json')))

      expect(content).to include('epics' => 9, 'iterations' => 8)
    end

    it 'includes group_milestones from CE alongside EE resources' do
      create(:milestone, group: group, iid: 4)

      expect(saver.save).to be true

      content = Gitlab::Json.safe_parse(File.read(File.join(export_path, 'max_iids.json')))

      expect(content).to include('group_milestones' => 4, 'epics' => 9, 'iterations' => 8)
    end
  end
end
