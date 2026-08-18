# frozen_string_literal: true

module API
  module GitlabSubscriptions
    class AddOnPurchases < ::API::Base
      feature_category :subscription_management
      urgency :low

      before do
        @namespace = find_namespace(params[:id])

        not_found!('Namespace') unless @namespace

        @add_on = find_or_create_subscription_add_on!(params[:add_on_name], @namespace)
      end

      resource :namespaces, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
        desc 'Create an add-on purchase for the namespace' do
          tags ['add_on_purchases']
          detail 'Deprecated in GitLab 17.7'
          success ::API::Entities::GitlabSubscriptions::AddOnPurchase
          failure [
            { code: 400, message: 'Bad request' },
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' }
          ]
          deprecated true
        end
        params do
          requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the namespace'
          requires :add_on_name, type: String, desc: 'The name of the add-on'
          requires :quantity, type: Integer, desc: 'The quantity of the purchase'
          requires :started_on, type: Date, desc: 'The date when purchase takes effect'
          requires :expires_on, type: Date, desc: 'The date when purchase expires on'
          requires :purchase_xid, type: String, desc: 'The purchase identifier (example: the subscription name)'
          optional :trial, type: Boolean, default: false, desc: 'Whether the add-on is a trial'
        end
        route_setting :authorization, permissions: :create_add_on_purchase, boundary_type: :instance
        post ":id/subscription_add_on_purchase/:add_on_name" do
          result = ::GitlabSubscriptions::AddOnPurchases::CreateService.new(
            @namespace,
            @add_on,
            declared_params
          ).execute

          if result[:status] == :success
            present result[:add_on_purchase], with: ::API::Entities::GitlabSubscriptions::AddOnPurchase
          elsif result[:add_on_purchase].nil?
            bad_request!(result[:message])
          else
            render_validation_error!(result[:add_on_purchase])
          end
        end

        desc 'Returns an add-on purchase for the namespace' do
          tags ['add_on_purchases']
          detail 'Deprecated in GitLab 17.7'
          success ::API::Entities::GitlabSubscriptions::AddOnPurchase
          failure [
            { code: 400, message: 'Bad request' },
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' }
          ]
          deprecated true
        end
        params do
          requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the namespace'
          requires :add_on_name, type: String, desc: 'The name of the add-on'
        end
        route_setting :authorization, permissions: :read_add_on_purchase, boundary_type: :instance
        get ":id/subscription_add_on_purchase/:add_on_name" do
          add_on_purchase = find_subscription_add_on_purchase!(@namespace, @add_on)

          present add_on_purchase, with: ::API::Entities::GitlabSubscriptions::AddOnPurchase
        end

        desc 'Update the add-on purchase for the namespace' do
          tags ['add_on_purchases']
          detail 'Deprecated in GitLab 17.7'
          success ::API::Entities::GitlabSubscriptions::AddOnPurchase
          failure [
            { code: 400, message: 'Bad request' },
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' }
          ]
          deprecated true
        end
        params do
          requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the namespace'
          requires :add_on_name, type: String, desc: 'The name of the add-on'
          requires :started_on, type: Date, desc: 'The date when purchase takes effect'
          requires :expires_on, type: Date, desc: 'The date when purchase expires on'
          optional :quantity, type: Integer, desc: 'The quantity of the purchase'
          optional :purchase_xid, type: String, desc: 'The purchase identifier (example: the subscription name)'
          optional :trial, type: Boolean, desc: 'Whether the add-on is a trial'
        end
        route_setting :authorization, permissions: :update_add_on_purchase, boundary_type: :instance
        put ":id/subscription_add_on_purchase/:add_on_name" do
          result = ::GitlabSubscriptions::AddOnPurchases::UpdateService.new(
            @namespace,
            @add_on,
            declared_params
          ).execute

          if result[:status] == :success
            present result[:add_on_purchase], with: ::API::Entities::GitlabSubscriptions::AddOnPurchase
          elsif result[:add_on_purchase].nil?
            bad_request!(result[:message])
          else
            render_validation_error!(result[:add_on_purchase])
          end
        end
      end
    end
  end
end
