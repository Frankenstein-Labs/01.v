# frozen_string_literal: true

module ProductAnalytics
  class InitializeStackService < BaseContainerService
    include Gitlab::Utils::StrongMemoize

    def execute
      return feature_availability_error if feature_availability_error.present?

      unless can?(current_user, :update_product_analytics_settings, container)
        return ServiceResponse.error(message: 'User is not authorized to initialize product analytics')
      end

      return status_error if status_error.present?

      ServiceResponse.success(message: 'Product analytics service is no longer supported')
    end

    def lock!
      Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, 1) }
    end

    def unlock!
      Gitlab::Redis::SharedState.with { |redis| redis.del(redis_key) }
    end

    private

    def redis_key
      "project:#{container.id}:product_analytics_initializing"
    end

    def locked?
      !!Gitlab::Redis::SharedState.with { |redis| redis.get(redis_key) }
    end

    def feature_availability_error
      unless Gitlab::CurrentSettings.product_analytics_enabled?
        return ServiceResponse.error(message: 'Product analytics is disabled')
      end

      return if container.product_analytics_enabled? && container.connected_to_cluster?

      ServiceResponse.error(message: 'Product analytics is disabled for this project')
    end
    strong_memoize_attr :feature_availability_error

    def status_error
      return ServiceResponse.error(message: 'Product analytics initialization is already in progress') if locked?
      return unless container.project_setting.product_analytics_instrumentation_key.present?

      ServiceResponse.error(message: 'Product analytics initialization is already complete')
    end
    strong_memoize_attr :status_error
  end
end
