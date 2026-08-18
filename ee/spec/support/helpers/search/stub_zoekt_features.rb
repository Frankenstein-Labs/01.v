# frozen_string_literal: true

module Search
  module StubZoektFeatures
    # Stub Zoekt feature with `feature_name: true/false`
    #
    # @param [Hash] all_features where key is feature name and value is boolean whether available or not.
    #
    # Examples
    # - `stub_zoekt_features(traversal_id_search: false)` ... Disable `traversal_id_search`
    # - `stub_zoekt_features(traversal_id_search: true)` ... Enable `traversal_id_search`
    def stub_zoekt_features(all_features)
      all_features.each do |feature_name, value|
        raise ArgumentError, 'value must be boolean' unless value.in? [true, false]

        # Use any_args to accommodate different argument patterns across features
        # (e.g., traversal_id_search passes additional args, repo_filter_search passes just the name)
        allow(::Search::Zoekt).to receive(:feature_available?).with(feature_name, any_args).and_return(value)
      end
    end
  end
end
