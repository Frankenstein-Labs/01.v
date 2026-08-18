# frozen_string_literal: true

RSpec.shared_examples 'ai permission to' do |ability|
  using RSpec::Parameterized::TableSyntax

  where(:role, :ai_analytics_licensed, :allowed) do
    :guest    | false | false
    :guest    | true  | false
    :reporter | false | false
    :reporter | true  | true
  end

  with_them do
    let(:current_user) { public_send(role) }

    before do
      stub_licensed_features(ai_analytics: ai_analytics_licensed)
    end

    it { is_expected.to(allowed ? be_allowed(ability) : be_disallowed(ability)) }
  end
end
