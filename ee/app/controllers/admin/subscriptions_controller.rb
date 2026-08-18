# frozen_string_literal: true

# EE:Self Managed
class Admin::SubscriptionsController < Admin::ApplicationController
  respond_to :html

  feature_category :plan_provisioning
  urgency :low

  authorize! :read_admin_subscription, only: :show
end
