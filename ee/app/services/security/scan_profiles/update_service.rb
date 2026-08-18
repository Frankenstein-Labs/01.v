# frozen_string_literal: true

module Security
  module ScanProfiles
    class UpdateService
      def initialize(profile, params, current_user)
        @profile = profile
        @params = params
        @current_user = current_user
      end

      def execute
        old_snapshot = snapshot_of(profile)
        update_profile!
        audit_update(old_snapshot)

        ServiceResponse.success(payload: { scan_profile: profile })
      rescue ActiveRecord::RecordInvalid => e
        ServiceResponse.error(message: e.record.errors.full_messages.to_sentence, reason: :invalid)
      rescue ActiveRecord::RecordNotUnique
        ServiceResponse.error(
          message: s_('SecurityScanProfile|Profile was updated concurrently. Please try again.'), reason: :conflict
        )
      end

      private

      attr_reader :profile, :params, :current_user

      def update_profile!
        SecApplicationRecord.transaction do
          profile.update!(profile_attributes) if profile_attributes.any?
          sync_triggers! unless params[:triggers].nil?
          profile
        end
      end

      def profile_attributes
        params.slice(:name, :description)
      end

      def sync_triggers!
        desired = Array(params[:triggers])
        desired_types = desired.map { |trigger| trigger[:trigger_type].to_s }
        existing = profile.scan_profile_triggers.to_a

        desired.each { |trigger_params| upsert_trigger!(existing, trigger_params) }
        existing.each { |trigger| trigger.destroy! unless desired_types.include?(trigger.trigger_type) }

        profile.delete_unreferenced_configurations!
        profile.scan_profile_triggers.reset
      end

      def upsert_trigger!(existing, trigger_params)
        trigger = existing.find { |t| t.trigger_type == trigger_params[:trigger_type].to_s } ||
          profile.scan_profile_triggers.build(namespace: profile.namespace, trigger_type: trigger_params[:trigger_type])

        trigger.configuration = build_configuration(trigger_params[:configuration])
        trigger.save!
      end

      def build_configuration(config_input)
        values = configuration_values(config_input)
        return if values.blank?

        Security::ScanProfiles::Configuration.new(
          scan_profile: profile,
          namespace: profile.namespace,
          configuration: values
        )
      end

      def configuration_values(config_input)
        return if config_input.blank?
        return config_input unless params[:strip_defaults]

        Security::ScanProfiles::Configuration.strip_defaults(
          config_input, Security::ScanProfiles::Configuration.defaults_for(profile.scan_type)
        )
      end

      def audit_update(old_snapshot)
        Security::ScanProfiles::Audit::UpdateService.new(
          profile: profile,
          current_user: current_user,
          old_snapshot: old_snapshot,
          new_snapshot: snapshot_of(profile)
        ).execute
      end

      def snapshot_of(profile)
        triggers = profile.scan_profile_triggers.reset.to_a
        # Preload configurations to avoid N+1 when reading each trigger's stored config.
        ActiveRecord::Associations::Preloader.new(records: triggers, associations: [:configuration]).call

        {
          name: profile.name,
          description: profile.description,
          triggers: triggers.each_with_object({}) do |trigger, result|
            result[trigger.trigger_type] = (trigger.configuration&.configuration || {}).deep_symbolize_keys
          end
        }
      end
    end
  end
end
