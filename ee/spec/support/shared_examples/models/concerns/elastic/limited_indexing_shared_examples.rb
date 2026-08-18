# frozen_string_literal: true

RSpec.shared_examples 'limited indexing is enabled' do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create :project, name: 'test1', group: group }

  before do
    stub_ee_application_setting(elasticsearch_limit_indexing: true)
  end

  subject(:use_elasticsearch) { object.use_elasticsearch? }

  describe '#use_elasticsearch?' do
    context 'when the project is not enabled specifically' do
      it { is_expected.to eq(false) }
    end

    context 'when a project is enabled' do
      before do
        create :elasticsearch_indexed_project, project: project
      end

      it { is_expected.to eq(true) }
    end

    context 'when a group is enabled' do
      before do
        create :elasticsearch_indexed_namespace, namespace: group
      end

      it { is_expected.to eq(true) }
    end
  end
end
