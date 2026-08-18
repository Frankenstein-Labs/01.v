# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl, feature_category: :compliance_management do
  let_it_be(:control) { create(:compliance_requirements_control) }

  describe 'associations' do
    it 'belongs to requirement' do
      is_expected.to belong_to(:compliance_requirement)
        .class_name('ComplianceManagement::ComplianceFramework::ComplianceRequirement').required
    end

    it { is_expected.to belong_to(:namespace).optional(false) }
    it { is_expected.to have_many(:project_control_compliance_statuses) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:control_type) }

    it 'validates uniqueness of name scoped to requirement' do
      is_expected.to validate_uniqueness_of(:name)
         .scoped_to([:compliance_requirement_id]).ignoring_case_sensitivity
    end

    it 'validates uniqueness of external_control_name scoped to requirement' do
      is_expected.to validate_uniqueness_of(:external_control_name)
         .scoped_to([:compliance_requirement_id]).ignoring_case_sensitivity
    end

    it 'allows multiple records with empty external_control_name' do
      requirement = create(:compliance_requirement)
      create(:compliance_requirements_control, :external,
        compliance_requirement: requirement, external_control_name: '')

      no_external_name = build(:compliance_requirements_control, :external,
        compliance_requirement: requirement, external_control_name: '')

      expect(no_external_name).to be_valid
    end

    it 'allows multiple records with no external_control_name provided' do
      requirement = create(:compliance_requirement)
      create(:compliance_requirements_control, :external,
        compliance_requirement: requirement, external_control_name: nil)

      no_external_name = build(:compliance_requirements_control, :external,
        compliance_requirement: requirement)

      expect(no_external_name).to be_valid
    end

    it { is_expected.to validate_length_of(:external_control_name).is_at_most(255) }

    it { is_expected.to validate_length_of(:expression).is_at_most(255) }

    describe '#validate_name_with_expression' do
      let_it_be(:compliance_requirement) { create(:compliance_requirement) }

      let(:control) do
        build(:compliance_requirements_control,
          name: control_name,
          compliance_requirement: compliance_requirement,
          expression: expression_json)
      end

      context 'when name matches predefined control but expression does not match' do
        let(:control_name) { 'minimum_approvals_required_2' }
        let(:expression_json) { { operator: '=', field: 'merge_request_prevent_author_approval', value: true }.to_json }

        it 'returns error' do
          expect(control).to be_invalid
          expect(control.errors.full_messages)
            .to include("Expression does not match the name of the predefined control.")
        end
      end

      context 'when name and expression both match predefined control' do
        let(:control_name) { 'minimum_approvals_required_2' }
        let(:expression_json) { { operator: '>=', field: 'minimum_approvals_required', value: 2 }.to_json }

        it 'passes validation' do
          expect(control.valid?).to be(true)
        end
      end
    end
  end

  describe 'scopes' do
    describe '.for_framework' do
      let_it_be(:framework_1) { create(:compliance_framework) }
      let_it_be(:framework_2) { create(:compliance_framework) }
      let_it_be(:framework_3) { create(:compliance_framework) }

      let_it_be(:requirement_1) { create(:compliance_requirement, framework: framework_1) }
      let_it_be(:requirement_2) { create(:compliance_requirement, framework: framework_2) }

      let_it_be(:internal_control_1) { create(:compliance_requirements_control, compliance_requirement: requirement_1) }
      let_it_be(:external_control_1) do
        create(:compliance_requirements_control, :external, compliance_requirement: requirement_1)
      end

      let_it_be(:internal_control_2) { create(:compliance_requirements_control, compliance_requirement: requirement_2) }

      it 'returns all controls for the specified framework' do
        expect(described_class.for_framework(framework_1.id)).to contain_exactly(internal_control_1, external_control_1)
        expect(described_class.for_framework(framework_2.id)).to contain_exactly(internal_control_2)
      end

      it 'does not return controls from other frameworks' do
        expect(described_class.for_framework(framework_1.id)).not_to include(internal_control_2)
      end

      it 'returns an empty relation when the framework has no controls' do
        expect(described_class.for_framework(framework_3.id)).to be_empty
      end
    end

    describe '.for_projects' do
      let_it_be(:project_1) { create(:project) }
      let_it_be(:project_2) { create(:project) }
      let_it_be(:project_3) { create(:project) }

      let_it_be(:framework_1) { create(:compliance_framework, projects: [project_1]) }
      let_it_be(:framework_2) { create(:compliance_framework, projects: [project_2]) }
      let_it_be(:framework_3) { create(:compliance_framework, projects: [project_3]) }

      let_it_be(:requirement_1) { create(:compliance_requirement, framework: framework_1) }
      let_it_be(:requirement_2) { create(:compliance_requirement, framework: framework_2) }

      let_it_be(:internal_control_1) { create(:compliance_requirements_control, compliance_requirement: requirement_1) }
      let_it_be(:external_control_1) do
        create(:compliance_requirements_control, :external, compliance_requirement: requirement_1)
      end

      let_it_be(:internal_control_2) { create(:compliance_requirements_control, compliance_requirement: requirement_2) }

      it 'returns all controls for the specified projects' do
        result = described_class.for_projects([project_1.id, project_2.id])

        expect(result).to contain_exactly(internal_control_1, external_control_1, internal_control_2)
      end

      it 'includes project_id as an attribute for each control' do
        result = described_class.for_projects([project_1.id])

        expect(result.first.project_id).to eq(project_1.id)
      end

      it 'returns an empty relation when projects have no controls' do
        expect(described_class.for_projects([project_3.id])).to be_empty
      end
    end

    describe '.grouped_by_project' do
      let_it_be(:project_1) { create(:project) }
      let_it_be(:project_2) { create(:project) }
      let_it_be(:project_3) { create(:project) }

      let_it_be(:framework_1) { create(:compliance_framework, projects: [project_1]) }
      let_it_be(:framework_2) { create(:compliance_framework, projects: [project_2]) }
      let_it_be(:framework_3) { create(:compliance_framework, projects: [project_3]) }

      let_it_be(:requirement_1) { create(:compliance_requirement, framework: framework_1) }
      let_it_be(:requirement_2) { create(:compliance_requirement, framework: framework_2) }

      let_it_be(:internal_control_1) { create(:compliance_requirements_control, compliance_requirement: requirement_1) }
      let_it_be(:external_control_1) do
        create(:compliance_requirements_control, :external, compliance_requirement: requirement_1)
      end

      let_it_be(:internal_control_2) { create(:compliance_requirements_control, compliance_requirement: requirement_2) }

      it 'returns controls grouped by project_id' do
        result = described_class.grouped_by_project([project_1.id, project_2.id, project_3.id])

        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly(project_1.id, project_2.id)
        expect(result[project_1.id]).to contain_exactly(internal_control_1, external_control_1)
        expect(result[project_2.id]).to contain_exactly(internal_control_2)
      end

      it 'returns empty hash when projects have no controls' do
        result = described_class.grouped_by_project([project_3.id])

        expect(result).to eq({})
      end

      it 'handles empty project_ids array' do
        result = described_class.grouped_by_project([])

        expect(result).to eq({})
      end
    end
  end

  describe 'enums' do
    it 'name has correct values' do
      enum_definitions = ComplianceManagement::ComplianceFramework::Controls::Registry.enum_definitions
      is_expected.to define_enum_for(:name).with_values(enum_definitions)
    end

    it { is_expected.to define_enum_for(:control_type).with_values(internal: 0, external: 1) }
  end

  describe '#controls_count_per_requirement' do
    let_it_be(:compliance_requirement_1) { create(:compliance_requirement) }

    subject(:new_control) { build(:compliance_requirements_control, compliance_requirement: compliance_requirement_1) }

    context 'when controls count is one less than max count' do
      before do
        create(:compliance_requirements_control, :external, compliance_requirement: compliance_requirement_1)
        create(:compliance_requirements_control, :minimum_approvals_required_2,
          compliance_requirement: compliance_requirement_1)
        create(:compliance_requirements_control, :project_visibility_not_internal,
          compliance_requirement: compliance_requirement_1)
        create(:compliance_requirements_control, compliance_requirement: compliance_requirement_1)
      end

      it 'creates control with no error' do
        new_control.name = :default_branch_protected
        new_control.expression = { operator: '=', field: 'default_branch_protected', value: true }.to_json

        expect(new_control.valid?).to be(true)
        expect(new_control.errors).to be_empty
      end
    end

    context 'when requirements count is equal to max count' do
      before do
        create(:compliance_requirements_control, :external, compliance_requirement: compliance_requirement_1)
        create(:compliance_requirements_control, :minimum_approvals_required_2,
          compliance_requirement: compliance_requirement_1)
        create(:compliance_requirements_control, :project_visibility_not_internal,
          compliance_requirement: compliance_requirement_1)
        create(:compliance_requirements_control, compliance_requirement: compliance_requirement_1)
        create(:compliance_requirements_control, :default_branch_protected,
          compliance_requirement: compliance_requirement_1)
      end

      it 'returns error' do
        new_control.name = :auth_sso_enabled
        new_control.expression = { operator: '=', field: 'auth_sso_enabled', value: true }.to_json

        expect(new_control.valid?).to be(false)
        expect(new_control.errors.full_messages)
          .to contain_exactly("Compliance requirement cannot have more than 5 controls")
      end
    end
  end

  describe '#expression_as_hash' do
    let_it_be(:expression_hash) do
      {
        'operator' => '>=',
        'field' => 'minimum_approvals_required',
        'value' => 2
      }
    end

    let_it_be(:control) do
      create(:compliance_requirements_control,
        name: 'minimum_approvals_required_2',
        expression: expression_hash.to_json)
    end

    it 'returns parsed hash with string keys without param symbolize_names' do
      expect(control.expression_as_hash).to eq(expression_hash)
    end

    it 'returns parsed hash with symbol keys when symbolize_names is true' do
      expected_hash = {
        operator: '>=',
        field: 'minimum_approvals_required',
        value: 2
      }

      expect(control.expression_as_hash(symbolize_names: true)).to eq(expected_hash)
    end
  end

  describe 'external_url validation' do
    let_it_be(:compliance_requirement) { create :compliance_requirement }
    let(:control) do
      build :compliance_requirements_control,
        name: 'scanner_sast_running',
        compliance_requirement: compliance_requirement,
        control_type: control_type,
        secret_token: 'psssst'
    end

    context 'with external control type' do
      let(:control_type) { :external }

      it 'validates presence' do
        control.external_url = nil
        expect(control).not_to be_valid

        control.external_url = 'udp://example.com:1701'
        expect(control).not_to be_valid

        control.external_url = 'https://example.com/bar'
        expect(control).to be_valid

        control.external_url = 'https://localhost:1337/bar'
        expect(control).to be_valid
      end

      context 'when in SaaS context' do
        it 'validates presence', :aggregate_failures do
          stub_saas_features gitlab_com_subscriptions: true

          control.external_url = nil
          expect(control).not_to be_valid

          control.external_url = 'udp://example.com:1701'
          expect(control).not_to be_valid

          control.external_url = 'https://example.com/bar'
          expect(control).to be_valid

          control.external_url = 'https://localhost:1337/bar'
          expect(control).not_to be_valid

          control.external_url = 'https://0.0.0.0:1337/bar'
          expect(control).not_to be_valid

          control.external_url = 'https://127.0.0.1:1337/bar'
          expect(control).not_to be_valid
        end
      end
    end

    context 'with internal control_type' do
      let(:control_type) { :internal }

      it 'ignores presence' do
        control.external_url = nil
        expect(control).to be_valid

        control.external_url = ' '
        expect(control).to be_valid
      end
    end
  end

  describe 'secret_token validation' do
    let_it_be(:compliance_requirement) { create :compliance_requirement }
    let(:control) do
      build :compliance_requirements_control,
        name: 'scanner_sast_running',
        compliance_requirement: compliance_requirement,
        control_type: control_type,
        external_url: FFaker::Internet.unique.http_url
    end

    context 'with external control type' do
      let(:control_type) { :external }

      it 'validates presence' do
        control.secret_token = nil
        expect(control).not_to be_valid

        control.secret_token = 'foo'
        expect(control).to be_valid
      end
    end

    context 'with internal control_type' do
      let(:control_type) { :internal }

      it 'ignores presence' do
        control.secret_token = nil
        expect(control).to be_valid

        control.secret_token = 'foo'
        expect(control).to be_valid
      end
    end

    context 'when secret_token exceeds maximum length' do
      let(:control_type) { :external }

      it 'is invalid when secret_token is over 240 characters' do
        control.secret_token = 'a' * 241

        expect(control).not_to be_valid
        expect(control.errors[:secret_token]).to include('is too long (maximum is 240 characters)')
      end

      it 'is valid when secret_token is exactly 240 characters' do
        control.secret_token = 'a' * 240

        expect(control).to be_valid
      end
    end
  end

  describe '#validate_internal_expression' do
    let_it_be(:compliance_requirement) { create(:compliance_requirement) }

    context 'when the expression is not a json' do
      let_it_be(:expression) { "non_json_string" }
      let_it_be(:control) do
        build(:compliance_requirements_control, name: 'scanner_sast_running',
          compliance_requirement: compliance_requirement, expression: expression)
      end

      it 'returns invalid json object error' do
        expect(control).to be_invalid
        expect(control.errors.full_messages).to contain_exactly('Expression should be a valid json object.')
      end
    end

    context 'when the expression is a json' do
      context 'when control expression is valid' do
        let_it_be(:expression) do
          {
            operator: ">=",
            field: "minimum_approvals_required",
            value: 2
          }.to_json
        end

        subject do
          build(:compliance_requirements_control, name: 'minimum_approvals_required_2',
            compliance_requirement: compliance_requirement, expression: expression)
        end

        it { is_expected.to be_valid }
      end

      context 'when control expression is invalid' do
        let_it_be(:expression) do
          {
            operator: "=",
            field: "minimum_approvals_required",
            value: "invalid_value"
          }.to_json
        end

        subject(:control) do
          build(:compliance_requirements_control, name: 'minimum_approvals_required_2',
            compliance_requirement: compliance_requirement, expression: expression)
        end

        it 'returns invalid expression error' do
          expect(control).to be_invalid
          expect(control.errors.full_messages)
            .to include("Expression property '/value' is not of type: number")
        end
      end
    end
  end
end
