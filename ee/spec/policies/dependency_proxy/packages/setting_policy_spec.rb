# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::Packages::SettingPolicy, feature_category: :package_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'ProjectPolicy context'

  let(:project) { public_project }
  let(:setting) { create(:dependency_proxy_packages_setting, project: project) }

  subject { described_class.new(current_user, setting) }

  before do
    stub_feature_flags(allow_guest_plus_roles_to_pull_packages: false)
  end

  describe 'read_package', :enable_admin_mode do
    where(:project, :current_user, :allowed?) do
      ref(:public_project)   | ref(:anonymous)  | false
      ref(:public_project)   | ref(:non_member) | false
      ref(:public_project)   | ref(:guest)      | true
      ref(:public_project)   | ref(:reporter)   | true
      ref(:public_project)   | ref(:developer)  | true
      ref(:public_project)   | ref(:maintainer) | true
      ref(:public_project)   | ref(:owner)      | true
      ref(:public_project)   | ref(:admin)      | true

      ref(:internal_project) | ref(:anonymous)  | false
      ref(:internal_project) | ref(:non_member) | false
      ref(:internal_project) | ref(:guest)      | true
      ref(:internal_project) | ref(:reporter)   | true
      ref(:internal_project) | ref(:developer)  | true
      ref(:internal_project) | ref(:maintainer) | true
      ref(:internal_project) | ref(:owner)      | true
      ref(:internal_project) | ref(:admin)      | true

      ref(:private_project)  | ref(:anonymous)  | false
      ref(:private_project)  | ref(:non_member) | false
      ref(:private_project)  | ref(:guest)      | false
      ref(:private_project)  | ref(:reporter)   | true
      ref(:private_project)  | ref(:developer)  | true
      ref(:private_project)  | ref(:maintainer) | true
      ref(:private_project)  | ref(:owner)      | true
      ref(:private_project)  | ref(:admin)      | true
    end

    with_them do
      if params[:allowed?]
        it { expect_allowed(:read_package) }
      else
        it { expect_disallowed(:read_package) }
      end
    end

    context 'with deploy token' do
      subject { described_class.new(deploy_token, setting) }

      context 'when a deploy token with read_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_package_registry: true, projects: [project]) }

        it { expect_allowed(:read_package) }
      end

      context 'when a deploy token with write_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, write_package_registry: true, projects: [project]) }

        it { expect_allowed(:read_package) }
      end
    end
  end

  describe 'create_package', :enable_admin_mode do
    where(:project, :current_user, :allowed?) do
      ref(:public_project)   | ref(:anonymous)  | false
      ref(:public_project)   | ref(:non_member) | false
      ref(:public_project)   | ref(:guest)      | false
      ref(:public_project)   | ref(:reporter)   | false
      ref(:public_project)   | ref(:developer)  | true
      ref(:public_project)   | ref(:maintainer) | true
      ref(:public_project)   | ref(:owner)      | true
      ref(:public_project)   | ref(:admin)      | true

      ref(:internal_project) | ref(:anonymous)  | false
      ref(:internal_project) | ref(:non_member) | false
      ref(:internal_project) | ref(:guest)      | false
      ref(:internal_project) | ref(:reporter)   | false
      ref(:internal_project) | ref(:developer)  | true
      ref(:internal_project) | ref(:maintainer) | true
      ref(:internal_project) | ref(:owner)      | true
      ref(:internal_project) | ref(:admin)      | true

      ref(:private_project)  | ref(:anonymous)  | false
      ref(:private_project)  | ref(:non_member) | false
      ref(:private_project)  | ref(:guest)      | false
      ref(:private_project)  | ref(:reporter)   | false
      ref(:private_project)  | ref(:developer)  | true
      ref(:private_project)  | ref(:maintainer) | true
      ref(:private_project)  | ref(:owner)      | true
      ref(:private_project)  | ref(:admin)      | true
    end

    with_them do
      if params[:allowed?]
        it { expect_allowed(:create_package) }
      else
        it { expect_disallowed(:create_package) }
      end
    end

    context 'with deploy token' do
      subject { described_class.new(deploy_token, setting) }

      context 'when a deploy token with read_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_package_registry: true, projects: [project]) }

        it { expect_disallowed(:create_package) }
      end

      context 'when a deploy token with write_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, write_package_registry: true, projects: [project]) }

        it { expect_allowed(:create_package) }
      end
    end
  end

  describe 'destroy_package', :enable_admin_mode do
    where(:project, :current_user, :allowed?) do
      ref(:public_project)   | ref(:anonymous)  | false
      ref(:public_project)   | ref(:non_member) | false
      ref(:public_project)   | ref(:guest)      | false
      ref(:public_project)   | ref(:reporter)   | false
      ref(:public_project)   | ref(:developer)  | false
      ref(:public_project)   | ref(:maintainer) | true
      ref(:public_project)   | ref(:owner)      | true
      ref(:public_project)   | ref(:admin)      | true

      ref(:internal_project) | ref(:anonymous)  | false
      ref(:internal_project) | ref(:non_member) | false
      ref(:internal_project) | ref(:guest)      | false
      ref(:internal_project) | ref(:reporter)   | false
      ref(:internal_project) | ref(:developer)  | false
      ref(:internal_project) | ref(:maintainer) | true
      ref(:internal_project) | ref(:owner)      | true
      ref(:internal_project) | ref(:admin)      | true

      ref(:private_project)  | ref(:anonymous)  | false
      ref(:private_project)  | ref(:non_member) | false
      ref(:private_project)  | ref(:guest)      | false
      ref(:private_project)  | ref(:reporter)   | false
      ref(:private_project)  | ref(:developer)  | false
      ref(:private_project)  | ref(:maintainer) | true
      ref(:private_project)  | ref(:owner)      | true
      ref(:private_project)  | ref(:admin)      | true
    end

    with_them do
      if params[:allowed?]
        it { expect_allowed(:destroy_package) }
      else
        it { expect_disallowed(:destroy_package) }
      end
    end

    context 'with deploy token' do
      subject { described_class.new(deploy_token, setting) }

      context 'when a deploy token with read_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_package_registry: true, projects: [project]) }

        it { expect_disallowed(:destroy_package) }
      end

      context 'when a deploy token with write_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, write_package_registry: true, projects: [project]) }

        it { expect_allowed(:destroy_package) }
      end
    end
  end

  describe 'admin_dependency_proxy_packages_settings', :enable_admin_mode do
    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(dependency_proxy_for_packages: true)
    end

    where(:project, :current_user, :allowed?) do
      ref(:public_project)   | ref(:anonymous)  | false
      ref(:public_project)   | ref(:non_member) | false
      ref(:public_project)   | ref(:guest)      | false
      ref(:public_project)   | ref(:reporter)   | false
      ref(:public_project)   | ref(:developer)  | false
      ref(:public_project)   | ref(:maintainer) | true
      ref(:public_project)   | ref(:owner)      | true
      ref(:public_project)   | ref(:admin)      | true

      ref(:internal_project) | ref(:anonymous)  | false
      ref(:internal_project) | ref(:non_member) | false
      ref(:internal_project) | ref(:guest)      | false
      ref(:internal_project) | ref(:reporter)   | false
      ref(:internal_project) | ref(:developer)  | false
      ref(:internal_project) | ref(:maintainer) | true
      ref(:internal_project) | ref(:owner)      | true
      ref(:internal_project) | ref(:admin)      | true

      ref(:private_project)  | ref(:anonymous)  | false
      ref(:private_project)  | ref(:non_member) | false
      ref(:private_project)  | ref(:guest)      | false
      ref(:private_project)  | ref(:reporter)   | false
      ref(:private_project)  | ref(:developer)  | false
      ref(:private_project)  | ref(:maintainer) | true
      ref(:private_project)  | ref(:owner)      | true
      ref(:private_project)  | ref(:admin)      | true
    end

    with_them do
      if params[:allowed?]
        it { expect_allowed(:admin_dependency_proxy_packages_settings) }
      else
        it { expect_disallowed(:admin_dependency_proxy_packages_settings) }
      end
    end
  end

  context 'with project feature packages disabled' do
    let(:current_user) { owner }

    before do
      setting.project.project_feature.update!(package_registry_access_level: ProjectFeature::DISABLED)
    end

    it { expect_disallowed(:read_package) }
    it { expect_disallowed(:create_package) }
    it { expect_disallowed(:destroy_package) }
    it { expect_disallowed(:admin_package) }
    it { expect_disallowed(:admin_dependency_proxy_packages_settings) }
  end

  %i[packages dependency_proxy].each do |feature|
    context "with config #{feature} disabled" do
      let(:current_user) { owner }

      before do
        stub_config(feature => { enabled: false })
      end

      it { expect_disallowed(:admin_dependency_proxy_packages_settings) }
    end
  end

  context 'with licensed dependency proxy for packages disabled' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(dependency_proxy_for_packages: false)
    end

    it { expect_disallowed(:admin_dependency_proxy_packages_settings) }
  end

  context 'with ip restriction' do
    let_it_be_with_reload(:current_user) { create(:admin) }
    let_it_be_with_reload(:group) { create(:group, :public) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    before_all do
      group.add_maintainer(current_user)
    end

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
      stub_licensed_features(group_ip_restriction: true)
    end

    context 'with group without restriction' do
      it { expect_allowed(:read_package) }
      it { expect_allowed(:create_package) }
      it { expect_allowed(:destroy_package) }
      it { expect_allowed(:admin_package) }
    end

    context 'with group with restriction' do
      before do
        create(:ip_restriction, group: group, range: range)
      end

      context 'with address is within the range' do
        let(:range) { '192.168.0.0/24' }

        it { expect_allowed(:read_package) }
        it { expect_allowed(:create_package) }
        it { expect_allowed(:destroy_package) }
        it { expect_allowed(:admin_package) }
      end

      context 'with address is outside the range' do
        let(:range) { '10.0.0.0/8' }

        it { expect_disallowed(:read_package) }
        it { expect_disallowed(:create_package) }
        it { expect_disallowed(:destroy_package) }
        it { expect_disallowed(:admin_package) }
        it { expect_disallowed(:update_package) }

        context 'with admin enabled', :enable_admin_mode do
          it { expect_allowed(:read_package) }
          it { expect_allowed(:create_package) }
          it { expect_allowed(:destroy_package) }
          it { expect_allowed(:admin_package) }
        end

        context 'with admin disabled' do
          it { expect_disallowed(:read_package) }
          it { expect_disallowed(:create_package) }
          it { expect_disallowed(:destroy_package) }
          it { expect_disallowed(:admin_package) }
        end

        context 'with auditor' do
          let_it_be(:auditor) { create(:user, :auditor) }

          subject { described_class.new(auditor, setting) }

          before_all do
            group.add_maintainer(auditor)
          end

          it { expect_allowed(:read_package) }
          it { expect_allowed(:create_package) }
          it { expect_allowed(:destroy_package) }
          it { expect_allowed(:admin_package) }
        end
      end
    end
  end
end
