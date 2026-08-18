<script>
import {
  GlButton,
  GlCollapsibleListbox,
  GlEmptyState,
  GlIcon,
  GlKeysetPagination,
  GlLoadingIcon,
  GlModal,
  GlSprintf,
  GlTableLite,
  GlTooltipDirective,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, sprintf, n__, __ } from '~/locale';
import getDuoAvailabilityNamespacesQuery from '../graphql/queries/get_duo_availability_namespaces.query.graphql';
import duoSetNamespaceAvailabilityMutation from '../graphql/mutations/duo_set_namespace_availability.mutation.graphql';
import duoClearNamespaceAvailabilityMutation from '../graphql/mutations/duo_clear_namespace_availability.mutation.graphql';
import { AVAILABILITY_OPTIONS_ENUMS } from '../constants';

const PAGE_SIZE = 20;
const AFFECTED_DESCENDANTS_PREVIEW = 10;

const AVAILABILITY_ORDER = [
  AVAILABILITY_OPTIONS_ENUMS.ALWAYS_ON,
  AVAILABILITY_OPTIONS_ENUMS.DEFAULT_ON,
  AVAILABILITY_OPTIONS_ENUMS.DEFAULT_OFF,
  AVAILABILITY_OPTIONS_ENUMS.NEVER_ON,
];

const AVAILABILITY_META = {
  [AVAILABILITY_OPTIONS_ENUMS.ALWAYS_ON]: {
    labelKey: 'alwaysOnLabel',
    icon: 'lock',
    statusWordKey: 'lockingStatusWord',
    statusMessageKey: 'alwaysOnStatusMessage',
    lockedStatusMessageKey: 'alwaysOnLockedStatusMessage',
    locks: true,
  },
  [AVAILABILITY_OPTIONS_ENUMS.DEFAULT_ON]: {
    labelKey: 'defaultOnLabel',
    icon: 'group',
    statusWordKey: 'cascadingStatusWord',
    statusMessageKey: 'defaultOnStatusMessage',
    locks: false,
  },
  [AVAILABILITY_OPTIONS_ENUMS.DEFAULT_OFF]: {
    labelKey: 'defaultOffLabel',
    icon: 'group',
    statusWordKey: 'cascadingStatusWord',
    statusMessageKey: 'defaultOffStatusMessage',
    locks: false,
  },
  [AVAILABILITY_OPTIONS_ENUMS.NEVER_ON]: {
    labelKey: 'neverOnLabel',
    icon: 'lock',
    statusWordKey: 'lockingStatusWord',
    statusMessageKey: 'neverOnStatusMessage',
    lockedStatusMessageKey: 'neverOnLockedStatusMessage',
    locks: true,
  },
};

