<script>
import { GlFilteredSearch, GlFilteredSearchToken } from '@gitlab/ui';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { s__ } from '~/locale';
import { AVAILABILITY_OPTIONS_ENUMS } from '../constants';

const TOKEN_TYPE_ADMIN_LOCKED = 'adminLocked';
const TOKEN_TYPE_DUO_AVAILABILITY = 'duoAvailability';

const ADMIN_LOCKED_OPTIONS = [
  { value: 'true', title: s__('AiPowered|Yes') },
  { value: 'false', title: s__('AiPowered|No') },
];

const DUO_AVAILABILITY_OPTIONS = [
  { value: AVAILABILITY_OPTIONS_ENUMS.ALWAYS_ON, title: s__('AiPowered|Always on') },
  { value: AVAILABILITY_OPTIONS_ENUMS.DEFAULT_ON, title: s__('AiPowered|Default on') },
  { value: AVAILABILITY_OPTIONS_ENUMS.DEFAULT_OFF, title: s__('AiPowered|Default off') },
  { value: AVAILABILITY_OPTIONS_ENUMS.NEVER_ON, title: s__('AiPowered|Always off') },
];

const DEFAULT_FILTER_VALUE = [
  {
    type: TOKEN_TYPE_ADMIN_LOCKED,
    value: { data: 'true', operator: '=' },
  },
];

export default {
  name: 'DuoAvailabilityNamespacesFilter',
  components: {
    GlFilteredSearch,
  },
  emits: ['filter'],
  data() {
    return {
      filterValue: [...DEFAULT_FILTER_VALUE],
    };
  },
  methods: {
    onInput(value) {
      this.filterValue = value;
    },
    handleSubmit(terms) {
      const searchTerms = [];
      const duoAvailability = [];
      let adminLocked = null;

      terms.forEach((term) => {
        if (typeof term === 'string') {
          const trimmed = term.trim();
          if (trimmed) searchTerms.push(trimmed);
          return;
        }
        const data = term.value?.data;
        if (term.type === TOKEN_TYPE_ADMIN_LOCKED) {
          adminLocked = data === 'true';
        } else if (term.type === TOKEN_TYPE_DUO_AVAILABILITY) {
          if (data) duoAvailability.push(data);
        }
      });

      const search = searchTerms.join(' ').trim();

      const variables = {};
      if (search) variables.search = search;
      if (adminLocked !== null) variables.adminLocked = adminLocked;
      if (duoAvailability.length) variables.duoAvailability = duoAvailability;

      this.$emit('filter', variables);
    },
    onClear() {
      this.filterValue = [];
      this.$emit('filter', {});
    },
  },
  availableTokens: [
    {
      type: TOKEN_TYPE_ADMIN_LOCKED,
      title: s__('AiPowered|Admin locked'),
      icon: 'lock',
      token: GlFilteredSearchToken,
      operators: OPERATORS_IS,
      unique: true,
      options: ADMIN_LOCKED_OPTIONS,
    },
    {
      type: TOKEN_TYPE_DUO_AVAILABILITY,
      title: s__('AiPowered|Availability'),
      icon: 'tanuki-ai',
      token: GlFilteredSearchToken,
      operators: OPERATORS_IS,
      unique: false,
      options: DUO_AVAILABILITY_OPTIONS,
    },
  ],
  i18n: {
    placeholder: s__('AiPowered|Search or filter groups'),
  },
};
</script>

<template>
  <gl-filtered-search
    :value="filterValue"
    :placeholder="$options.i18n.placeholder"
    :available-tokens="$options.availableTokens"
    :clear-button-title="__('Clear')"
    :close-button-title="__('Close')"
    terms-as-tokens
    data-testid="duo-availability-namespaces-filter"
    @input="onInput"
    @submit="handleSubmit"
    @clear="onClear"
  />
</template>
