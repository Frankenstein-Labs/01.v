# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PolicyComparer
      include ::Gitlab::Utils::StrongMemoize

      attr_reader :db_policy, :yaml_policy, :policy_index

      def initialize(db_policy:, yaml_policy:, policy_index:)
        @db_policy = db_policy
        @yaml_policy = yaml_policy
        @policy_index = policy_index
      end

      def diff
        diff = Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.new
        compare_policy_fields(diff)
        compare_rules(diff)

        diff
      end
      strong_memoize_attr :diff

      def event_payload
        diff_hash = diff.to_h
        {
          security_policy_id: db_policy.id,
          diff: diff_hash[:diff],
          rules_diff: diff_hash[:rules_diff]
        }
      end

      private

      def db_policy_hash
        db_policy.to_policy_hash
      end
      strong_memoize_attr :db_policy_hash

      def compare_policy_fields(diff)
        # policy type cannot be updated, so it can be ignored
        all_keys = (Array.wrap(db_policy_hash.keys) + Array.wrap(yaml_policy.keys)).uniq - [:rules, :type]
        all_keys.each do |key|
          db_value = db_policy_hash[key]
          yaml_value = yaml_policy[key]

          next if db_value == yaml_value || (db_value.blank? && yaml_value.blank?)

          diff.add_policy_field(key, db_value, yaml_value)
        end
      end

      def compare_rules(diff)
        db_rules = Array.wrap(db_policy.rules)
        yaml_rules = Array.wrap(yaml_policy[:rules])

        created = []
        deleted = []

        if yaml_rules.count > db_rules.count
          created = yaml_rules.last(yaml_rules.count - db_rules.count)
        elsif db_rules.count > yaml_rules.count
          deleted = db_rules.last(db_rules.count - yaml_rules.count)
        end

        created.each { |rule| diff.add_created_rule(rule) }
        deleted.each { |rule| diff.add_deleted_rule(rule) }

        common_count = [db_rules.count, yaml_rules.count].min
        yaml_rules.first(common_count).zip(db_rules.first(common_count))
          .select { |yaml_rule, db_rule| yaml_rule != db_rule.typed_content.deep_symbolize_keys }
          .map { |(yaml_rule, db_rule)| diff.add_updated_rule(db_rule, db_rule, yaml_rule) }
      end
    end
  end
end
