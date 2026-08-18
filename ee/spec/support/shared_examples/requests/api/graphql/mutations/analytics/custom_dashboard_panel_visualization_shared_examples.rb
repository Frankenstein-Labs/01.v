# frozen_string_literal: true

# Shared validation coverage for custom dashboard mutations that accept panel
# visualizations. A panel supplies its visualization either as a string
# reference (`visualization`) or an inline config object (`visualizationConfig`),
# and exactly one of the two must be present.
#
# The including context must:
#   - define `mutation` and `mutation_response`
#   - define `user`
#   - build the mutation `variables` so the dashboard config's panels come from
#     the `panels` let defined here
RSpec.shared_examples 'a custom dashboard mutation validating panel visualizations' do
  let(:argument_error_message) do
    'One and only one of [visualization, visualizationConfig] arguments is required.'
  end

  context 'when a panel visualization is an invalid config object' do
    let(:panels) do
      [
        {
          title: 'Broken Panel',
          visualizationConfig: { type: 'NotAChartType' },
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    end

    it 'returns a validation error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(mutation_response['dashboard']).to be_nil
      expect(mutation_response['errors'].join).to match(/must be a valid json schema/)
    end
  end

  context 'when a panel supplies neither visualization nor visualizationConfig' do
    let(:panels) do
      [
        {
          title: 'Empty Panel',
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    end

    it 'returns an argument error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(graphql_errors).to include(a_hash_including('message' => argument_error_message))
    end
  end

  context 'when a panel supplies both visualization and visualizationConfig' do
    let(:panels) do
      [
        {
          title: 'Ambiguous Panel',
          visualization: 'number',
          visualizationConfig: {
            version: 1, type: 'SingleStat', options: {}, data: { type: 'cube_analytics', query: {} }
          },
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    end

    it 'returns an argument error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(graphql_errors).to include(a_hash_including('message' => argument_error_message))
    end
  end
end
