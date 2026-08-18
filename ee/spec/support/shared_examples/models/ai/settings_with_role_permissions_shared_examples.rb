# frozen_string_literal: true

RSpec.shared_examples 'settings with role permissions' do
  describe 'database columns' do
    it { is_expected.to have_db_column(:minimum_access_level_execute).of_type(:integer) }
    it { is_expected.to have_db_column(:minimum_access_level_execute_async).of_type(:integer) }
    it { is_expected.to have_db_column(:minimum_access_level_manage).of_type(:integer) }
    it { is_expected.to have_db_column(:minimum_access_level_enable_on_projects).of_type(:integer) }
  end
end
