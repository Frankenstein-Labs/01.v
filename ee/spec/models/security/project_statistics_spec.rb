# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectStatistics, feature_category: :vulnerability_management do
  let_it_be(:statistics) { create(:project_security_statistics) }

  it { is_expected.to belong_to(:project).required }

  describe 'scopes' do
    describe '.by_projects' do
      subject { described_class.by_projects(statistics.project_id) }

      before do
        create(:project_security_statistics)
      end

      it { is_expected.to contain_exactly(statistics) }
    end
  end

  describe '.create_for' do
    let_it_be_with_refind(:project) { create(:project) }

    subject(:create_statistics) { described_class.create_for(project) }

    context 'when there is already a record for the given project' do
      let_it_be(:existing_record) { create(:project_security_statistics, project: project) }

      it { is_expected.to eq(existing_record) }

      it 'does not try to create a new record' do
        expect { create_statistics }.not_to change { described_class.count }
      end
    end

    context 'when there is no record for the given project' do
      it 'creates a new record' do
        expect { create_statistics }.to change { described_class.count }.by(1)
      end
    end
  end

  describe '#increase_vulnerability_counter!' do
    subject(:decrease_vulnerability_counter) { statistics.increase_vulnerability_counter!(1) }

    it 'decreases the `vulnerability_count` attribute by given number' do
      expect { decrease_vulnerability_counter }.to change { statistics.reload.vulnerability_count }.by(1)
    end
  end

  describe '#decrease_vulnerability_counter!' do
    subject(:decrease_vulnerability_counter) { statistics.decrease_vulnerability_counter!(1) }

    it 'decreases the `vulnerability_count` attribute by given number' do
      expect { decrease_vulnerability_counter }.to change { statistics.reload.vulnerability_count }.by(-1)
    end
  end
end
