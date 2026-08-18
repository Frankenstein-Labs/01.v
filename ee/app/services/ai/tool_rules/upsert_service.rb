# frozen_string_literal: true

module Ai
  module ToolRules
    class UpsertService < BaseService
      def initialize(rule, current_user, params = {})
        @rule = rule
        @current_user = current_user
        @params = params
      end

      def execute
        return ServiceResponse.error(message: 'Not authorized') unless authorized?

        @rule.web_access    = @params[:web_access] unless @params[:web_access].nil?
        @rule.local_access  = @params[:local_access] unless @params[:local_access].nil?
        @rule.background_access = @params[:background_access] unless @params[:background_access].nil?

        if @rule.save
          emit_audit_event if @rule.previously_new_record? || @rule.saved_changes?
          ServiceResponse.success(payload: @rule)
        else
          ServiceResponse.error(message: @rule.errors.full_messages.join(', '))
        end
      end

      private

      def authorized?
        Ability.allowed?(current_user, :update_ai_tool_rule, @rule.project) ||
          Ability.allowed?(current_user, :update_ai_tool_rule, @rule.namespace)
      end

      def emit_audit_event
        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def audit_context
        {
          name: audit_event_name,
          author: current_user,
          scope: @rule.namespace,
          target: @rule,
          message: audit_message,
          additional_details: build_additional_details
        }
      end

      def build_additional_details
        {
          tool_name: @rule.tool_name,
          namespace_id: @rule.namespace_id,
          project_id: @rule.project_id
        }.tap do |details|
          next if @rule.previously_new_record?

          if @rule.saved_change_to_web_access?
            details[:web_access_from], details[:web_access_to] = @rule.saved_change_to_web_access
          end

          if @rule.saved_change_to_local_access?
            details[:local_access_from], details[:local_access_to] = @rule.saved_change_to_local_access
          end

          if @rule.saved_change_to_background_access?
            details[:background_access_from], details[:background_access_to] = @rule.saved_change_to_background_access
          end
        end
      end

      def audit_event_name
        @rule.previously_new_record? ? 'ai_tool_rule_created' : 'ai_tool_rule_updated'
      end

      def audit_message
        if @rule.previously_new_record?
          "Created tool rule for #{@rule.tool_name}: " \
            "web_access=#{@rule.web_access}, local_access=#{@rule.local_access}, " \
            "background_access=#{@rule.background_access}"
        else
          tracked = @rule.saved_changes.slice('web_access', 'local_access', 'background_access')
          changes = tracked.map do |attr, (from, to)|
            "#{attr} #{from}->#{to}"
          end

          return "Updated tool rule for #{@rule.tool_name}: no changes" if changes.empty?

          "Updated tool rule for #{@rule.tool_name}: #{changes.join(', ')}"
        end
      end
    end
  end
end
