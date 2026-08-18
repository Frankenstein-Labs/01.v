# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectSecurityExclusion, feature_category: :secret_detection, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:scanner) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to allow_value(true, false).for(:active) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:value).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }

    describe '#validate_push_protection_path_exclusions_limit' do
      let_it_be(:project) { create(:project) }

      before do
        stub_const('Security::ProjectSecurityExclusion::MAX_PATH_EXCLUSIONS_PER_PROJECT', 2)
      end

      context 'when exclusion is created or updated for the secret push protection scanner' do
        context 'with `path` type' do
          context 'when maximum number of path exclusions already exist' do
            let_it_be_with_reload(:rule_exclusion) do
              create(:project_security_exclusion, :with_rule, project: project)
            end

            before do
              create_list(:project_security_exclusion, 2, :with_path, project: project)
            end

            it 'does not allow adding more exclusions' do
              exclusion = build(:project_security_exclusion, :with_path, project: project)

              expect(exclusion.save).to be_falsey
              expect(exclusion.errors.full_messages).to eq(
                ["Cannot have more than 2 path exclusions for secret push protection per project"]
              )
            end

            it 'does not allow updating an exclusion of another type to `path` type' do
              rule_exclusion.type = :path

              expect(rule_exclusion.save).to be_falsey
              expect(rule_exclusion.errors.full_messages).to eq(
                ["Cannot have more than 2 path exclusions for secret push protection per project"]
              )
            end
          end

          context 'when less than maximum number of path exclusions exist' do
            before do
              create_list(:project_security_exclusion, 1, :with_path, project: project)
            end

            it 'creates the 2nd path exclusion' do
              exclusion = build(:project_security_exclusion, :with_path, project: project)

              expect { exclusion.save! }.to change { ::Security::ProjectSecurityExclusion.count }.by(1)
            end
          end
        end

        context 'when exclusion created or updated is not of `path` type' do
          before do
            create_list(:project_security_exclusion, 2, :with_rule, project: project)
          end

          it 'allows adding more exclusions' do
            exclusion = build(:project_security_exclusion, :with_rule, project: project)

            expect { exclusion.save! }.to change { ::Security::ProjectSecurityExclusion.count }.by(1)
          end
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:scanner).with_values([:secret_push_protection]) }
    it { is_expected.to define_enum_for(:type).with_values([:path, :regex_pattern, :raw_value, :rule]) }
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:exclusion_1) { create(:project_security_exclusion, :with_raw_value, project: project) }
    let_it_be(:exclusion_2) { create(:project_security_exclusion, :with_raw_value, :inactive, project: project) }
    let_it_be(:exclusion_3) { create(:project_security_exclusion, :with_path, project: project) }

    describe '.by_scanner' do
      it 'returns the correct records' do
        expect(described_class.by_scanner(:secret_push_protection)).to match_array([exclusion_1, exclusion_2,
          exclusion_3])
      end
    end

    describe '.by_type' do
      it 'returns the correct records' do
        expect(described_class.by_type(:raw_value)).to match_array([exclusion_1, exclusion_2])
      end
    end

    describe '.by_status' do
      it 'returns the correct records' do
        expect(described_class.by_status(true)).to match_array([exclusion_1, exclusion_3])
      end
    end

    describe '.active' do
      it 'returns the correct records' do
        expect(described_class.active).to match_array([exclusion_1, exclusion_3])
      end
    end
  end

  describe '#exclusion_type' do
    it 'returns correct GRPC enum for each type' do
      expect(build(:project_security_exclusion, type: 'path').exclusion_type).to eq(:EXCLUSION_TYPE_PATH)
      expect(build(:project_security_exclusion, type: 'rule').exclusion_type).to eq(:EXCLUSION_TYPE_RULE)
      expect(build(:project_security_exclusion, type: 'raw_value').exclusion_type).to eq(:EXCLUSION_TYPE_RAW_VALUE)
    end
  end

  describe '#audit_details' do
    let_it_be(:project) { create(:project) }
    let_it_be(:exclusion) { create(:project_security_exclusion, :with_rule, project: project, description: 'foobar') }

    it 'contains some attributes of the object' do
      expect(exclusion.audit_details).to match(
        a_hash_including(
          scanner: 'secret_push_protection',
          value: 'gitlab_personal_access_token',
          active: true,
          description: 'foobar'
        )
      )
    end
  end

  context 'with loose foreign key on project_security_exclusions.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:project_security_exclusion, :with_rule, project: parent) }
    end
  end
end
