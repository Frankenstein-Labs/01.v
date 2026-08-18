# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dast::ProfileTag, feature_category: :dynamic_application_security_testing do
  it { is_expected.to belong_to(:dast_profile).optional(false) }
  it { is_expected.to belong_to(:tag).optional(false) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:tag_name) }
    it { is_expected.to validate_length_of(:tag_name).is_at_most(described_class::MAX_NAME_LENGTH) }

    describe 'tag_name' do
      let_it_be(:dast_profile) { create(:dast_profile) }
      let_it_be(:tag, freeze: false) { create(:ci_tag, name: 'postgres') }

      subject(:profile_tag) { create(:dast_profile_tag, dast_profile: dast_profile, tag: tag, tag_name: nil) }

      it 'sets tag_name to tag name' do
        expect(profile_tag).to be_valid
        expect(profile_tag.tag_name).to eq('postgres')
      end

      it 'preserves existing tag_name' do
        profile_tag.tag_name = 'new-name'
        profile_tag.validate!
        expect(profile_tag.tag_name).to eq('new-name')
      end

      context 'when tag is missing' do
        let_it_be(:tag, freeze: false) { create(:ci_tag, name: 'missing-tag') }

        before do
          profile_tag.tag.destroy!
        end

        it 'handles missing tag gracefully' do
          expect do
            profile_tag.validate!
          end.not_to change { profile_tag.tag_name }.from('missing-tag')
        end
      end

      context 'when tag name is different from existing tag name' do
        before do
          profile_tag.tag.update!(name: 'golang')
        end

        it 'does not update tag_name to tag name on validation' do
          expect { profile_tag.validate! }
            .not_to change { profile_tag.tag_name }.from('postgres')
        end
      end

      context "when tag name exceeds #{described_class::MAX_NAME_LENGTH} characters" do
        let(:long_tag_name) { 'a' * (described_class::MAX_NAME_LENGTH + 20) }
        let(:tag) { create(:ci_tag, name: 'a') }
        let(:profile_tag) { build(:dast_profile_tag, dast_profile: dast_profile, tag: tag, tag_name: nil) }

        before do
          tag.update_columns(name: long_tag_name)
        end

        it 'makes profile tag invalid' do
          expect(tag).not_to be_valid
          expect(profile_tag).not_to be_valid
        end
      end
    end
  end

  describe 'loose foreign keys' do
    context 'with loose foreign key on tags.id' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let(:lfk_column) { :tag_id }
        let_it_be(:parent) { create(:ci_tag) }
        let_it_be(:model) { create(:dast_profile_tag, tag: parent) }
      end
    end

    context 'with loose foreign key on projects.id' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let(:lfk_column) { :project_id }
        let_it_be(:parent) { create(:project) }
        let_it_be(:model) { create(:dast_profile_tag, dast_profile: create(:dast_profile, project: parent)) }
      end
    end
  end
end
