# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dast::PreScanVerification, :dynamic_analysis,
  feature_category: :dynamic_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:dast_profile) { create(:dast_profile, project: project) }

  subject { create(:dast_pre_scan_verification, dast_profile: dast_profile) }

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:dast_profile_id) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe 'associations' do
    describe '#ci_pipeline' do
      it_behaves_like 'a partition-pruned pipeline association', :ci_pipeline do
        # .reload clears the :pipeline target cached by the attribute writer
        let(:related_resource) { create(:dast_pre_scan_verification, ci_pipeline: pipeline).reload }
      end
    end
  end

  describe 'instance methods' do
    describe '#verification_valid?' do
      context 'when the associated dast_site_profile was updated before the pre_scan_verification creation' do
        before do
          subject.created_at = subject.created_at + 1.day
          subject.save!
        end

        it { is_expected.to be_verification_valid }
      end

      context 'when the associated dast_site_profile was updated after the pre_scan_verification creation' do
        before do
          subject.created_at = subject.created_at - 1.day
          subject.save!
        end

        it { is_expected.not_to be_verification_valid }
      end
    end
  end

  context 'with loose foreign key on dast_pre_scan_verifications.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:dast_pre_scan_verification, project_id: parent.id) }
    end
  end
end
