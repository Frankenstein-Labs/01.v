# frozen_string_literal: true

module Security
  module DependencyFirewall
    class PolicyEvaluator
      include Gitlab::Utils::StrongMemoize

      def initialize(project, current_user)
        @project = project
        @current_user = current_user
      end

      # example PURL breakdown for maven/org.apache.xmlgraphics/batik-anim@1.9.1
      # name: org.apache.xmlgraphics/batik-anim
      # purl_type: maven
      # version: 1.9.1 (optional)
      def evaluate(name, purl_type:, version: nil, licenses: [], vulnerabilities: [], malicious_packages: [])
        return [] unless Availability.feature_flag_enabled?(project)

        evaluate_policies(
          { name: name, purl_type: purl_type, version: version },
          licenses,
          policies,
          vulnerabilities,
          malicious_packages
        )
      end

      private

      attr_reader :project, :current_user

      def evaluate_policies(package, licenses, policies, vulnerabilities, malicious_packages)
        policies.map do |policy|
          bypass_settings = policy.bypass_settings

          if bypass_settings.user_bypassed?(@current_user)
            {
              action: ::Security::DependencyFirewallPolicies::Rule::ACTION_ALLOWED,
              reason: :user_bypassed,
              policy_name: policy.name
            }
          elsif bypass_settings.access_token_bypassed?(@current_user)
            {
              action: ::Security::DependencyFirewallPolicies::Rule::ACTION_ALLOWED,
              reason: :token_bypassed,
              policy_name: policy.name
            }
          else
            matching_rules = policy.rules.filter_map do |rule|
              result = rule.evaluate(package, metadata: {
                licenses: licenses,
                vulnerabilities: vulnerabilities,
                malicious_packages: malicious_packages
              })
              result&.merge(rule: rule)
            end

            policy_result(matching_rules, policy.enforcement_type).merge(policy_name: policy.name)
          end
        end
      end

      def policies
        return [] unless project

        project.security_policies
               .enabled
               .type_dependency_firewall_policy
               .preload(:undeleted_dependency_firewall_policy_rules) # rubocop: disable CodeReuse/ActiveRecord -- not an ActiveRecord model
               .map(&:dependency_firewall_policy)
      end
      strong_memoize_attr :policies

      def policy_result(matched_rules, enforcement_type)
        denied_rule = matched_rules.find { |rule| rule[:action] == ::Security::DependencyFirewallPolicies::Rule::ACTION_DENIED }

        if denied_rule
          # Default to 'enforced' (denied) if nil/missing for security
          if enforcement_type == 'warn'
            return build_result(
              ::Security::DependencyFirewallPolicies::Rule::ACTION_WARNED,
              ::Security::DependencyFirewallPolicies::Rule::REASON_EVALUATION,
              matched_rule: denied_rule[:rule])
          end

          return build_result(
            ::Security::DependencyFirewallPolicies::Rule::ACTION_DENIED,
            ::Security::DependencyFirewallPolicies::Rule::REASON_EVALUATION,
            matched_rule: denied_rule[:rule])
        end

        if matched_rules.empty?
          return build_result(
            ::Security::DependencyFirewallPolicies::Rule::ACTION_ALLOWED,
            ::Security::DependencyFirewallPolicies::Rule::REASON_NO_MATCHES)
        end

        all_rules_exceptions = matched_rules.all? do |rule|
          rule[:action] == ::Security::DependencyFirewallPolicies::Rule::ACTION_ALLOWED &&
            rule[:reason] == ::Security::DependencyFirewallPolicies::Rule::REASON_EXCEPTION
        end

        if all_rules_exceptions
          return build_result(
            ::Security::DependencyFirewallPolicies::Rule::ACTION_ALLOWED,
            ::Security::DependencyFirewallPolicies::Rule::REASON_EXCEPTION)
        end

        build_result(
          ::Security::DependencyFirewallPolicies::Rule::ACTION_ALLOWED,
          ::Security::DependencyFirewallPolicies::Rule::REASON_EVALUATION)
      end

      def build_result(action, reason, matched_rule: nil)
        result = { action: action, reason: reason }
        result[:matched_rule] = matched_rule if matched_rule
        result
      end
    end
  end
end
