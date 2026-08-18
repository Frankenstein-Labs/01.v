<script>
import { GlCollapsibleListbox, GlTruncate, GlIcon, GlButton, GlAlert } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';
import { getNewStatusOptionsFromTheSameState, getDefaultStatusMapping } from '../utils';

const FALLBACK_ICON_NAME = 'status-waiting';

export default {
  name: 'StatusMapping',
  components: {
    GlCollapsibleListbox,
    GlTruncate,
    GlIcon,
    GlButton,
    GlAlert,
  },
  props: {
    currentLifecycle: {
      type: Object,
      required: true,
    },
    selectedLifecycle: {
      type: Object,
      required: true,
    },
    stepError: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['error-dismissed', 'initialise-mapping', 'mapping-updated'],
  data() {
    return {
      statusMappings: getDefaultStatusMapping(
        this.currentLifecycle.statuses,
        this.selectedLifecycle.statuses,
      ),
      searchTerm: '',
    };
  },
  computed: {
    newLifecycleStatuses() {
      return this.selectedLifecycle?.statuses || [];
    },
    // config map
    statusConfigs() {
      const configs = {};
      this.currentLifecycle.statuses?.forEach((status) => {
        const selectedStatus = this.getNewSelectedStatus({ currentStatus: status });
        const eligibleItems = this.getEligibleItemsForCurrentStatus({ currentStatus: status });

        configs[status.id] = {
          toggleText: this.getNewSelectedStatusName({ currentStatus: status }),
          selectedStatusId: selectedStatus.id,
          eligibleItems,
          iconName: selectedStatus.iconName,
        };
      });
      return configs;
    },
  },
  mounted() {
    this.$emit('initialise-mapping', this.statusMappings);
  },
  methods: {
    getColorValue(color) {
      return { color: getAdaptiveStatusColor(color) };
    },
    getNewSelectedStatusName({ currentStatus }) {
      const { newStatusId } = this.statusMappings.find(
        (mapping) => mapping.oldStatusId === currentStatus.id,
      );
      const newStatus = this.newLifecycleStatuses.find((status) => status.id === newStatusId);
      return newStatus?.name || '';
    },
    getNewSelectedStatus({ currentStatus }) {
      const { newStatusId } = this.statusMappings.find(
        (mapping) => mapping.oldStatusId === currentStatus.id,
      );
      const newStatus = this.newLifecycleStatuses.find((status) => status.id === newStatusId);
      return newStatus || {};
    },
    getItemsForCurrentStatus({ currentStatus }) {
      const availableStatuses =
        getNewStatusOptionsFromTheSameState(currentStatus, this.newLifecycleStatuses) || [];

      if (this.searchTerm.trim()) {
        return fuzzaldrinPlus.filter(availableStatuses, this.searchTerm.trim(), {
          key: 'name',
        });
      }

      return availableStatuses;
    },
    getEligibleItemsForCurrentStatus({ currentStatus }) {
      return this.getItemsForCurrentStatus({ currentStatus }).map(
        ({ name, id, color, iconName }) => ({
          text: name,
          value: id,
          color,
          iconName,
        }),
      );
    },
    changeSelectedStatus(currentStatusId, newStatusId) {
      const updatedMappings = this.statusMappings.map((item) =>
        item.oldStatusId === currentStatusId ? { ...item, newStatusId } : item,
      );

      this.statusMappings = [...updatedMappings];

      this.$emit('mapping-updated', this.statusMappings);
    },
    getToggleTextForStatus(status) {
      return this.statusConfigs[status.id]?.toggleText || '';
    },
    getSelectedStatusIdForStatus(status) {
      return this.statusConfigs[status.id]?.selectedStatusId;
    },
    getSelectedStatusIcon(status) {
      return this.statusConfigs[status.id]?.iconName || FALLBACK_ICON_NAME;
    },
    getEligibleItemsForStatus(status) {
      return this.statusConfigs[status.id]?.eligibleItems || [];
    },
    clearSearchTerm(index) {
      this.searchTerm = '';
      const listBox = this.$refs[`listbox-${index}`];
      if (listBox && listBox[0]) {
        listBox[0]?.$refs?.searchBox?.clearInput();
      }
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-4 gl-text-subtle">
      {{
        __(
          'Select a status to use for each current status. Items using these statuses will automatically be updated to the new status.',
        )
      }}
    </div>

    <gl-alert v-if="stepError" class="gl-my-3" variant="danger" @dismiss="$emit('error-dismissed')">
      {{ stepError }}
    </gl-alert>

    <div class="gl-max-w-88">
      <!-- Table Container -->

      <div class="gl-grid gl-grid-cols-2">
        <div
          data-testid="current-status-mapping-header"
          class="gl-py-3 gl-font-bold gl-text-default"
        >
          {{ s__('WorkItem|Current status') }}
        </div>
        <div
          data-testid="new-status-mapping-header"
          class="gl-px-4 gl-py-3 gl-font-bold gl-text-default"
        >
          {{ s__('WorkItem|New status') }}
        </div>
      </div>

      <!-- Table Body -->
      <div class="gl-divide-y gl-divide-gray-200">
        <!-- Dynamic Rows -->
        <div
          v-for="(status, index) in currentLifecycle.statuses"
          :key="status.id"
          class="status-row gl-grid gl-grid-cols-2"
        >
          <!-- Current Status Column -->
          <div
            data-testid="current-status"
            class="gl-border-b gl-inline-flex gl-max-w-full gl-items-center gl-py-1 gl-pl-2 gl-pr-2-5 gl-leading-normal gl-text-strong"
          >
            <gl-icon
              class="gl-mr-3 gl-shrink-0"
              :size="12"
              :name="status.iconName"
              :style="getColorValue(status.color)"
            />
            <div class="gl-overflow-hidden">
              <gl-truncate :text="status.name" />
            </div>
          </div>

          <!-- New Status Column -->
          <div class="gl-border-b gl-px-4 gl-py-3">
            <gl-collapsible-listbox
              :ref="`listbox-${index}`"
              block
              searchable
              is-check-centered
              :toggle-text="getToggleTextForStatus(status)"
              :selected="getSelectedStatusIdForStatus(status)"
              :items="getEligibleItemsForStatus(status)"
              :header-text="s__('WorkItem|Select new status')"
              @select="changeSelectedStatus(status.id, $event)"
              @search="searchTerm = $event"
              @hidden="clearSearchTerm(index)"
            >
              <template #toggle>
                <gl-button
                  class="gl-w-full"
                  button-text-classes="gl-w-full gl-flex gl-justify-between"
                >
                  <div>
                    <gl-icon
                      class="gl-shrink-0"
                      :size="12"
                      :name="getSelectedStatusIcon(status)"
                      :style="getColorValue(getNewSelectedStatus({ currentStatus: status }).color)"
                    />
                    <gl-truncate :text="getToggleTextForStatus(status)" />
                  </div>

                  <gl-icon name="chevron-down" :size="16" variant="current" />
                </gl-button>
              </template>
              <template #list-item="{ item }">
                <gl-icon
                  :name="item.iconName"
                  :size="12"
                  class="gl-mr-2"
                  :style="getColorValue(item.color)"
                />
                {{ item.text }}
              </template>
            </gl-collapsible-listbox>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