export default {
  name: 'DuoAvailabilityNamespacesTable',
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlEmptyState,
    GlIcon,
    GlLoadingIcon,
    GlKeysetPagination,
    GlModal,
    GlSprintf,
    GlTableLite,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    filter: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    enabled: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      groups: [],
      pageInfo: null,
      cursor: { first: PAGE_SIZE },
      isLoading: false,
      // Per-group in-flight mutation state. Shape per id:
      //   { mutating: boolean, pendingValue: string|null }
      // `pendingValue` is non-null when a set mutation is in flight (used to
      // decide which spinner to show); it's null for a clear mutation.
      mutationState: {},
      // Populated when a set mutation returns affectedAdminLockedDescendants.
      // Contains the target row, chosen availability, and the affected list so
      // the cascade-confirm modal can render the preview.
      pendingCascade: null,
      // Populated when the user clicks the row's Reset button. Drives the
      // reset-confirm modal.
      pendingReset: null,
    };
  },
  computed: {
    showEmptyState() {
      return !this.isLoading && this.groups.length === 0;
    },
    availabilityListboxItems() {
      return AVAILABILITY_ORDER.map((value) => ({
        value,
        text: this.$options.i18n[AVAILABILITY_META[value].labelKey],
      }));
    },
    tableFields() {
      return [
        {
          key: 'group',
          label: this.$options.i18n.columnGroup,
          thClass: 'gl-w-1/3',
        },
        {
          key: 'availability',
          label: this.$options.i18n.columnAvailability,
          thClass: 'gl-w-1/6',
        },
        {
          key: 'status',
          label: this.$options.i18n.columnStatus,
        },
        {
          key: 'actions',
          label: this.$options.i18n.columnActions,
          // GlTableLite ignores thAlignRight, so the header alignment is set directly.
          thClass: 'gl-w-20 gl-text-right',
          tdClass: 'gl-text-right',
        },
      ];
    },
    showPagination() {
      return Boolean(this.pageInfo && (this.pageInfo.hasNextPage || this.pageInfo.hasPreviousPage));
    },
    resetModalTitle() {
      if (!this.pendingReset) return '';
      return sprintf(this.$options.i18n.resetModalTitle, {
        groupName: this.pendingReset.group.name,
      });
    },
    cascadeModalTitle() {
      if (!this.pendingCascade) return '';
      const count = this.pendingCascade.affected.length;
      return sprintf(this.$options.i18n.cascadeModalTitle, {
        groupName: this.pendingCascade.group.name,
        value: this.availabilityLabel(this.pendingCascade.availability),
        count,
        lockNoun: n__('lock', 'locks', count),
      });
    },
    cascadePreviewDescendants() {
      if (!this.pendingCascade) return [];
      return this.pendingCascade.affected.slice(0, AFFECTED_DESCENDANTS_PREVIEW);
    },
    cascadeExtraCount() {
      if (!this.pendingCascade) return 0;
      return Math.max(0, this.pendingCascade.affected.length - AFFECTED_DESCENDANTS_PREVIEW);
    },
  },
  watch: {
    filter: {
      handler() {
        this.cursor = { first: PAGE_SIZE };
      },
      deep: true,
    },
  },
  apollo: {
    groups: {
      query: getDuoAvailabilityNamespacesQuery,
      fetchPolicy: 'network-only',
      variables() {
        return {
          includeDescendants: true,
          ...this.filter,
          ...this.cursor,
        };
      },
      skip() {
        return !this.enabled;
      },
      update(data) {
        const connection = data?.adminDuoAvailabilityNamespaces;
        this.pageInfo = connection?.pageInfo || null;
        return connection?.nodes || [];
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.loadGroupsError,
          error,
          captureError: true,
        });
      },
      watchLoading(isLoading) {
        this.isLoading = isLoading;
      },
    },
  },
  methods: {
    availabilityLabel(value) {
      return this.$options.i18n[AVAILABILITY_META[value]?.labelKey];
    },
    availabilityToggleAriaLabel(group) {
      return sprintf(s__('AiPowered|GitLab Duo availability for %{groupName}'), {
        groupName: group.name,
      });
    },
    availabilityToggleText(group) {
      return this.$options.i18n[AVAILABILITY_META[group.duoAvailability]?.labelKey] || '';
    },
    isAdminLocked(group) {
      return Boolean(group.adminLocked);
    },
    isLockedByAncestor(group) {
      return Boolean(group.lockedByAncestor);
    },
    isLocked(group) {
      return this.isLockedByAncestor(group) || this.isAdminLocked(group);
    },
    isOverride(group) {
      return group.duoAvailability !== group.inheritedValue;
    },
    isRowMutating(group) {
      return Boolean(this.mutationState[group.id]?.mutating);
    },
    pendingValueFor(group) {
      return this.mutationState[group.id]?.pendingValue ?? null;
    },
    lockedTooltipText(group) {
      if (this.isAdminLocked(group)) {
        return sprintf(
          s__("AiPowered|This group has an admin lock. Click '%{action}' to change this value."),
          { action: this.$options.i18n.resetActionLabel },
        );
      }
      return sprintf(
        s__(
          'AiPowered|Locked by %{path}. Clear the admin lock on the ancestor to modify this group.',
        ),
        {
          path: group.lockedByAncestor?.fullPath || '',
        },
      );
    },
    onAvailabilityClick(group, value) {
      if (value === group.duoAvailability) return;
      this.runSetMutation({ group, availability: value, clearDescendants: false });
    },
    onRemoveOverride(group) {
      this.pendingReset = { group };
    },
    confirmReset() {
      if (!this.pendingReset) return;
      const { group } = this.pendingReset;
      this.pendingReset = null;
      this.runClearMutation(group);
    },
    cancelReset() {
      this.pendingReset = null;
    },
    confirmCascade() {
      if (!this.pendingCascade) return;
      const { group, availability } = this.pendingCascade;
      this.pendingCascade = null;
      this.runSetMutation({ group, availability, clearDescendants: true });
    },
    cancelCascade() {
      if (this.pendingCascade) {
        this.setRowMutating(this.pendingCascade.group.id, false);
      }
      this.pendingCascade = null;
    },
    setRowMutating(groupId, mutating, pendingValue = null) {
      this.mutationState = {
        ...this.mutationState,
        [groupId]: { mutating, pendingValue },
      };
    },
    async runSetMutation({ group, availability, clearDescendants }) {
      this.setRowMutating(group.id, true, availability);
      try {
        const { data } = await this.$apollo.mutate({
          mutation: duoSetNamespaceAvailabilityMutation,
          variables: { groupId: group.id, availability, clearDescendants },
        });
        const payload = data?.adminSetDuoAvailability;

        if (payload?.conflictingAncestor) {
          createAlert({
            message: sprintf(this.$options.i18n.conflictingAncestorError, {
              path: payload.conflictingAncestor.fullPath,
            }),
          });
          return;
        }

        const affected = payload?.affectedAdminLockedDescendants?.nodes || [];
        if (affected.length && !clearDescendants) {
          this.pendingCascade = { group, availability, affected };
          return;
        }

        if (payload?.errors?.length) {
          createAlert({
            message: payload.errors.join(', '),
            captureError: true,
          });
          return;
        }

        await this.$apollo.queries.groups.refetch();
      } catch (error) {
        createAlert({
          message: this.$options.i18n.setError,
          error,
          captureError: true,
        });
      } finally {
        if (!this.pendingCascade || this.pendingCascade.group.id !== group.id) {
          this.setRowMutating(group.id, false);
        }
      }
    },
    async runClearMutation(group) {
      this.setRowMutating(group.id, true);
      try {
        const { data } = await this.$apollo.mutate({
          mutation: duoClearNamespaceAvailabilityMutation,
          variables: { groupId: group.id },
        });
        const payload = data?.adminClearDuoAvailability;

        if (payload?.errors?.length) {
          createAlert({
            message: payload.errors.join(', '),
            captureError: true,
          });
          return;
        }

        await this.$apollo.queries.groups.refetch();
      } catch (error) {
        createAlert({
          message: this.$options.i18n.clearError,
          error,
          captureError: true,
        });
      } finally {
        this.setRowMutating(group.id, false);
      }
    },
    onNextPage() {
      this.cursor = { first: PAGE_SIZE, after: this.pageInfo.endCursor };
    },
    onPrevPage() {
      this.cursor = { last: PAGE_SIZE, before: this.pageInfo.startCursor };
    },
    resetOverrideLabel(group) {
      return sprintf(this.$options.i18n.resetOverrideLabel, { groupName: group.name });
    },
    statusWord(value) {
      return this.$options.i18n[AVAILABILITY_META[value]?.statusWordKey];
    },
    statusMessage(value) {
      return this.$options.i18n[AVAILABILITY_META[value]?.statusMessageKey];
    },
    lockedStatusMessage(value) {
      return this.$options.i18n[AVAILABILITY_META[value]?.lockedStatusMessageKey];
    },
    statusIcon(value) {
      return AVAILABILITY_META[value]?.icon;
    },
  },
  i18n: {
    columnGroup: s__('AiPowered|Group'),
    columnAvailability: s__('AiPowered|Availability'),
    columnStatus: s__('AiPowered|Status'),
    columnActions: s__('AiPowered|Actions'),
    hideGroupsLabel: s__('AiPowered|Hide groups'),
    showGroupsLabel: s__('AiPowered|Show groups'),
    alwaysOnLabel: s__('AiPowered|Always on'),
    defaultOnLabel: s__('AiPowered|Default on'),
    defaultOffLabel: s__('AiPowered|Default off'),
    neverOnLabel: s__('AiPowered|Always off'),
    alwaysOnStatusMessage: s__('AiPowered|%{word} — subgroups cannot opt out.'),
    neverOnStatusMessage: s__('AiPowered|%{word} — subgroups cannot opt in.'),
    defaultOnStatusMessage: s__(
      'AiPowered|%{word} — subgroups default to on but can opt out individually.',
    ),
    defaultOffStatusMessage: s__(
      'AiPowered|%{word} — subgroups default to off but can opt in individually.',
    ),
    alwaysOnLockedStatusMessage: s__('AiPowered|%{word} by %{source} — subgroups cannot opt out.'),
    neverOnLockedStatusMessage: s__('AiPowered|%{word} by %{source} — subgroups cannot opt in.'),
    lockedStatusWord: s__('AiPowered|Locked'),
    lockingStatusWord: s__('AiPowered|Locking'),
    cascadingStatusWord: s__('AiPowered|Cascading'),
    inheritingStatusWord: s__('AiPowered|Inheriting'),
    resetOverrideLabel: s__('AiPowered|Reset override for %{groupName}'),
    overridesValue: s__('AiPowered|Overrides "%{value}"'),
    loadGroupsError: s__('AiPowered|An error occurred while loading the group list.'),
    setError: s__('AiPowered|An error occurred while updating the availability.'),
    clearError: s__('AiPowered|An error occurred while resetting the availability.'),
    conflictingAncestorError: s__(
      'AiPowered|Cannot update: %{path} is admin-locked. Clear the lock on the ancestor first.',
    ),
    resetModalTitle: s__('AiPowered|Reset %{groupName} to inherited value?'),
    resetModalBody: s__(
      'AiPowered|Resets the group to its inherited value — the nearest ancestor with an override, or the instance default if none exists.',
    ),
    cascadeModalTitle: s__(
      'AiPowered|Set %{groupName} to %{value} and clear %{count} admin %{lockNoun}?',
    ),
    cascadeModalBody: s__(
      'AiPowered|This will clear admin locks on the following groups. Each cleared lock is recorded in the audit log.',
    ),
    cascadeModalExtra: s__('AiPowered|…and %{count} more'),
    resetActionLabel: s__('AiPowered|Reset override'),
  },
  resetModalActionPrimary: {
    text: s__('AiPowered|Reset'),
    attributes: { variant: 'danger', category: 'primary' },
  },
  cascadeModalActionPrimary: {
    text: s__('AiPowered|Set and clear locks'),
    attributes: { variant: 'danger', category: 'primary' },
  },
  modalActionCancel: {
    text: __('Cancel'),
  },
};
</script>

