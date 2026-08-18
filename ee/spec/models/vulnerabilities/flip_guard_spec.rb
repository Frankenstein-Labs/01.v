# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FlipGuard, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability_finding) { create(:vulnerabilities_finding, project: project) }

  describe 'associations' do
    it { is_expected.to belong_to(:finding).class_name('Vulnerabilities::Finding') }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    subject { build(:vulnerability_flip_guard, finding: vulnerability_finding, project: project) }

    it { is_expected.to validate_presence_of(:finding) }
    it { is_expected.to validate_uniqueness_of(:finding) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:first_automatic_transition_at) }
    it { is_expected.to validate_presence_of(:last_automatic_transition_at) }
  end

  context 'with loose foreign key on vulnerability_flip_guards.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) do
        create(:vulnerability_flip_guard, finding: create(:vulnerabilities_finding, project: parent))
      end
    end
  end
end
