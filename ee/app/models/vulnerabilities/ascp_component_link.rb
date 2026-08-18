# frozen_string_literal: true

module Vulnerabilities
  class AscpComponentLink < ::SecApplicationRecord
    self.table_name = 'vulnerability_finding_ascp_component_links'

    belongs_to :vulnerability_finding,
      class_name: 'Vulnerabilities::Finding',
      foreign_key: :vulnerability_occurrence_id,
      inverse_of: :ascp_component_link,
      optional: false
    belongs_to :ascp_component,
      class_name: 'Security::Ascp::Component',
      inverse_of: :vulnerability_finding_ascp_component_links,
      optional: false
    belongs_to :project, optional: false

    validates :vulnerability_occurrence_id, uniqueness: true

    scope :by_finding_ids, ->(finding_ids) { where(vulnerability_occurrence_id: finding_ids) }
  end
end
