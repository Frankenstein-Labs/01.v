# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::DetectionTransition, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:finding).with_foreign_key('vulnerability_occurrence_id') }
    it { is_expected.to belong_to(:finding).inverse_of(:detection_transitions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:vulnerability_occurrence_id) }
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to validate_inclusion_of(:detected).in_array([true, false]) }
  end

  describe 'table_name' do
    it 'uses vulnerability_detection_transitions table' do
      expect(described_class.table_name).to eq('vulnerability_detection_transitions')
    end
  end

  describe 'database constraints' do
    let_it_be(:finding) { create(:vulnerabilities_finding) }

    it 'enforces presence of vulnerability_occurrence_id' do
      transition = described_class.new(detected: true)
      expect(transition).not_to be_valid
      expect(transition.errors[:vulnerability_occurrence_id]).to include("can't be blank")
    end

    it 'allows detected to be true' do
      transition = build(:vulnerability_detection_transition, finding: finding, detected: true)
      expect(transition).to be_valid
    end

    it 'allows detected to be false' do
      transition = build(:vulnerability_detection_transition, finding: finding, detected: false)
      expect(transition).to be_valid
    end

    it 'does not allow detected to be nil' do
      transition = build(:vulnerability_detection_transition, finding: finding)
      transition.detected = nil
      expect(transition).not_to be_valid
      expect(transition.errors[:detected]).to include('is not included in the list')
    end
  end

  describe 'foreign key cascade' do
    let_it_be(:finding) { create(:vulnerabilities_finding) }
    let_it_be(:transition) { create(:vulnerability_detection_transition, finding: finding) }

    it 'deletes transition when finding is deleted' do
      expect { finding.destroy! }.to change { described_class.count }.by(-1)
    end
  end

  describe 'timestamps' do
    let(:transition) { create(:vulnerability_detection_transition) }

    it 'sets created_at on creation' do
      expect(transition.created_at).to be_present
    end

    it 'sets updated_at on creation' do
      expect(transition.updated_at).to be_present
    end

    it 'updates updated_at on update' do
      original_updated_at = transition.updated_at
      travel_to(1.hour.from_now) do
        transition.update!(detected: false)
        expect(transition.updated_at).to be > original_updated_at
      end
    end
  end

  describe 'multiple transitions for same finding' do
    let_it_be(:finding) { create(:vulnerabilities_finding) }

    let_it_be(:first_transition) do
      create(:vulnerability_detection_transition, finding: finding, detected: true, created_at: 3.days.ago)
    end

    let_it_be(:second_transition) do
      create(:vulnerability_detection_transition, finding: finding, detected: false, created_at: 2.days.ago)
    end

    let_it_be(:third_transition) do
      create(:vulnerability_detection_transition, finding: finding, detected: true, created_at: 1.day.ago)
    end

    it 'allows multiple transitions for the same finding' do
      expect(described_class.where(vulnerability_occurrence_id: finding.id).count).to eq(3)
      expect([first_transition, second_transition, third_transition]).to all(be_persisted)
    end

    it 'tracks detection state changes over time' do
      transitions = described_class.where(vulnerability_occurrence_id: finding.id).order(created_at: :asc)
      expect(transitions.pluck(:detected)).to eq([true, false, true])
    end
  end
end
