# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicyCiConfigAccess, feature_category: :security_policy_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be_with_reload(:project) { create(:project, group: subgroup) }
  let_it_be(:policy_project) { create(:project, :small_repo, group: root_group) }

  let(:setting) { project.project_setting }

  describe 'associations' do
    it 'belongs to pipeline_execution_policy_bot_access_group' do
      expect(setting)
        .to belong_to(:pipeline_execution_policy_bot_access_group).class_name('Group').optional
    end
  end

  describe 'validations' do
    context 'when pipeline_execution_policy_bot_access_enabled is true' do
      subject(:setting) { build(:project_setting, pipeline_execution_policy_bot_access_enabled: true) }

      it 'is valid with proper file patterns' do
        setting.pipeline_execution_policy_bot_access_file_patterns = ['*.yml', 'config/**/*.yaml']

        expect(setting).to be_valid
      end

      it 'is invalid with more than 20 file patterns' do
        setting.pipeline_execution_policy_bot_access_file_patterns = Array.new(21) { |i| "pattern#{i}.yml" }

        expect(setting).not_to be_valid
        expect(setting.errors[:pipeline_execution_policy_bot_access_file_patterns])
          .to include("cannot have more than #{described_class::MAX_FILE_PATTERNS} file patterns")
      end

      it 'is invalid with a pattern exceeding the maximum length' do
        long_pattern = "#{'a' * described_class::MAX_FILE_PATTERN_LENGTH}.yml"
        setting.pipeline_execution_policy_bot_access_file_patterns = [long_pattern]

        expect(setting).not_to be_valid
        expect(setting.errors[:pipeline_execution_policy_bot_access_file_patterns])
          .to include("individual patterns cannot exceed #{described_class::MAX_FILE_PATTERN_LENGTH} characters")
      end

      it 'is invalid with empty pattern in array' do
        setting.pipeline_execution_policy_bot_access_file_patterns = ['valid.yml', '']

        expect(setting).not_to be_valid
        expect(setting.errors[:pipeline_execution_policy_bot_access_file_patterns])
          .to include('cannot contain empty patterns')
      end

      it 'is invalid with path traversal in pattern' do
        setting.pipeline_execution_policy_bot_access_file_patterns = ['../secret.yml']

        expect(setting).not_to be_valid
        expect(setting.errors[:pipeline_execution_policy_bot_access_file_patterns])
          .to include('cannot contain path traversal')
      end

      it 'is invalid with pattern starting with /' do
        setting.pipeline_execution_policy_bot_access_file_patterns = ['/etc/passwd']

        expect(setting).not_to be_valid
        expect(setting.errors[:pipeline_execution_policy_bot_access_file_patterns])
          .to include('cannot start with /')
      end

      it 'normalizes patterns with leading ./ on save' do
        setting.pipeline_execution_policy_bot_access_file_patterns = ['./config/*.yml', './ci/**/*.yaml']
        setting.save!

        expect(setting.pipeline_execution_policy_bot_access_file_patterns).to match_array(['config/*.yml',
          'ci/**/*.yaml'])
      end
    end

    context 'when pipeline_execution_policy_bot_access_enabled is false' do
      subject(:setting) { build(:project_setting, pipeline_execution_policy_bot_access_enabled: false) }

      it 'skips file pattern validations' do
        setting.pipeline_execution_policy_bot_access_file_patterns = ['../traversal.yml', '', '/absolute.yml']

        expect(setting).to be_valid
      end
    end

    context 'when pipeline_execution_policy_bot_access_group_id is set' do
      let_it_be(:group) { create(:group) }

      it 'is valid with a valid group' do
        setting = build(:project_setting, pipeline_execution_policy_bot_access_group_id: group.id)

        expect(setting).to be_valid
      end

      it 'is invalid with an invalid group id' do
        setting = build(:project_setting, pipeline_execution_policy_bot_access_group_id: non_existing_record_id)

        expect(setting).not_to be_valid
        expect(setting.errors[:pipeline_execution_policy_bot_access_group]).to include('must be a valid group')
      end
    end

    context 'when pipeline_execution_policy_bot_access_group_id is nil' do
      it 'does not add validation errors' do
        setting = build(:project_setting, pipeline_execution_policy_bot_access_group_id: nil)

        setting.send(:validate_pipeline_execution_policy_bot_access_group)

        expect(setting.errors[:pipeline_execution_policy_bot_access_group]).to be_empty
      end
    end

    context 'when pipeline_execution_policy_bot_access_group is outside project hierarchy' do
      let_it_be(:external_group) { create(:group) }

      it 'is invalid because the group is not within the project hierarchy' do
        setting.pipeline_execution_policy_bot_access_group_id = external_group.id

        expect(setting).not_to be_valid
        expect(setting.errors[:pipeline_execution_policy_bot_access_group])
          .to include('must be within the project hierarchy')
      end
    end

    context 'when pipeline_execution_policy_bot_access_group is an ancestor of the project' do
      it 'is valid for root ancestor group' do
        setting.pipeline_execution_policy_bot_access_group_id = root_group.id

        expect(setting).to be_valid
      end

      it 'is valid for immediate parent group' do
        setting.pipeline_execution_policy_bot_access_group_id = subgroup.id

        expect(setting).to be_valid
      end
    end
  end

  describe '#allows_pipeline_execution_policy_ci_config_access?' do
    let_it_be(:requesting_project) { create(:project, group: root_group) }

    before do
      setting.update!(
        pipeline_execution_policy_bot_access_enabled: true,
        pipeline_execution_policy_bot_access_file_patterns: ['*.yml', 'config/**/*.yaml'],
        pipeline_execution_policy_bot_access_group_id: nil
      )

      allow(setting).to receive(:valid_pipeline_execution_policy_context?).and_return(true)
    end

    context 'when checking valid_pipeline_execution_policy_context?' do
      before do
        allow(setting).to receive(:valid_pipeline_execution_policy_context?).and_call_original
      end

      it 'returns false when requesting project is nil' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: nil
        )

        expect(result).to be false
      end

      using RSpec::Parameterized::TableSyntax

      where(:policy_type, :expected_result) do
        nil                              | false
        :approval_policy                 | false
        :pipeline_execution_policy       | true
        :pipeline_execution_schedule_policy | true
      end

      with_them do
        it "returns #{params[:expected_result]} for #{params[:policy_type] || 'no'} policy" do
          test_requesting_project = create(:project, group: root_group)

          if policy_type
            policy_management_project = create(:project, :small_repo, group: root_group)
            policy_config = create(:security_orchestration_policy_configuration,
              project: test_requesting_project,
              security_policy_management_project: policy_management_project)
            create(:security_policy, policy_type,
              security_orchestration_policy_configuration: policy_config,
              linked_projects: [test_requesting_project])
          end

          result = setting.allows_pipeline_execution_policy_ci_config_access?(
            file_path: 'test.yml',
            requesting_project: test_requesting_project
          )

          expect(result).to be expected_result
        end
      end
    end

    it 'returns false when policy file access is disabled' do
      setting.update!(pipeline_execution_policy_bot_access_enabled: false)

      result = setting.allows_pipeline_execution_policy_ci_config_access?(
        file_path: 'test.yml',
        requesting_project: requesting_project
      )

      expect(result).to be false
    end

    context 'when requesting project is in allowed group hierarchy' do
      it 'returns true for matching file pattern' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: requesting_project
        )

        expect(result).to be true
      end

      it 'returns true for nested path matching glob pattern' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'config/ci/pipeline.yaml',
          requesting_project: requesting_project
        )

        expect(result).to be true
      end

      it 'returns false for non-matching file pattern' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.txt',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end

      it 'returns false when glob does not match nested path' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: '.gitlab/ci/foo.yml',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end

      it 'returns true for brace expansion patterns', :aggregate_failures do
        setting.update!(pipeline_execution_policy_bot_access_file_patterns: ['*.{rb,js}'])

        expect(setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'app.rb',
          requesting_project: requesting_project
        )).to be true

        expect(setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'app.js',
          requesting_project: requesting_project
        )).to be true

        expect(setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'app.py',
          requesting_project: requesting_project
        )).to be false
      end
    end

    context 'when requesting project is in a subgroup of the allowed group' do
      let_it_be(:nested_subgroup) { create(:group, parent: root_group) }
      let_it_be(:nested_requesting_project) { create(:project, group: nested_subgroup) }

      it 'returns true because the requesting project namespace is a descendant of the allowed group' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: nested_requesting_project
        )

        expect(result).to be true
      end
    end

    context 'when requesting project is outside allowed group hierarchy' do
      it 'returns false' do
        other_group = create(:group)
        other_requesting_project = create(:project, group: other_group)

        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: other_requesting_project
        )

        expect(result).to be false
      end
    end

    context 'when file patterns are empty' do
      before do
        setting.update_column(:pipeline_execution_policy_bot_access_file_patterns, [])
      end

      it 'returns false' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end
    end

    context 'when requesting project namespace is nil' do
      it 'returns false' do
        allow(requesting_project).to receive(:namespace).and_return(nil)

        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end
    end

    context 'when explicit group is configured' do
      let_it_be(:allowed_subgroup) { create(:group, parent: subgroup) }
      let_it_be(:allowed_requesting_project) { create(:project, group: allowed_subgroup) }

      before do
        setting.update!(pipeline_execution_policy_bot_access_group_id: allowed_subgroup.id)
      end

      it 'returns true for project in explicitly allowed group' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: allowed_requesting_project
        )

        expect(result).to be true
      end

      it 'returns false for project in root group (not within allowed subgroup)' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end
    end

    context 'when project is in personal namespace' do
      let_it_be(:personal_project) { create(:project, :in_user_namespace) }
      let(:personal_setting) { personal_project.project_setting }

      before do
        personal_setting.update!(
          pipeline_execution_policy_bot_access_enabled: true,
          pipeline_execution_policy_bot_access_file_patterns: ['*.yml']
        )

        allow(personal_setting)
          .to receive(:valid_pipeline_execution_policy_context?).and_return(true)
      end

      it 'returns false because root ancestor is not a group' do
        result = personal_setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: 'test.yml',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end
    end

    context 'with path traversal attempts' do
      it 'returns false for paths with ..' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: '../secret.yml',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end

      it 'returns false for absolute paths' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: '/etc/passwd',
          requesting_project: requesting_project
        )

        expect(result).to be false
      end

      it 'normalizes paths with leading ./' do
        result = setting.allows_pipeline_execution_policy_ci_config_access?(
          file_path: './test.yml',
          requesting_project: requesting_project
        )

        expect(result).to be true
      end
    end

    it 'returns false when file_path is blank' do
      result = setting.allows_pipeline_execution_policy_ci_config_access?(
        file_path: '',
        requesting_project: requesting_project
      )

      expect(result).to be false
    end
  end
end
