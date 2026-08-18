# frozen_string_literal: true

module Types
  module Security
    class ScanProfileTriggerTypeEnum < BaseEnum
      graphql_name 'ScanProfileTriggerType'
      description 'Scan profile trigger type'

      Enums::Security.scan_profile_trigger_types.except(:sbom_ingested).each_key do |name|
        value(
          name.to_s.upcase,
          value: name.to_s,
          description: name.to_s.humanize
        )
      end

      value 'SBOM_INGESTED',
        value: 'sbom_ingested',
        description: 'SBOM ingested.',
        experiment: { milestone: '19.2' }
    end
  end
end
