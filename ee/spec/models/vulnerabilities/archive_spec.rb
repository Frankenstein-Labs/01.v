# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archive, feature_category: :vulnerability_management do
  subject(:archive) { build(:vulnerability_archive) }

  it_behaves_like 'cleanup by a loose foreign key' do
    let_it_be(:parent) { create(:project) }
    let_it_be(:model) { create(:vulnerability_archive, project: parent) }
  end

  it { is_expected.to belong_to(:project).required }
  it { is_expected.to have_many(:archived_records) }

  it { is_expected.to delegate_method(:year).to(:date).allow_nil }
  it { is_expected.to delegate_method(:month).to(:date).allow_nil }

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:date).scoped_to(:project_id) }
    it { is_expected.to validate_numericality_of(:archived_records_count).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe '#date=' do
    before do
      archive.date = nil
    end

    around do |example|
      travel_to('29/01/2025') { example.run }
    end

    context 'when the given value is nil' do
      it 'does not change the value from nil' do
        expect { archive.date = nil }.not_to change { archive.date }.from(nil)
      end
    end

    context 'when the given value is not nil' do
      let(:expected_date) { Date.parse('01/01/2025') }

      it 'assigns the beginning of month of given date' do
        expect { archive.date = Time.zone.today }.to change { archive.date }.to(expected_date)
      end
    end
  end
end
