# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectSecurityExclusionPolicy, feature_category: :secret_detection do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:security_exclusion) { create(:project_security_exclusion, :with_raw_value, :active, project: project) }

  subject { described_class.new(user, security_exclusion) }

  describe 'manage_project_security_exclusions' do
    context 'when the current user can manage project security exclusions' do
      before_all do
        project.add_maintainer(user)
      end

      it { is_expected.to be_allowed(:manage_project_security_exclusions) }
    end

    context 'when the current user cannot manage project security exclusions' do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.to be_disallowed(:manage_project_security_exclusions) }
    end
  end

  describe 'read_project_security_exclusions' do
    context 'when the current user can read project security exclusions' do
      before_all do
        project.add_maintainer(user)
      end

      it { is_expected.to be_allowed(:read_project_security_exclusions) }
    end

    context 'when the current user cannot read project security exclusions' do
      before_all do
        project.add_reporter(user)
      end

      it { is_expected.to be_disallowed(:read_project_security_exclusions) }
    end
  end
end
