# frozen_string_literal: true

module Namespaces
  class TrialEligibleFinder
    include Gitlab::Utils::StrongMemoize

    EXPIRATION_TIME = 8.hours

    def initialize(params = {})
      @params = params
    end

    def execute
      namespaces = scope_by_plans.in_specific_plans(eligible_plans)
      return Namespace.none if namespaces.empty?

      build_namespaces_trial_type(namespaces)
      namespaces.id_in(find_eligible_namespace_ids).ordered_by_name
    end

    private

    attr_reader :params, :namespaces_trial_type

    def build_namespaces_trial_type(namespaces)
      @namespaces_trial_type = namespaces.to_h { |namespace| [namespace.id, namespace_trial_type(namespace)] }
    end

    def namespace_ids
      namespaces_trial_type.keys
    end

    def namespace_trial_type(namespace)
      GitlabSubscriptions::Trials.trial_type_for_namespace(namespace)
    end

    def scope_by_plans
      if params[:user] && params[:namespace]
        raise ArgumentError, 'Only User or Namespace can be provided, not both'
      elsif params[:user]
        params[:user].owned_groups
      elsif params[:namespace]
        Namespace.id_in(params[:namespace])
      else
        raise ArgumentError, 'User or Namespace must be provided'
      end
    end

    def no_subscription_plan_name
      # Subscriptions aren't created until needed/looked at
      nil
    end

    def eligible_plans
      [no_subscription_plan_name, *::Plan::PLANS_ELIGIBLE_FOR_TRIAL]
    end

    def find_eligible_namespace_ids
      if cache_exists?
        cached_eligible_namespace_ids
      else
        cache_eligible_namespace_ids
      end
    end

    def client
      Gitlab::SubscriptionPortal::Client
    end

    def cache_key(id)
      "namespaces:eligible_trials:#{id}"
    end

    def cache_keys
      namespace_ids.map { |id| cache_key(id) }
    end
    strong_memoize_attr :cache_keys

    def cache_exists?
      cache_keys.all? { |key| Rails.cache.exist?(key) }
    end

    def filter_namespace_ids(id_trials_hash)
      id_trials_hash.filter_map do |id, eligible_trial_types|
        id if namespaces_trial_type[id.to_i].in?(eligible_trial_types)
      end
    end

    def cached_eligible_namespace_ids
      values = Rails.cache.read_multi(*cache_keys).values
      filter_namespace_ids(Hash[namespace_ids.zip(values)])
    end

    def eligible_trials_request
      response = client.namespace_eligible_trials(namespace_ids: namespace_ids)

      if response[:success]
        response.dig(:data, :namespaces)
      else
        Gitlab::AppLogger.warn(
          class: self.class.name,
          message: 'Unable to fetch eligible trials from GitLab Customers App',
          error_message: response.dig(:data, :errors)
        )

        {}
      end
    end

    def cache_eligible_namespace_ids
      response_data = eligible_trials_request
      return [] if response_data.blank?

      Rails.cache.write_multi(
        response_data.transform_keys { |id| cache_key(id) },
        expires_in: EXPIRATION_TIME
      )

      filter_namespace_ids(response_data)
    end
  end
end
