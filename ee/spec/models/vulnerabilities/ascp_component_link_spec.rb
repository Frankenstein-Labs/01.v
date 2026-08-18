# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::AscpComponentLink, feature_category: :static_application_security_testing do
  describe 'associations' do
    it { is_expected.to belong_to(:vulnerability_finding).class_name('Vulnerabilities::Finding').inverse_of(:ascp_component_link).required }
    it { is_expected.to belong_to(:ascp_component).class_name('Security::Ascp::Component').inverse_of(:vulnerability_finding_ascp_component_links).required }
    it { is_expected.to belong_to(:project).required }
  end

  describe 'validations' do
    subject { build(:vulnerability_finding_ascp_component_link) }

    describe 'uniqueness' do
      before do
        create(:vulnerability_finding_ascp_component_link)
      end

      it { is_expected.to validate_uniqueness_of(:vulnerability_occurrence_id) }
    end
  end

  describe 'data consistency constraints' do
    context 'when a link for the same vulnerability already exists' do
      let_it_be(:existing_link) { create(:vulnerability_finding_ascp_component_link) }

      it 'raises the uniqueness violation error' do
        expect do
          duplicate = build(:vulnerability_finding_ascp_component_link,
            vulnerability_finding: existing_link.vulnerability_finding)
          duplicate.save!(validate: false)
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end
