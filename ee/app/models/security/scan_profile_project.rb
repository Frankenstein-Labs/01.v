# frozen_string_literal: true

module Security
  class ScanProfileProject < ::SecApplicationRecord
    self.table_name = 'security_scan_profiles_projects'

    MAX_PROFILES_PER_PROJECT = 10

    belongs_to :project, optional: false
    belongs_to :scan_profile, class_name: 'Security::ScanProfile', foreign_key: :security_scan_profile_id,
      inverse_of: :scan_profile_projects, optional: false

    validates :project_id, uniqueness: { scope: :security_scan_profile_id }

    scope :for_projects_and_profile, ->(projects, scan_profile) {
      where(project: projects, scan_profile: scan_profile)
    }

    scope :by_project_id, ->(project_id) { where(project_id: project_id) }
    scope :for_scan_profile, ->(scan_profile_id) { where(security_scan_profile_id: scan_profile_id) }
    scope :not_in_root_namespace, ->(root_namespace) {
      joins(:scan_profile).where.not(security_scan_profiles: { namespace: root_namespace })
    }
  end
end
