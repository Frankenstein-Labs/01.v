# frozen_string_literal: true

module Geo
  class PushUser
    include ::Gitlab::Identifier

    def initialize(gl_id)
      @gl_id = gl_id
    end

    def user
      @user ||= identify_using_ssh_key(gl_id)
    end

    def deploy_key
      @deploy_key ||= identify_using_deploy_key(gl_id)
    end

    private

    attr_reader :gl_id
  end
end
