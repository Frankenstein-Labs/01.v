# frozen_string_literal: true

class PushRule < ApplicationRecord
  include PushRuleable
  extend Gitlab::Cache::RequestCache

  request_cache_key do
    [self.id]
  end

  belongs_to :project, inverse_of: :push_rule
  belongs_to :organization, class_name: 'Organizations::Organization'

  validates :project_id, presence: true, uniqueness: { on: :create }

  before_save :convert_to_re2

  def global?
    is_sample?
  end

  def available?(feature_sym, object: nil)
    if global?
      License.feature_available?(feature_sym)
    else
      object ||= project
      object&.feature_available?(feature_sym)
    end
  end

  def reject_unsigned_commits
    read_setting_with_global_default(:reject_unsigned_commits)
  end
  alias_method :reject_unsigned_commits?, :reject_unsigned_commits

  def reject_unsigned_commits=(value)
    write_setting_with_global_default(:reject_unsigned_commits, value)
  end

  def commit_committer_check
    read_setting_with_global_default(:commit_committer_check)
  end
  alias_method :commit_committer_check?, :commit_committer_check

  def commit_committer_check=(value)
    write_setting_with_global_default(:commit_committer_check, value)
  end

  def commit_committer_name_check
    read_setting_with_global_default(:commit_committer_name_check)
  end
  alias_method :commit_committer_name_check?, :commit_committer_name_check

  def reject_non_dco_commits
    read_setting_with_global_default(:reject_non_dco_commits)
  end
  alias_method :reject_non_dco_commits?, :reject_non_dco_commits

  def reject_non_dco_commits=(value)
    write_setting_with_global_default(:reject_non_dco_commits, value)
  end

  def regexp_uses_re2
    # Always return true to enforce RE2 usage for security
    # Database column is maintained for compatibility but ignored
    # This regexp_uses_re2 column will be deprecated and removed in the future
    # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/553148
    true
  end

  def organization
    project&.organization
  end

  private

  def convert_to_re2
    self.regexp_uses_re2 = true
  end

  request_cache def read_setting_with_global_default(setting)
    value = read_attribute(setting)

    # return if value is true/false or if current object is the global setting
    # for OrganizationPushRule this will always return value
    return value if global? || !value.nil?

    OrganizationPushRuleFinder.new(organization).execute&.public_send(setting)
  end

  def write_setting_with_global_default(setting, value)
    enabled_globally = OrganizationPushRuleFinder.new(organization).execute&.public_send(setting)
    is_disabled = !Gitlab::Utils.to_boolean(value)

    # If setting is globally disabled and user disable it at project level,
    # reset the attr so we can use the default global if required later.
    if !enabled_globally && is_disabled
      write_attribute(setting, nil)
    else
      write_attribute(setting, value)
    end
  end
end
