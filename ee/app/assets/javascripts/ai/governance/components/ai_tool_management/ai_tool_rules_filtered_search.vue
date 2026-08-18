<script>
import { GlFilteredSearch, GlFilteredSearchToken } from '@gitlab/ui';
import { s__ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { TOKEN_TYPE_ACTION, ACTION_TOKEN_OPTIONS } from '../../constants';

export default {
  name: 'AiToolRulesFilteredSearch',
  components: {
    GlFilteredSearch,
  },
  emits: ['filter'],
  data() {
    return {
      // Bound value array drives chip rendering and `unique` single-token behaviour.
      filterValue: [],
    };
  },
  methods: {
    onInput(value) {
      this.filterValue = value;
    },
    onSubmit(terms) {
      const searchTerms = [];
      let actionType = null;

      // GlFilteredSearch's `submit` payload represents free text as plain
      // strings and only wraps actual filter tokens (e.g. the action token)
      // as `{ type, value: { data } }` objects. `terms-as-tokens` only affects
      // chip rendering, not this event's shape.
      terms.forEach((term) => {
        if (typeof term === 'string') {
          const trimmed = term.trim();
          if (trimmed) {
            searchTerms.push(trimmed);
          }
        } else if (term?.type === TOKEN_TYPE_ACTION) {
          actionType = term.value?.data ?? null;
        }
      });

      const search = searchTerms.join(' ').trim();

      this.$emit('filter', { search: search || null, actionType });
    },
    onClear() {
      // The clear button emits `clear` (not `submit`), so reset the filter here
      // or the table keeps showing results after the bar is emptied.
      this.filterValue = [];
      this.$emit('filter', { search: null, actionType: null });
    },
  },
  availableTokens: [
    {
      type: TOKEN_TYPE_ACTION,
      title: s__('AiGovernance|Action'),
      icon: 'comparison',
      token: GlFilteredSearchToken,
      operators: OPERATORS_IS,
      unique: true,
      options: ACTION_TOKEN_OPTIONS,
    },
  ],
  i18n: {
    placeholder: s__('AiGovernance|Search or filter tool rules...'),
  },
};
</script>

<template>
  <div data-testid="ai-tool-rules-filtered-search">
    <gl-filtered-search
      :value="filterValue"
      :placeholder="$options.i18n.placeholder"
      :available-tokens="$options.availableTokens"
      :clear-button-title="__('Clear')"
      :close-button-title="__('Close')"
      terms-as-tokens
      @input="onInput"
      @submit="onSubmit"
      @clear="onClear"
    />
  </div>
</template>
