<script>
import { GlIcon, GlButton, GlCollapsibleListbox, GlToastMixin } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import RemoveLifecycleConfirmationModal from './remove_lifecycle_confirmation_modal.vue';
import LifecycleNameForm from './lifecycle_name_form.vue';
import removeLifecycleMutation from './graphql/remove_lifecycle.mutation.graphql';

export default {
  name: 'LifecycleDetail',
  components: {
    GlIcon,
    WorkItemStatusBadge,
    LifecycleNameForm,
    GlButton,
    GlCollapsibleListbox,
    RemoveLifecycleConfirmationModal,
  },
  mixins: [GlToastMixin],
  props: {
    lifecycle: {
      type: Object,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    isLifecycleTemplate: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRadioSelection: {
      type: Boolean,
      required: false,
      default: false,
    },
    showUsageSection: {
      type: Boolean,
      required: false,
      default: false,
    },
    showNotInUseSection: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRemoveLifecycleButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showChangeLifecycleButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showRenameButton: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['deleted'],
  data() {
    return {
      cardHover: false,
      showConfirmationModal: false,
    };
  },
  computed: {
    lifecycleId() {
      return getIdFromGraphQLId(this.lifecycle?.id);
    },
    items() {
      return (this.lifecycle.workItemTypes || []).map(({ name }) => ({ text: name, value: name }));
    },
    isLifecycleAssociatedWithWorkItemTypes() {
      return this.lifecycle?.workItemTypes?.length > 0;
    },
    isUsageSectionVisible() {
      return this.isLifecycleAssociatedWithWorkItemTypes && this.showUsageSection;
    },
  },
  methods: {
    linkToItemType(workItemType) {
      this.$router.push({
        name: 'changeLifecycle',
        params: {
          workItemType,
        },
      });
    },
    confirmRemoval() {
      this.showConfirmationModal = true;
    },
    discardRemoval() {
      this.showConfirmationModal = false;
    },
    async removeLifecycle() {
      this.showConfirmationModal = false;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: removeLifecycleMutation,
          variables: {
            input: {
              namespacePath: this.fullPath,
              id: this.lifecycle.id,
            },
          },
        });

        const {
          lifecycleDelete: { errors },
        } = data;

        if (errors.length) {
          const message = sprintf(s__('WorkItem|Failed to delete lifecycle. %{error}'), {
            error: data.lifecycleDelete.errors.join(', '),
          });
          throw new Error(message);
        }

        this.$emit('deleted');
        this.$toast.show(s__('WorkItem|Lifecycle deleted.'));
      } catch (error) {
        Sentry.captureException(error);
      }
    },
  },
};
</script>
<template>
  <div
    :key="lifecycle.id"
    class="gl-border gl-rounded-lg gl-bg-white gl-px-4 gl-pt-4"
    data-testid="lifecycle-detail"
  >
    <div class="gl-mb-3" @mouseenter="cardHover = true" @mouseleave="cardHover = false">
      <span v-if="showRadioSelection" :data-testid="`lifecycle-${lifecycleId}-select`">
        <slot name="radio-selection"></slot>
      </span>

      <lifecycle-name-form
        v-else-if="showRenameButton"
        :lifecycle="lifecycle"
        :is-lifecycle-template="isLifecycleTemplate"
        :full-path="fullPath"
        :card-hover="cardHover"
      />

      <span v-else class="gl-font-bold gl-text-strong">{{ lifecycle.name }} </span>

      <div class="gl-mx-auto gl-my-3 gl-flex gl-flex-wrap gl-gap-3">
        <div v-for="status in lifecycle.statuses" :key="status.id" class="gl-max-w-20">
          <work-item-status-badge :key="status.id" :item="status" />
        </div>
      </div>

      <slot name="detail-footer"></slot>
    </div>

    <div
      v-if="isUsageSectionVisible"
      :data-testid="`lifecycle-${lifecycleId}-usage`"
      class="-gl-mx-4 gl-flex gl-flex-wrap gl-items-center gl-gap-3 gl-rounded-bl-lg gl-rounded-br-lg gl-border-t-1 gl-border-gray-400 gl-bg-strong gl-px-4 gl-py-2"
    >
      <span class="gl-text-sm gl-text-subtle">{{ s__('WorkItem|Usage:') }}</span>
      <span
        v-for="workItemType in lifecycle.workItemTypes"
        :key="workItemType.id"
        class="gl-flex gl-items-center gl-gap-1 gl-text-sm"
        data-testid="work-item-type-name"
      >
        <gl-icon :name="workItemType.iconName" :size="14" />
        <span>{{ workItemType.name }}</span>
      </span>

      <template v-if="showChangeLifecycleButton">
        <gl-button
          v-if="lifecycle.workItemTypes.length === 1"
          size="small"
          @click="linkToItemType(lifecycle.workItemTypes[0].name)"
          >{{ s__('WorkItem|Change lifecycle') }}</gl-button
        >

        <gl-collapsible-listbox
          v-else
          :items="items"
          :header-text="s__('WorkItem|Select type to change')"
          :toggle-text="s__('WorkItem|Change lifecycle')"
          category="secondary"
          size="small"
          @select="linkToItemType"
        />
      </template>
    </div>

    <div
      v-else-if="showNotInUseSection && !isLifecycleAssociatedWithWorkItemTypes"
      :data-testid="`lifecycle-${lifecycleId}-no-usage`"
      class="gl-border-warning-400 -gl-mx-4 gl-flex gl-items-center gl-gap-3 gl-rounded-bl-lg gl-rounded-br-lg gl-border-t-1 gl-bg-feedback-warning gl-px-4 gl-py-2"
      :class="{
        'gl-py-3': !showRemoveLifecycleButton,
      }"
    >
      <gl-icon name="warning" :size="14" class="gl-text-orange-700" />
      <span class="gl-text-sm gl-text-orange-700">
        {{ s__('WorkItem|Not in use') }}
      </span>

      <gl-button
        v-if="showRemoveLifecycleButton"
        :data-testid="`remove-lifecycle-${lifecycleId}`"
        size="small"
        @click="confirmRemoval"
        >{{ s__('WorkItem|Remove lifecycle') }}</gl-button
      >
    </div>
    <remove-lifecycle-confirmation-modal
      v-if="lifecycle.name"
      :is-visible="showConfirmationModal"
      :lifecycle-name="lifecycle.name"
      @continue="removeLifecycle"
      @cancel="discardRemoval"
    />
  </div>
</template>
