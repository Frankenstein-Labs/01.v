# frozen_string_literal: true

module PackageMetadata
  class SyncConfiguration
    include Gitlab::Utils::StrongMemoize

    VERSION_FORMAT_V1 = 'v1'
    VERSION_FORMAT_V2 = 'v2'
    VERSION_FORMAT_V3 = 'v3'

    PURL_TYPE_TO_REGISTRY_ID = {
      composer: "packagist",
      conan: "conan",
      gem: "rubygem",
      golang: "go",
      maven: "maven",
      npm: "npm",
      nuget: "nuget",
      pypi: "pypi",
      apk: "apk",
      rpm: "rpm",
      deb: "deb",
      'cbl-mariner': "cbl-mariner",
      wolfi: "wolfi",
      cargo: "cargo",
      swift: "swift",
      conda: "conda",
      pub: "pub",
      not_provided: "none",
      unknown: "none"
    }.with_indifferent_access.freeze

    def self.configs_for(data_type)
      case data_type
      when 'cve_enrichment'
        cve_enrichment_configs
      when 'advisories'
        advisory_configs
      when 'licenses'
        license_configs
      when 'malware_advisories'
        malware_advisory_configs
      else
        raise ArgumentError, "unsupported data type: #{data_type}"
      end
    end

    def self.cve_enrichment_configs
      storage_type, base_uri = Location.for_cve_enrichment
      [new('cve_enrichment', storage_type, base_uri, VERSION_FORMAT_V2, nil)]
    end

    def self.advisory_configs
      storage_type, base_uri = Location.for_advisories

      permitted_purl_types.map do |purl_type, _|
        new('advisories', storage_type, base_uri, VERSION_FORMAT_V2, purl_type)
      end
    end

    def self.license_configs
      storage_type, base_uri = Location.for_licenses

      permitted_purl_types.map do |purl_type, _|
        new('licenses', storage_type, base_uri, VERSION_FORMAT_V2, purl_type)
      end
    end

    def self.malware_advisory_configs
      storage_type, base_uri = Location.for_malware_advisories

      permitted_purl_types.map do |purl_type, _|
        new('malware_advisories', storage_type, base_uri, VERSION_FORMAT_V3, purl_type)
      end
    end

    def self.registry_id(purl_type)
      PURL_TYPE_TO_REGISTRY_ID[purl_type].freeze
    end

    def self.permitted_purl_types
      ::Gitlab::CurrentSettings.current_application_settings.package_metadata_purl_types_names
    end

    attr_accessor :data_type, :storage_type, :base_uri, :version_format, :purl_type

    def initialize(data_type, storage_type, base_uri, version_format, purl_type)
      @data_type = data_type
      @storage_type = storage_type
      @base_uri = base_uri
      @version_format = version_format
      @purl_type = purl_type
    end

    def v2?
      version_format == 'v2'
    end

    def advisories?
      data_type == 'advisories'
    end

    def cve_enrichment?
      data_type == 'cve_enrichment'
    end

    def malware_advisories?
      data_type == 'malware_advisories'
    end

    def to_s
      "#{data_type}:#{storage_type}/#{base_uri}/#{version_format}/#{purl_type}"
    end
    strong_memoize_attr :to_s

    class Location
      LICENSES_PATH = Rails.root.join('vendor/package_metadata/licenses').freeze
      # old licenses path did not differentiate between data_types
      OLD_LICENSES_PATH = Rails.root.join('vendor/package_metadata_db').freeze
      LICENSES_BUCKET = 'prod-export-license-bucket-1a6c642fc4de57d4'
      ADVISORIES_PATH = Rails.root.join('vendor/package_metadata/advisories').freeze
      ADVISORIES_BUCKET = 'prod-export-advisory-bucket-1a6c642fc4de57d4'
      CVE_ENRICHMENT_PATH = Rails.root.join('vendor/package_metadata/cve_enrichment').freeze
      CVE_ENRICHMENT_BUCKET = 'prod-export-cve-enrichment-bucket-1a6c642fc4de57d4'
      MALWARE_ADVISORIES_PATH = Rails.root.join('vendor/package_metadata/malware_advisories').freeze
      # PDS (PMDB Distribution Service) endpoints for online malware advisory
      # sync. See https://gitlab.com/gitlab-org/gitlab/-/work_items/602430
      PDS_MALWARE_ENDPOINT = 'https://pmdb-dist-svc.runway.gitlab.net/v1/malware/advisories'
      PDS_MALWARE_STAGING_ENDPOINT = 'https://pmdb-dist-svc.staging.runway.gitlab.net/v1/malware/advisories'

      def self.for_licenses
        if File.exist?(LICENSES_PATH)
          [:offline, LICENSES_PATH]
        elsif File.exist?(OLD_LICENSES_PATH)
          [:offline, OLD_LICENSES_PATH]
        else
          [:gcp, LICENSES_BUCKET]
        end
      end

      def self.for_advisories
        if File.exist?(ADVISORIES_PATH)
          [:offline, ADVISORIES_PATH]
        else
          [:gcp, ADVISORIES_BUCKET]
        end
      end

      def self.for_cve_enrichment
        if File.exist?(CVE_ENRICHMENT_PATH)
          [:offline, CVE_ENRICHMENT_PATH]
        else
          [:gcp, CVE_ENRICHMENT_BUCKET]
        end
      end

      # Malware advisories sync from PDS online, or from an admin-unpacked
      # vendor directory (air-gapped). Offline takes precedence when present.
      def self.for_malware_advisories
        if File.exist?(MALWARE_ADVISORIES_PATH)
          [:offline, MALWARE_ADVISORIES_PATH]
        else
          [:pds, malware_pds_endpoint]
        end
      end

      # Non-production environments (staging, development, test) use the staging
      # PDS; production uses the production PDS.
      def self.malware_pds_endpoint
        Gitlab.staging? || Gitlab.dev_or_test_env? ? PDS_MALWARE_STAGING_ENDPOINT : PDS_MALWARE_ENDPOINT
      end
    end
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/models/jh/package_metadata/sync_configuration.rb
PackageMetadata::SyncConfiguration::Location.prepend_mod
