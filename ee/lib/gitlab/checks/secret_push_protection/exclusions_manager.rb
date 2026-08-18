# frozen_string_literal: true

module Gitlab
  module Checks
    module SecretPushProtection
      class ExclusionsManager < ::Gitlab::Checks::SecretPushProtection::Base
        MAX_PATH_EXCLUSIONS_DEPTH = 20

        def active_exclusions
          @active_exclusions ||= project
            .security_exclusions
            .by_scanner(:secret_push_protection)
            .active
            .select(:type, :value)
            .group_by { |exclusion| exclusion.type.to_sym }
        end

        def matches_excluded_path?(path)
          return false if active_exclusions.empty?
          # skip paths that are too deep
          return false if path.count('/') > MAX_PATH_EXCLUSIONS_DEPTH

          # check only the maximum path exclusions allowed
          active_exclusions[:path]
            &.first(::Security::ProjectSecurityExclusion::MAX_PATH_EXCLUSIONS_PER_PROJECT)
            &.any? do |exclusion|
              matches = File.fnmatch?(
                exclusion.value,
                path,
                File::FNM_DOTMATCH | File::FNM_EXTGLOB | File::FNM_PATHNAME
              )

              audit_logger.log_exclusion_audit_event(exclusion) if matches
              matches
            end || false
        end
      end
    end
  end
end
