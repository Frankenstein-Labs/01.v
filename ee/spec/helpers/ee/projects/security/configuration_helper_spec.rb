# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::Security::ConfigurationHelper do
  let_it_be(:project) { create(:project) }

  before do
    helper.instance_variable_set(:@project, project)
  end

  describe 'group_configuration_path' do
    subject { helper.group_configuration_path }

    it { is_expected.to eq(group_security_configuration_path(project.root_ancestor)) }
  end
end
