# frozen_string_literal: true

module ComplianceManagement
  class FrameworkPolicy < BasePolicy
    delegate { @subject.namespace }

    condition(:compliance_framework_available, scope: :subject) do
      @subject.namespace.feature_available?(:custom_compliance_frameworks)
    end

    condition(:group_level_compliance_pipeline_available, scope: :subject) do
      @subject.namespace.feature_available?(:evaluate_group_level_compliance_pipeline)
    end

    condition(:read_root_group) do
      @user.can?(:read_group, @subject.namespace.root_ancestor)
    end

    rule { ~group_level_compliance_pipeline_available }.prevent :admin_compliance_pipeline_configuration

    rule { read_root_group & compliance_framework_available }.policy do
      enable :read_compliance_framework
      enable :read_compliance_adherence_report
    end

    rule { can?(:admin_compliance_framework) & compliance_framework_available }.policy do
      enable :read_compliance_framework
      enable :read_compliance_adherence_report
    end

    rule { can?(:admin_compliance_framework) & group_level_compliance_pipeline_available }.policy do
      enable :admin_compliance_pipeline_configuration
    end
  end
end
