<script>
import {
  GlBadge,
  GlButton,
  GlIcon,
  GlLoadingIcon,
  GlModal,
  GlSprintf,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { numberToHumanSize } from '~/lib/utils/number_utils';

export default {
  name: 'UpstreamCacheEntriesTable',
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GlLoadingIcon,
    GlModal,
    GlSprintf,
    GlTable,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['i18n'],
  props: {
    cacheEntries: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['delete'],
  data() {
    return {
      cacheEntryToBeDeleted: null,
      showDeleteModal: false,
    };
  },
  computed: {
    canDelete() {
      return this.glAbilities.destroyVirtualRegistry;
    },
    fields() {
      return [
        {
          key: 'relativePath',
          label: __('Artifact'),
          thClass: 'gl-w-3/5',
        },
        {
          key: 'size',
          label: __('Size'),
          tdClass: '!gl-align-middle',
        },
        {
          key: 'downloadsCount',
          label: s__('VirtualRegistryCacheEntry|Download count'),
          tdClass: '!gl-align-middle',
        },
        {
          key: 'upstreamCheckedAt',
          label: s__('VirtualRegistryCacheEntry|Last checked'),
          tdClass: '!gl-align-middle',
        },
        {
          key: 'actions',
          label: __('Actions'),
          hide: !this.canDelete,
          thAlignRight: true,
          tdClass: '!gl-align-middle gl-text-right',
        },
      ].filter((field) => !field.hide);
    },
  },
  methods: {
    handleDelete(item) {
      this.cacheEntryToBeDeleted = item;
      this.showDeleteModal = true;
    },
    hideModal() {
      this.showDeleteModal = false;
      this.cacheEntryToBeDeleted = null;
    },
    formatSize(size) {
      return numberToHumanSize(size);
    },
  },
  modal: {
    primaryAction: {
      text: __('Delete'),
      attributes: {
        variant: 'danger',
        category: 'primary',
      },
    },
    cancelAction: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <div>
    <gl-table
      :fields="fields"
      :items="cacheEntries"
      stacked="sm"
      :tbody-tr-attr="{ 'data-testid': 'cache-entry-row' }"
      :busy="loading"
      show-empty
    >
      <template #table-busy>
        <gl-loading-icon size="lg" class="gl-mt-5" />
      </template>

      <template #empty>
        <p class="gl-mb-0 gl-text-center gl-text-subtle">
          {{ s__('VirtualRegistry|No artifacts to display.') }}
        </p>
      </template>

      <template #cell(relativePath)="{ item }">
        <div class="gl-mb-3 gl-flex gl-gap-2">
          <span>
            <gl-icon name="doc-text" />
          </span>
          <span class="gl-break-all gl-text-subtle" data-testid="relative-path">{{
            item.relativePath
          }}</span>
        </div>
        <gl-badge>{{ item.contentType }}</gl-badge>
      </template>

      <template #cell(size)="{ item }">
        <span data-testid="artifact-size">{{ formatSize(item.size) }}</span>
      </template>

      <template #cell(upstreamCheckedAt)="{ item }">
        <span class="gl-text-subtle">
          <time-ago-tooltip :time="item.upstreamCheckedAt" />
        </span>
      </template>

      <template v-if="canDelete" #cell(actions)="{ item }">
        <gl-button
          v-gl-tooltip="__('Delete')"
          :aria-label="__('Delete')"
          size="small"
          category="tertiary"
          icon="remove"
          data-testid="delete-cache-entry-btn"
          @click="handleDelete(item)"
        />
      </template>
    </gl-table>
    <gl-modal
      v-model="showDeleteModal"
      modal-id="delete-cache-entry-modal"
      size="sm"
      :action-primary="$options.modal.primaryAction"
      :action-cancel="$options.modal.cancelAction"
      :title="i18n.upstreams.deleteCacheModalTitle"
      @primary="$emit('delete', { id: cacheEntryToBeDeleted.id })"
      @canceled="hideModal"
    >
      <gl-sprintf
        v-if="cacheEntryToBeDeleted"
        :message="s__('VirtualRegistry|Are you sure you want to delete %{name}?')"
      >
        <template #name>
          <strong>{{ cacheEntryToBeDeleted.relativePath }}</strong>
        </template>
      </gl-sprintf>
    </gl-modal>
  </div>
</template>
