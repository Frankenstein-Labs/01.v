# frozen_string_literal: true

module SecretsManagement
  class TestJwt < GlobalSecretsManagerJwt
    def initialize(project_id: nil, aud: nil, user_id: nil, user_name: nil, scope: :global, token_ttl: nil, **_)
      super()
      @test_project_id = project_id
      @test_aud        = aud
      @test_user_id    = user_id
      @test_user_name  = user_name
      @scope = scope
      @token_ttl = token_ttl
    end

    def payload
      claims = super
      claims[:sub] = sub
      claims[:secrets_manager_scope] = secrets_manager_scope
      claims[:secrets_manager_token_ttl] = @token_ttl unless @token_ttl.nil?
      claims
    end

    private

    def aud
      @test_aud || super
    end

    def resource_claims
      {
        user_id: @test_user_id || '0',
        project_id: @test_project_id,
        user_login: 'test-system',
        namespace_id: '0'
      }.compact
    end

    def secrets_manager_scope
      if @scope == :user
        'user'
      elsif @scope == :global
        'privileged'
      end
    end

    def sub
      if @scope == :user
        @test_user_name ? "user:#{@test_user_name}" : nil
      elsif @scope == :global
        'gitlab_secrets_manager'
      end
    end
  end
end
