# frozen_string_literal: true

RSpec.shared_examples 'a duo workflow link type' do
  it { expect(described_class).to require_graphql_authorizations(:read_duo_workflow) }

  it 'requires the read_duo_workflow granular token scope at the user boundary' do
    directive = described_class.directives.find { |d| d.is_a?(Directives::Authz::GranularScope) }

    expect(directive).to be_present
    expect(directive.arguments[:permissions]).to eq(['read_duo_workflow'])
    expect(directive.arguments[:boundary]).to eq('user')
    expect(directive.arguments[:boundary_type]).to eq('user')
  end

  describe 'inherited fields' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name) do
      %w[workflow createdAt]
    end

    with_them do
      it "exposes the #{params[:field_name]} field with the AI token scopes" do
        field = described_class.fields[field_name]

        expect(field).to be_present
        expect(field.instance_variable_get(:@scopes))
          .to include(:api, :read_api, :ai_features, :ai_workflows)
      end
    end
  end
end
