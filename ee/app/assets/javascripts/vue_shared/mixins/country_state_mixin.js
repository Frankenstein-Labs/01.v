import { COUNTRIES_WITH_STATES_ALLOWED } from 'ee/vue_shared/leads/constants';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';

/**
 * Mixin for components that uses gl-form-fields that need country and state selection functionality.
 * Provides common data, computed properties, Apollo queries, and methods
 * for handling country/state selection with proper state management.
 *
 * ## Performance Considerations
 *
 * By default, this mixin skips GraphQL queries to prevent unnecessary network requests
 * on components that may not immediately need country/state data (like modals).
 *
 * ### Enabling Query Execution
 *
 * To enable queries when you need the data, set `skipCountryStateQueries` to `false`:
 *
 * ```javascript
 * export default {
 *   mixins: [countryStateMixin],
 *   data() {
 *     return {
 *       skipCountryStateQueries: false, // Enable queries immediately
 *       // ... other data
 *     };
 *   },
 *   // OR enable them dynamically:
 *   methods: {
 *     showCountryFields() {
 *       this.skipCountryStateQueries = false; // Enable queries when needed
 *     }
 *   }
 * }
 * ```
 *
 * This approach ensures optimal performance by default and requires explicit opt-in
 * for components that need immediate country/state data loading.
 */
export default {
  data() {
    return {
      countries: [],
      states: [],
      skipCountryStateQueries: true,
    };
  },
  computed: {
    /**
     * Whether to show the country field (when countries are loaded)
     */
    showCountry() {
      return !this.$apollo.queries.countries.loading;
    },
    /**
     * Whether the selected country requires a state selection
     */
    stateRequired() {
      return COUNTRIES_WITH_STATES_ALLOWED.includes(this.formValues.country);
    },
    /**
     * Whether to show the state field
     * Requires: country selected, states loaded, and country requires states
     */
    showState() {
      return !this.$apollo.queries.states.loading && this.formValues.country && this.stateRequired;
    },
    isLoadingCountryOrState() {
      return this.$apollo.queries.countries.loading || this.$apollo.queries.states.loading;
    },
  },
  apollo: {
    countries: {
      query: countriesQuery,
      skip() {
        return this.skipCountryStateQueries;
      },
      update(data) {
        return data.countries.map((country) => ({
          value: country.id,
          text: country.name,
        }));
      },
    },
    states: {
      query: statesQuery,
      update(data) {
        return data.states.map((state) => ({
          value: state.id,
          text: state.name,
        }));
      },
      skip() {
        return !this.formValues.country || this.skipCountryStateQueries;
      },
      variables() {
        return {
          countryId: this.formValues.country,
        };
      },
    },
  },
  methods: {
    /**
     * Handle country selection
     * Clears state value if the new country doesn't require states
     * @param {string} value - Selected country ID
     * @param {Function} formFieldsInput - GlFormFields input callback
     */
    onCountrySelect(value, formFieldsInput) {
      if (!this.showState) {
        this.formValues.state = '';
      }

      // On initialization this can be undefined
      formFieldsInput?.(value);
    },
  },
};
