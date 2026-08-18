# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::HasRolePermissions, feature_category: :duo_agent_platform do
  let(:role_permission_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'ai_settings'

      include Ai::HasRolePermissions
    end
  end

  subject(:instance) { RolePermission.new }

  before do
    stub_const('RolePermission', role_permission_class)
  end

  describe 'validations' do
    describe '#minimum_access_level_execute' do
      it 'validates inclusion in valid access levels' do
        expect(instance).to validate_inclusion_of(:minimum_access_level_execute)
          .in_array(Gitlab::Access.sym_options_with_admin.values).allow_nil
      end

      it 'validates numericality greater than or equal to GUEST' do
        expect(instance).to validate_numericality_of(:minimum_access_level_execute)
          .is_greater_than_or_equal_to(Gitlab::Access::GUEST)
      end
    end

    describe '#minimum_access_level_execute_async' do
      it 'validates inclusion in valid access levels' do
        expect(instance).to validate_inclusion_of(:minimum_access_level_execute_async)
          .in_array(Gitlab::Access.sym_options_with_admin.values).allow_nil
      end

      it 'validates numericality greater than or equal to DEVELOPER' do
        expect(instance).to validate_numericality_of(:minimum_access_level_execute_async)
          .is_greater_than_or_equal_to(Gitlab::Access::DEVELOPER)
      end
    end

    describe '#minimum_access_level_manage' do
      it 'validates inclusion in valid access levels' do
        expect(instance).to validate_inclusion_of(:minimum_access_level_manage)
          .in_array(Gitlab::Access.sym_options_with_admin.values).allow_nil
      end

      it 'validates numericality greater than or equal to DEVELOPER' do
        expect(instance).to validate_numericality_of(:minimum_access_level_manage)
          .is_greater_than_or_equal_to(Gitlab::Access::DEVELOPER)
      end
    end

    describe '#minimum_access_level_enable_on_projects' do
      it 'validates inclusion in valid access levels' do
        expect(instance).to validate_inclusion_of(:minimum_access_level_enable_on_projects)
          .in_array(Gitlab::Access.sym_options_with_admin.values).allow_nil
      end

      it 'validates numericality greater than or equal to DEVELOPER' do
        expect(instance).to validate_numericality_of(:minimum_access_level_enable_on_projects)
          .is_greater_than_or_equal_to(Gitlab::Access::DEVELOPER)
      end
    end
  end
end
