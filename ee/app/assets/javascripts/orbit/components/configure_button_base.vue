<script>
import { defineComponent } from 'vue';
import { GlDisclosureDropdown, GlModal, GlSearchBoxByType, GlSprintf } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { s__, sprintf } from '~/locale';

export default defineComponent({
  name: 'OrbitConfigureButtonBase',
  compatConfig: { MODE: 3 },
  components: {
    GlDisclosureDropdown,
    GlModal,
    GlSearchBoxByType,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    namespaces: {
      type: Array,
      required: false,
      default: () => [],
    },
    namespacesLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    enabling: {
      type: Boolean,
      required: false,
      default: false,
    },
    pendingGroup: {
      type: Object,
      required: false,
      default: null,
    },
    confirmModalVisible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['select', 'confirm-enable', 'modal-hidden'],
  i18n: {
    configure: s__('Orbit|Configure'),
    headerText: s__('Orbit|Configure Orbit for a group'),
    searchPlaceholder: s__('Orbit|Search groups'),
    noResultsText: s__('Orbit|No groups match your search.'),
    notEnabledText: s__('Orbit|Orbit not enabled'),
    primary: s__('Orbit|Turn on indexing'),
    cancel: s__('Orbit|Cancel'),
    accessIntro: s__(
      "Orbit|All content from this group, its subgroups, and projects will be added to Orbit. Existing access controls still apply — users who cannot access content in this group won't see it through Orbit.",
    ),
    initialScan: s__(
      'Orbit|%{boldStart}The initial scan can take some time depending on the amount of content.%{boldEnd} After that, updated content is automatically re-indexed. You can turn off Orbit at any time.',
    ),
  },
  data() {
    return {
      search: '',
    };
  },
  computed: {
    filteredNamespaces() {
      const term = this.search.trim().toLowerCase();
      if (!term) return this.namespaces;
      return this.namespaces.filter(
        (ns) =>
          ns.name.toLowerCase().includes(term) ||
          ns.fullName?.toLowerCase().includes(term) ||
          ns.fullPath.toLowerCase().includes(term),
      );
    },
    enabledNamespaces() {
      return this.filteredNamespaces
        .filter((ns) => ns.knowledgeGraphEnabled)
        .toSorted((a, b) => a.name.localeCompare(b.name));
    },
    disabledNamespaces() {
      return this.filteredNamespaces
        .filter((ns) => !ns.knowledgeGraphEnabled)
        .toSorted((a, b) => a.name.localeCompare(b.name));
    },
    disclosureItems() {
      const groups = [];
      if (this.enabledNamespaces.length) {
        groups.push({
          items: this.enabledNamespaces.map((ns) => ({
            text: ns.name,
            action: () => {
              this.trackEvent('click_orbit_configure_group');
              this.$emit('select', ns.fullPath);
            },
          })),
        });
      }
      if (this.disabledNamespaces.length) {
        groups.push({
          name: this.$options.i18n.notEnabledText,
          items: this.disabledNamespaces.map((ns) => ({
            text: ns.name,
            action: () => {
              this.trackEvent('click_orbit_configure_group');
              this.$emit('select', ns.fullPath);
            },
          })),
        });
      }
      return groups;
    },
    modalTitle() {
      if (!this.pendingGroup) return '';
      return sprintf(s__('Orbit|Turn on Orbit indexing for %{groupName}'), {
        groupName: this.pendingGroup.name,
      });
    },
    primaryAction() {
      return {
        text: this.$options.i18n.primary,
        attributes: { variant: 'confirm', loading: this.enabling },
      };
    },
    cancelAction() {
      return {
        text: this.$options.i18n.cancel,
        attributes: { disabled: this.enabling },
      };
    },
  },
});
</script>

<template>
  <div>
    <gl-disclosure-dropdown
      :items="disclosureItems"
      :toggle-text="$options.i18n.configure"
      :loading="namespacesLoading"
      icon="settings"
      category="tertiary"
      size="small"
      no-caret
      data-testid="orbit-configure-groups-listbox"
    >
      <template #header>
        <div class="gl-border-b gl-border-default gl-p-3">
          <p class="gl-mb-2 gl-text-sm gl-font-bold">{{ $options.i18n.headerText }}</p>
          <gl-search-box-by-type
            v-model="search"
            :placeholder="$options.i18n.searchPlaceholder"
            :debounce="200"
          />
        </div>
      </template>
      <template v-if="!disclosureItems.length && !namespacesLoading" #footer>
        <p class="gl-px-4 gl-py-3 gl-text-sm gl-text-subtle">{{ $options.i18n.noResultsText }}</p>
      </template>
    </gl-disclosure-dropdown>
    <gl-modal
      :visible="confirmModalVisible"
      modal-id="orbit-enable-confirm-modal"
      :title="modalTitle"
      :action-primary="primaryAction"
      :action-cancel="cancelAction"
      data-testid="orbit-enable-confirm-modal"
      @primary.prevent="$emit('confirm-enable')"
      @hidden="$emit('modal-hidden')"
    >
      <p>{{ $options.i18n.accessIntro }}</p>
      <p>
        <gl-sprintf :message="$options.i18n.initialScan">
          <template #bold="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </p>
    </gl-modal>
  </div>
</template>
