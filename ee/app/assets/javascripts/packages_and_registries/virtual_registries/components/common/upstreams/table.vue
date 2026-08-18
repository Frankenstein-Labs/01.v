<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLink,
  GlSkeletonLoader,
  GlTable,
  GlTooltipDirective,
  GlTruncate,
  GlToastMixin,
} from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import { deleteMavenUpstreamCache } from 'ee/api/virtual_registries_api';
import UpstreamClearCacheModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/clear_cache_modal.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import DeleteUpstreamWithModal from './delete_modal.vue';

export default {
  name: 'UpstreamsTable',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlLink,
    GlSkeletonLoader,
    GlTable,
    GlTruncate,
    UpstreamClearCacheModal,
    DeleteUpstreamWithModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin(), GlToastMixin],
  inject: {
    editUpstreamPathTemplate: { default: '' },
    showUpstreamPathTemplate: { default: '' },
    deleteUpstreamCacheMutation: { default: null },
    routes: { default: {} },
  },
  props: {
    upstreams: {
      type: Array,
      required: true,
    },
    busy: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['upstream-deleted', 'upstream-delete-failed'],
  data() {
    return {
      selectedUpstream: null,
      upstreamClearCacheModalIsShown: false,
      upstreamDeleteModalIsShown: false,
    };
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    fields() {
      return [
        {
          key: 'name',
          label: s__('VirtualRegistry|Upstream'),
          tdClass: '@sm/panel:gl-max-w-0',
        },
        {
          key: 'registriesCount',
          label: s__('VirtualRegistry|Used by registries'),
          tdClass: '@sm/panel:gl-w-20 @sm/panel:!gl-leading-32',
        },
        {
          key: 'actions',
          label: s__('VirtualRegistry|Actions'),
          hide: !this.canEdit,
          thAlignRight: true,
          thClass: 'gl-w-26',
          tdClass: 'gl-text-right',
        },
      ].filter((field) => !field.hide);
    },
    selectedUpstreamId() {
      return getIdFromGraphQLId(this.selectedUpstream?.id ?? null);
    },
    selectedUpstreamName() {
      return this.selectedUpstream?.name ?? '';
    },
  },
  methods: {
    showClearUpstreamCacheModal(upstream) {
      this.selectedUpstream = upstream;
      this.upstreamClearCacheModalIsShown = true;
    },
    hideUpstreamClearCacheModal() {
      this.upstreamClearCacheModalIsShown = false;
      this.selectedUpstream = null;
    },
    showUpstreamDeleteModal(upstream) {
      this.selectedUpstream = upstream;
      this.upstreamDeleteModalIsShown = true;
    },
    hideUpstreamDeleteModal() {
      this.upstreamDeleteModalIsShown = false;
      this.selectedUpstream = null;
    },
    parseError(error) {
      captureException({ component: this.$options.name, error });
      return (
        error.response?.data?.delete?.errors.join(', ') ||
        error.response?.data?.error ||
        error.message
      );
    },
    handleSuccess() {
      this.$emit('upstream-deleted');
      this.hideUpstreamDeleteModal();
    },
    handleError(error) {
      this.$emit('upstream-delete-failed', this.parseError(error));
      this.hideUpstreamDeleteModal();
    },
    async clearUpstreamCache() {
      const { id } = this.selectedUpstream;
      this.hideUpstreamClearCacheModal();
      try {
        if (this.deleteUpstreamCacheMutation) {
          const { data } = await this.$apollo.mutate({
            mutation: this.deleteUpstreamCacheMutation,
            variables: {
              id,
            },
          });
          if (data.cacheDelete.errors.length) {
            throw data.cacheDelete.errors;
          }
        } else {
          await deleteMavenUpstreamCache({ id: getIdFromGraphQLId(id) });
        }

        this.$toast.show(s__('VirtualRegistry|Upstream cache cleared successfully.'));
      } catch (error) {
        this.$toast.show(s__('VirtualRegistry|Failed to clear upstream cache. Try again.'));
        captureException({ error, component: this.$options.name });
      }
    },
    getShowUpstreamURL(id) {
      return (
        this.showUpstreamPathTemplate &&
        this.showUpstreamPathTemplate.replace(':id', getIdFromGraphQLId(id))
      );
    },
    getEditUpstreamURL(id) {
      return (
        this.editUpstreamPathTemplate &&
        this.editUpstreamPathTemplate.replace(':id', getIdFromGraphQLId(id))
      );
    },
    getEditUpstreamRouter(id) {
      return { name: this.routes.editUpstreamRouteName, params: { id: getIdFromGraphQLId(id) } };
    },
    getEditUpstreamLabel(name) {
      return sprintf(s__('VirtualRegistry|Edit upstream %{name}'), { name });
    },
    getShowUpstreamRouter(id) {
      return { name: this.routes.showUpstreamRouteName, params: { id: getIdFromGraphQLId(id) } };
    },
    getCacheValidityHoursLabel(cacheValidityHours) {
      return sprintf(
        n__(
          'VirtualRegistry|Artifact cache: %{hours} hour',
          'VirtualRegistry|Artifact cache: %{hours} hours',
          cacheValidityHours,
        ),
        { hours: cacheValidityHours },
      );
    },
    getMetadataCacheValidityHoursLabel(cacheValidityHours) {
      return sprintf(
        n__(
          'VirtualRegistry|Metadata cache: %{hours} hour',
          'VirtualRegistry|Metadata cache: %{hours} hours',
          cacheValidityHours,
        ),
        { hours: cacheValidityHours },
      );
    },
  },
};
</script>