<template>
  <div data-testid="duo-availability-namespaces-table">
    <gl-loading-icon
      v-if="isLoading"
      size="md"
      class="gl-my-4"
      data-testid="duo-availability-namespaces-table-loading"
    />

    <gl-empty-state
      v-else-if="showEmptyState"
      :title="s__('AiPowered|No groups found')"
      :description="s__('AiPowered|Try adjusting your filters or adding groups.')"
      data-testid="duo-availability-namespaces-table-empty"
    />

    <gl-table-lite
      v-else
      :items="groups"
      :fields="tableFields"
      stacked="md"
      data-testid="duo-availability-namespaces-table-items"
    >
      <template #cell(group)="{ item }">
        <div class="gl-flex gl-flex-col" data-testid="duo-availability-namespaces-table-row-group">
          <span class="gl-font-bold">{{ item.name }}</span>
          <span class="gl-truncate gl-text-sm gl-text-subtle">{{ item.fullPath }}</span>
        </div>
      </template>

      <template #cell(availability)="{ item }">
        <span
          v-if="isLocked(item)"
          v-gl-tooltip="lockedTooltipText(item)"
          class="gl-inline-flex gl-h-7 gl-items-center gl-text-subtle"
          data-testid="duo-availability-namespaces-table-row-locked-value"
        >
          {{ availabilityToggleText(item) }}
        </span>
        <gl-collapsible-listbox
          v-else
          :items="availabilityListboxItems"
          :selected="item.duoAvailability"
          :toggle-text="availabilityToggleText(item)"
          :loading="isRowMutating(item)"
          :toggle-aria-label="availabilityToggleAriaLabel(item)"
          :data-testid="`duo-availability-namespaces-table-row-listbox-${item.id}`"
          fluid-width
          @select="onAvailabilityClick(item, $event)"
        />
      </template>

      <template #cell(status)="{ item }">
        <span
          v-if="isLockedByAncestor(item)"
          class="gl-text-sm gl-text-subtle"
          data-testid="duo-availability-namespaces-table-row-status-locked"
        >
          <gl-icon name="lock" :size="12" class="gl-mr-2" />
          <gl-sprintf :message="lockedStatusMessage(item.duoAvailability)">
            <template #word
              ><strong>{{ $options.i18n.lockedStatusWord }}</strong></template
            >
            <template #source>{{ item.lockedByAncestor.fullPath }}</template>
          </gl-sprintf>
        </span>
        <span
          v-else-if="isOverride(item)"
          class="gl-text-sm gl-text-subtle"
          data-testid="duo-availability-namespaces-table-row-status-override"
        >
          <gl-icon :name="statusIcon(item.duoAvailability)" :size="12" class="gl-mr-2" />
          <gl-sprintf :message="statusMessage(item.duoAvailability)">
            <template #word
              ><strong>{{ statusWord(item.duoAvailability) }}</strong></template
            >
          </gl-sprintf>
          <gl-sprintf :message="$options.i18n.overridesValue">
            <template #value>{{ availabilityLabel(item.inheritedValue) }}</template>
          </gl-sprintf>
        </span>
        <span
          v-else
          class="gl-text-sm gl-text-subtle"
          data-testid="duo-availability-namespaces-table-row-status-inheriting"
        >
          <gl-icon name="group" :size="12" class="gl-mr-2" />
          <gl-sprintf :message="statusMessage(item.duoAvailability)">
            <template #word
              ><strong>{{ $options.i18n.inheritingStatusWord }}</strong></template
            >
          </gl-sprintf>
        </span>
      </template>

      <template #cell(actions)="{ item }">
        <gl-button
          v-if="isOverride(item) && !isLockedByAncestor(item)"
          v-gl-tooltip="resetOverrideLabel(item)"
          variant="danger"
          category="secondary"
          size="small"
          :aria-label="resetOverrideLabel(item)"
          :loading="isRowMutating(item) && pendingValueFor(item) === null"
          :disabled="isRowMutating(item)"
          data-testid="duo-availability-namespaces-table-row-remove-override"
          @click="onRemoveOverride(item)"
        >
          {{ $options.i18n.resetActionLabel }}
        </gl-button>
      </template>
    </gl-table-lite>

    <div v-if="showPagination" class="gl-mt-3 gl-flex gl-justify-center">
      <gl-keyset-pagination
        v-bind="pageInfo"
        data-testid="duo-availability-namespaces-table-pagination"
        @prev="onPrevPage"
        @next="onNextPage"
      />
    </div>

    <gl-modal
      modal-id="duo-availability-namespaces-reset-modal"
      :visible="Boolean(pendingReset)"
      :title="resetModalTitle"
      :action-primary="$options.resetModalActionPrimary"
      :action-cancel="$options.modalActionCancel"
      data-testid="duo-availability-namespaces-reset-modal"
      @primary="confirmReset"
      @canceled="cancelReset"
      @hidden="cancelReset"
    >
      {{ $options.i18n.resetModalBody }}
    </gl-modal>

    <gl-modal
      modal-id="duo-availability-namespaces-cascade-modal"
      :visible="Boolean(pendingCascade)"
      :title="cascadeModalTitle"
      :action-primary="$options.cascadeModalActionPrimary"
      :action-cancel="$options.modalActionCancel"
      data-testid="duo-availability-namespaces-cascade-modal"
      @primary="confirmCascade"
      @canceled="cancelCascade"
      @hidden="cancelCascade"
    >
      <p>{{ $options.i18n.cascadeModalBody }}</p>
      <ul data-testid="duo-availability-namespaces-cascade-modal-list">
        <li v-for="descendant in cascadePreviewDescendants" :key="descendant.id">
          {{ descendant.fullPath }}
        </li>
      </ul>
      <p v-if="cascadeExtraCount > 0" class="gl-text-sm gl-text-subtle">
        <gl-sprintf :message="$options.i18n.cascadeModalExtra">
          <template #count>{{ cascadeExtraCount }}</template>
        </gl-sprintf>
      </p>
    </gl-modal>
  </div>
</template>
