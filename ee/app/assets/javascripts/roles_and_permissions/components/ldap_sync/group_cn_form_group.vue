<script>
import { debounce } from 'lodash-es';
import { GlFormGroup, GlCollapsibleListbox, GlTooltipDirective } from '@gitlab/ui';
import Api from 'ee/api';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';

export default {
  name: 'GroupCnFormGroup',
  components: { GlFormGroup, GlCollapsibleListbox },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    value: {
      type: String,
      required: false,
      default: null,
    },
    state: {
      type: Boolean,
      required: true,
    },
    server: {
      type: String,
      required: false,
      default: null,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['input'],
  data() {
    return {
      groups: [],
      searchTerm: '',
      isLoading: false,
    };
  },
  watch: {
    server: {
      immediate: true,
      handler() {
        // When the server is changed, fetch the groups for that server.
        if (this.server) {
          this.fetchGroups();
        }
      },
    },
    searchTerm() {
      this.debouncedFetchGroups();
    },
  },
  created() {
    this.debouncedFetchGroups = debounce(this.fetchGroups, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    async fetchGroups() {
      try {
        this.isLoading = true;
        const { data } = await Api.ldapGroups(this.searchTerm, this.server);
        this.groups = data.map(({ cn }) => ({ text: cn, value: cn }));
      } catch {
        createAlert({ message: s__('LDAP|Could not fetch LDAP groups. Please try again.') });
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <gl-form-group
    :label="s__('LDAP|Group cn')"
    :state="state"
    :invalid-feedback="__('This field is required')"
  >
    <gl-collapsible-listbox
      v-gl-tooltip.d0="server ? '' : s__('LDAP|Select a server to fetch groups.')"
      :selected="value"
      :items="groups"
      :searching="isLoading"
      :disabled="!server || disabled"
      category="secondary"
      :variant="state ? 'default' : 'danger'"
      :toggle-text="value || s__('LDAP|Select LDAP group')"
      class="gl-max-w-30"
      searchable
      block
      @search="searchTerm = $event"
      @select="$emit('input', $event)"
    />
  </gl-form-group>
</template>