<template>
  <div>
    <gl-table stacked="sm" :fields="fields" :items="upstreams" :busy="busy">
      <template #table-busy>
        <gl-skeleton-loader :lines="2" :width="500" />
      </template>
      <template #cell(name)="{ item }">
        <div class="gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-gap-2">
          <div
            class="gl-flex gl-min-w-0 gl-flex-col gl-flex-wrap gl-items-end gl-gap-x-2 @sm/panel:gl-flex-row @sm/panel:gl-items-start"
          >
            <gl-link
              :href="getShowUpstreamURL(item.id)"
              :to="getShowUpstreamRouter(item.id)"
              class="gl-mr-2 gl-min-w-0 gl-max-w-full gl-font-bold gl-text-default"
              data-testid="upstream-name"
            >
              <gl-truncate
                :text="item.name"
                class="gl-min-w-0 gl-max-w-full hover:gl-underline"
                with-tooltip
              />
            </gl-link>
            <span
              data-testid="upstream-url"
              class="gl-min-w-0 gl-max-w-full gl-overflow-hidden gl-text-default"
            >
              <gl-truncate :text="item.url" class="gl-min-w-0 gl-max-w-full" with-tooltip />
            </span>
          </div>
          <div
            class="gl-flex gl-flex-wrap gl-items-center gl-justify-end gl-gap-2 @sm/panel:gl-justify-normal"
          >
            <div data-testid="cache-validity-hours">
              {{ getCacheValidityHoursLabel(item.cacheValidityHours) }}
            </div>
            <template v-if="item.metadataCacheValidityHours">
              <div>&middot;</div>
              <div data-testid="metadata-cache-validity-hours">
                {{ getMetadataCacheValidityHoursLabel(item.metadataCacheValidityHours) }}
              </div>
            </template>
          </div>
        </div>
      </template>
      <template v-if="canEdit" #cell(actions)="{ item }">
        <gl-button
          size="small"
          category="tertiary"
          data-testid="clear-cache-button"
          @click="showClearUpstreamCacheModal(item)"
        >
          {{ s__('VirtualRegistry|Clear cache') }}
        </gl-button>
        <gl-button
          v-gl-tooltip="__('Edit')"
          :aria-label="getEditUpstreamLabel(item.name)"
          size="small"
          category="tertiary"
          icon="pencil"
          data-testid="edit-upstream-button"
          :href="getEditUpstreamURL(item.id)"
          :to="getEditUpstreamRouter(item.id)"
        />
        <gl-disclosure-dropdown
          icon="ellipsis_v"
          :toggle-text="__('More actions')"
          :text-sr-only="true"
          category="tertiary"
          no-caret
          placement="bottom-end"
        >
          <gl-disclosure-dropdown-item variant="danger" @action="showUpstreamDeleteModal(item)">
            <template #list-item>
              {{ s__('VirtualRegistry|Delete upstream') }}
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown>
      </template>
    </gl-table>
    <delete-upstream-with-modal
      v-model="upstreamDeleteModalIsShown"
      :upstream-id="selectedUpstreamId"
      :upstream-name="selectedUpstreamName"
      @success="handleSuccess"
      @error="handleError"
      @canceled="hideUpstreamDeleteModal"
    />
    <upstream-clear-cache-modal
      v-model="upstreamClearCacheModalIsShown"
      :upstream-name="selectedUpstreamName"
      @primary="clearUpstreamCache"
      @canceled="hideUpstreamClearCacheModal"
    />
  </div>
</template>
