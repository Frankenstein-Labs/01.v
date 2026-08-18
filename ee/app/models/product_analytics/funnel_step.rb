# frozen_string_literal: true

module ProductAnalytics
  class FunnelStep
    include ActiveModel::Validations

    attr_accessor :name, :target, :action

    # This model is not used as a true ActiveRecord
    # You must run .valid? wherever this model is used for these validations to be run
    validates :action, inclusion: { in: %w[pageview] }
    validates :name, format: { with: /\A[\w\-]+\z/ }
    validates :target, format: { with: %r{\A[\w\-./]+\z} }

    def initialize(name:, target:, action:, funnel:)
      @name = name
      @target = target
      @action = action
      @funnel = funnel
    end

    def step_definition
      path_name = 'page_urlpath'
      "#{path_name} = '#{target}'" if action == 'pageview'
    end

    def to_h
      { name: @name, target: @target, action: @action }
    end
  end
end
