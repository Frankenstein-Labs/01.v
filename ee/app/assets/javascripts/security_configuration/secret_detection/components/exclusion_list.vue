<script>
import {
  GlTable,
  GlIcon,
  GlButton,
  GlToggle,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlToastMixin,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { EXCLUSION_TYPE_MAP } from '../constants';
import updateMutation from '../graphql/project_security_exclusion_update.mutation.graphql';
import DeleteModal from './exclusion_delete_modal.vue';
import ExperimentHeader from './experiment_header.vue';

const i18nStrings = {
  status: s__('SecurityExclusions|Status'),
  type: s__('SecurityExclusions|Type'),
  value: s__('SecurityExclusions|Value'),
  enforcement: s__('SecurityExclusions|Enforcement'),
  modified: s__('SecurityExclusions|Modified'),
  headingText: s__(
    'SecurityExclusions|Specify file paths, raw values, and regex that should be excluded by secret detection in this project.',
  ),
  addExclusion: s__('SecurityExclusions|Add exclusion'),
  secretPushProtection: s__('SecurityExclusions|Secret push protection'),
  toggleLabel: s__('SecurityExclusions|Toggle exclusion'),
  exclusionStatusEnabled: s__('SecurityExclusions|Exclusion enabled successfully.'),
  exclusionStatusDisabled: s__('SecurityExclusions|Exclusion disabled successfully.'),
};

export default {
  name: 'ExclusionList',
  components: {
    GlTable,
    GlIcon,
    GlButton,
    GlToggle,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    DeleteModal,
    ExperimentHeader,
  },
  mixins: [GlToastMixin],
  props: {
    exclusions: {
      type: Array,
      required: true,
    },
  },
  emits: ['add-exclusion', 'edit-exclusion', 'view-exclusion'],
  i18n: i18nStrings,
  data() {
    return {
      fields: [
        { key: 'status', label: this.$options.i18n.status },
        { key: 'type', label: this.$options.i18n.type, sortable: true },
        { key: 'content', label: this.$options.i18n.value },
        { key: 'enforcement', label: this.$options.i18n.enforcement },
        { key: 'modified', label: this.$options.i18n.modified },
        { key: 'actions', label: '' },
      ],
      itemToBeDeleted: {},
    };
  },
  methods: {
    addExclusion() {
      this.$emit('add-exclusion');
    },
    typeLabel(type) {
      return EXCLUSION_TYPE_MAP[type]?.text || '';
    },
    modifiedTime(time) {
      return getTimeago().format(time);
    },
    prepareExclusionDeletion(item) {
      this.itemToBeDeleted = item;
      this.$refs.deleteModal.show();
    },
    prepareExclusionEdit(item) {
      this.$emit('edit-exclusion', item);
    },
    viewItem(item) {
      this.$emit('view-exclusion', item);
    },
    editItem(item) {
      return {
        text: __('Edit'),
        action: () => this.prepareExclusionEdit(item),
      };
    },
    deleteItem(item) {
      return {
        text: __('Delete'),
        action: () => this.prepareExclusionDeletion(item),
        variant: 'danger',
      };
    },
    async toggleExclusionStatus(item) {
      const { id, active } = item;
      const newStatus = !active;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateMutation,
          variables: {
            input: {
              id,
              active: newStatus,
            },
          },
        });

        const { errors } = data.projectSecurityExclusionUpdate;

        if (errors && errors.length > 0) {
          this.onError(new Error(errors.join(' ')));
          return;
        }

        this.$toast.show(
          newStatus
            ? this.$options.i18n.exclusionStatusEnabled
            : this.$options.i18n.exclusionStatusDisabled,
        );
      } catch (error) {
        this.onError(error);
      }
    },
    onError(error) {
      const { message } = error;
      const title = s__('SecurityExclusions|Failed to update the exclusion:');

      createAlert({ title, message });
      Sentry.captureException(error);
    },
  },
};
</script>

<template>
  <div>
    <experiment-header />
    <div class="gl-mb-3 gl-flex gl-items-baseline gl-justify-between">
      <p>
        {{ $options.i18n.headingText }}
      </p>
      <gl-button variant="confirm" @click="addExclusion">{{
        $options.i18n.addExclusion
      }}</gl-button>
    </div>

    <gl-table
      :items="exclusions"
      :fields="fields"
      stacked="md"
      hover
      selectable
      select-mode="single"
      selected-variant="primary"
      @row-clicked="viewItem"
    >
      <template #cell(status)="{ item }">
        <gl-toggle
          :value="item.active"
          :label="$options.i18n.toggleLabel"
          label-position="hidden"
          @change="toggleExclusionStatus(item)"
        />
      </template>
      <template #cell(type)="{ item }">
        {{ typeLabel(item.type) }}
      </template>
      <template #cell(content)="{ item }">
        {{ item.value }}
      </template>
      <template #cell(enforcement)>
        <gl-icon name="check" variant="success" />
        {{ $options.i18n.secretPushProtection }}
      </template>
      <template #cell(modified)="{ item }"> {{ modifiedTime(item.updatedAt) }} </template>
      <template #cell(actions)="{ item }">
        <gl-disclosure-dropdown
          category="tertiary"
          variant="default"
          size="small"
          icon="ellipsis_v"
          no-caret
        >
          <gl-disclosure-dropdown-item :item="editItem(item)" />
          <gl-disclosure-dropdown-item :item="deleteItem(item)" />
        </gl-disclosure-dropdown>
      </template>
    </gl-table>
    <delete-modal ref="deleteModal" :exclusion="itemToBeDeleted" />
  </div>
</template>
