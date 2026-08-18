# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserDetail, feature_category: :system_access do
  it { is_expected.to belong_to(:enterprise_group).inverse_of(:enterprise_user_details) }

  describe 'validations' do
    context 'with support for hash with indifferent access - ind_jsonb' do
      specify do
        user_detail = build(:user_detail, onboarding_status: { 'step_url' => '_string_' })
        user_detail.onboarding_status[:email_opt_in] = true

        expect(user_detail).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.with_enterprise_group' do
      subject(:scope) { described_class.with_enterprise_group }

      let_it_be(:user_detail_with_enterprise_group) { create(:enterprise_user).user_detail }
      let_it_be(:user_details_without_enterprise_group) { create_list(:user, 3, enterprise_group: nil) }

      it 'returns user details with enterprise group' do
        expect(scope).to contain_exactly(
          user_detail_with_enterprise_group
        )
      end
    end
  end

  context 'with loose foreign key on user_details.enterprise_group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let(:lfk_column) { :enterprise_group_id }
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:user, enterprise_group: parent).user_detail }
    end
  end

  context 'with onboarding_status enum values' do
    let_it_be(:json_schema) do
      Gitlab::Json.parse(File.read(Rails.root.join('app/validators/json_schemas/user_detail_onboarding_status.json')))
    end

    it 'matches with role enum values in onboarding_status json schema' do
      role_enum =
        json_schema.dig('properties', 'role', 'enum').reject do |value|
          value == 99 # non-applicable value, see https://gitlab.com/gitlab-org/gitlab/-/issues/524340
        end
      expect(role_enum).to eq(described_class.onboarding_status_roles.values)
    end

    it 'matches with registration_objective enum values in onboarding_status json schema' do
      registration_objective_enum = json_schema.dig('properties', 'registration_objective', 'enum')
      expect(registration_objective_enum).to eq(described_class.onboarding_status_registration_objectives.values)
    end
  end

  describe '#onboarding_status_role=' do
    let(:user_detail) { build(:user_detail) }

    context 'when given valid values' do
      it 'correctly handles string values' do
        value = '0'
        user_detail.onboarding_status_role = value

        expect(user_detail.onboarding_status_role).to eq(0)
      end

      it 'correctly handles integer values' do
        value = 0
        user_detail.onboarding_status_role = value

        expect(user_detail.onboarding_status_role).to eq(0)
      end
    end

    it 'passes nil to super when value is not present' do
      value = ''
      user_detail.onboarding_status_role = value

      expect(user_detail.onboarding_status_role).to be_nil
    end
  end

  describe '#onboarding_status_registration_objective=' do
    let(:user_detail) { build(:user_detail) }

    context 'when given valid values' do
      it 'correctly handles string values' do
        value = '0'
        user_detail.onboarding_status_registration_objective = value

        expect(user_detail.onboarding_status_registration_objective).to eq(0)
      end

      it 'correctly handles integer values' do
        value = 0
        user_detail.onboarding_status_registration_objective = value

        expect(user_detail.onboarding_status_registration_objective).to eq(0)
      end
    end

    it 'passes nil to super when value is not present' do
      value = ''
      user_detail.onboarding_status_registration_objective = value

      expect(user_detail.onboarding_status_registration_objective).to be_nil
    end
  end

  describe '#onboarding_status_joining_project=' do
    let(:user_detail) { build(:user_detail) }

    context 'when given valid values' do
      it 'correctly handles true' do
        value = 'true'
        user_detail.onboarding_status_joining_project = value

        expect(user_detail.onboarding_status_joining_project).to be(true)
      end

      it 'correctly handles false' do
        value = 'false'
        user_detail.onboarding_status_joining_project = value

        expect(user_detail.onboarding_status_joining_project).to be(false)
      end
    end

    it 'is false when value is nil' do
      user_detail.onboarding_status_joining_project = nil

      expect(user_detail.onboarding_status_joining_project).to be(false)
    end
  end

  describe '#onboarding_status_setup_for_company=' do
    let(:user_detail) { build(:user_detail) }

    context 'when given valid values' do
      it 'correctly handles true' do
        value = 'true'
        user_detail.onboarding_status_setup_for_company = value

        expect(user_detail.onboarding_status_setup_for_company).to be(true)
      end

      it 'correctly handles false' do
        value = 'false'
        user_detail.onboarding_status_setup_for_company = value

        expect(user_detail.onboarding_status_setup_for_company).to be(false)
      end
    end

    it 'is false when value is nil' do
      user_detail.onboarding_status_setup_for_company = nil

      expect(user_detail.onboarding_status_setup_for_company).to be(false)
    end
  end

  context 'when reading onboarding_status_role' do
    using RSpec::Parameterized::TableSyntax

    let(:user_detail) { build(:user_detail, onboarding_status: { 'role' => onboarding_status_role_enum }) }

    context 'with valid values' do
      where(
        onboarding_status_role_enum: described_class.onboarding_status_roles.values
      )

      with_them do
        it 'returns the string corresponding to the enum value' do
          expect(user_detail.onboarding_status_role_name)
            .to eq(described_class.onboarding_status_roles.key(onboarding_status_role_enum))
        end
      end
    end

    context 'with invalid values' do
      where(
        onboarding_status_role_enum: [nil, 9]
      )

      with_them do
        it 'returns nil' do
          expect(user_detail.onboarding_status_role_name).to be_nil
        end
      end
    end
  end

  context 'when reading onboarding_status_registration_objective' do
    using RSpec::Parameterized::TableSyntax

    let(:user_detail) do
      build(:user_detail,
        onboarding_status: { 'registration_objective' => onboarding_status_registration_objective_enum })
    end

    context 'with valid values' do
      where(
        onboarding_status_registration_objective_enum: described_class.onboarding_status_registration_objectives.values
      )

      with_them do
        it 'returns the string corresponding to the enum value' do
          expect(user_detail.onboarding_status_registration_objective_name)
            .to eq(
              described_class.onboarding_status_registration_objectives
                             .key(onboarding_status_registration_objective_enum)
            )
        end
      end
    end

    context 'with invalid values' do
      where(
        onboarding_status_registration_objective_enum: [nil, 9]
      )

      with_them do
        it 'returns nil' do
          expect(user_detail.onboarding_status_registration_objective_name).to be_nil
        end
      end
    end
  end
end
