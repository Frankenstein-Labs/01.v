<script>
import { GlAlert, GlBadge, GlButton, GlModal, GlToastMixin } from '@gitlab/ui';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { sprintf, s__, __ } from '~/locale';
import {
  associateMavenUpstreamWithVirtualRegistry,
  deleteMavenRegistryCache,
  deleteMavenUpstreamCache,
  updateMavenRegistryUpstreamPosition,
  removeMavenUpstreamRegistryAssociation,
} from 'ee/api/virtual_registries_api';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/form.vue';
import UpstreamClearCacheModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/clear_cache_modal.vue';
import AddUpstream from './add_upstream.vue';
import LinkUpstreamForm from './link_upstream_form.vue';
import RegistryUpstreamItem from './registry_upstream_item.vue';

const FORM_TYPES = {
  CREATE: 'create',
  LINK: 'link',
};

export default {
  name: 'RegistryShowUpstreamsList',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlModal,
    AddUpstream,
    CrudComponent,
    LinkUpstreamForm,
    RegistryUpstreamItem,
    RegistryUpstreamForm,
    UpstreamClearCacheModal,
  },
  mixins: [glAbilitiesMixin(), GlToastMixin],
  inject: {
    fullPath: {
      default: '',
    },
    getUpstreamsCountQuery: {
      default: null,
    },
    ids: { default: {} },
    deleteRegistryCacheMutation: { default: null },
    deleteUpstreamCacheMutation: { default: null },
    createUpstreamMutation: {
      default: null,
    },
    maxRegistryUpstreamsCount: {
      default: 0,
    },
    createRegistryUpstreamMutation: { default: null },
    deleteRegistryUpstreamMutation: { default: null },
    updateRegistryUpstreamMutation: { default: null },
  },
  props: {
    loading: {
      type: Boolean,
      default: false,
      required: false,
    },
    id: {
      type: String,
      required: true,
    },
    /**
     * The registryUpstreams array
     */
    registryUpstreams: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['update'],
  data() {
    return {
      currentFormType: '',
      createUpstreamError: '',
      createUpstreamMutationLoading: false,
      linkUpstreamInProgress: false,
      registryClearCacheModalIsShown: false,
      topLevelUpstreamsTotalCount: 0,
      upstreamClearCacheModalIsShown: false,
      upstreamToBeCleared: null,
      updateActionErrorMessage: '',
    };
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    canClearRegistryCache() {
      return this.canEdit && this.upstreamsCount;
    },
    linkedUpstreamIds() {
      return this.registryUpstreams.map(({ upstream }) => upstream.id);
    },
    canCreate() {
      return this.glAbilities.createVirtualRegistry;
    },
    canLinkUpstream() {
      return this.canEdit && this.topLevelUpstreamsTotalCount > this.upstreamsCount;
    },
    isCreateUpstreamForm() {
      return this.currentFormType === FORM_TYPES.CREATE;
    },
    isLinkUpstreamForm() {
      return this.currentFormType === FORM_TYPES.LINK;
    },
    upstreamsCount() {
      return this.registryUpstreams.length;
    },
    registryId() {
      return getIdFromGraphQLId(this.id);
    },
    queriesInProgress() {
      return this.$apollo.queries.topLevelUpstreamsTotalCount.loading || this.loading;
    },
    upstreamNameForClearCache() {
      return this.upstreamToBeCleared?.name ?? '';
    },
    upstreamsCountBadgeText() {
      return sprintf(s__('VirtualRegistry|%{count} of %{max}'), {
        max: this.maxRegistryUpstreamsCount,
        count: this.upstreamsCount,
      });
    },
    upstreamsLimitReached() {
      return this.upstreamsCount === this.maxRegistryUpstreamsCount;
    },
  },
  apollo: {
    topLevelUpstreamsTotalCount: {
      query() {
        return this.getUpstreamsCountQuery;
      },
      skip() {
        return !this.canEdit;
      },
      variables() {
        return { groupPath: this.fullPath };
      },
      update: (data) => data.group?.upstreams?.count ?? 0,
    },
  },
  methods: {
    async reorderUpstream(direction, registryUpstream) {
      const position = registryUpstream.position + (direction === 'up' ? -1 : 1);

      this.resetUpdateActionErrorMessage();

      try {
        if (this.updateRegistryUpstreamMutation) {
          const { data } = await this.$apollo.mutate({
            mutation: this.updateRegistryUpstreamMutation,
            variables: {
              id: registryUpstream.id,
              position,
            },
          });

          if (data.update?.errors?.length) {
            throw data.update.errors[0];
          }
        } else {
          await updateMavenRegistryUpstreamPosition({
            id: getIdFromGraphQLId(registryUpstream.id),
            position,
          });
        }

        this.$emit('update');
        this.$toast.show(
          s__('VirtualRegistry|Position of the upstream has been updated successfully.'),
        );
      } catch (error) {
        this.updateActionErrorMessage =
          error.error ||
          (typeof error === 'string' && error) ||
          s__('VirtualRegistry|Failed to update position of the upstream. Try again.');
        this.handleError(error);
      }
    },
    async upstreamAction(name, mutationData) {
      this.createUpstreamMutationLoading = true;
      this.createUpstreamError = '';

      try {
        const {
          data: {
            [name]: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: this.createUpstreamMutation,
          variables: mutationData,
        });

        if (errors.length > 0) {
          this.createUpstreamError = errors.join(', ');
        } else {
          this.hideFormAndEmitUpdate();
          this.$toast.show(s__('VirtualRegistry|Upstream created successfully.'));
        }
      } catch (error) {
        this.createUpstreamError = s__(
          'VirtualRegistry|Something went wrong while creating the upstream. Try again.',
        );
        this.handleError(error);
      } finally {
        this.createUpstreamMutationLoading = false;
      }
    },
    createUpstream(form) {
      this.upstreamAction(this.$options.upstreamRegistryCreate, {
        id: this.id,
        ...form,
      });
    },
    hideFormAndEmitUpdate() {
      this.$emit('update');
      this.hideForm();
    },
    async linkUpstream(upstreamId) {
      this.createUpstreamError = '';
      try {
        this.linkUpstreamInProgress = true;

        if (this.createRegistryUpstreamMutation) {
          const { data } = await this.$apollo.mutate({
            mutation: this.createRegistryUpstreamMutation,
            variables: {
              registryId: this.id,
              upstreamId,
            },
          });

          if (data?.upstreamCreate?.errors?.length) {
            throw data.upstreamCreate.errors[0];
          }
        } else {
          await associateMavenUpstreamWithVirtualRegistry({
            registryId: this.registryId,
            upstreamId: getIdFromGraphQLId(upstreamId),
          });
        }

        this.hideFormAndEmitUpdate();
        this.$toast.show(s__('VirtualRegistry|Upstream added to virtual registry successfully.'));
      } catch (error) {
        this.createUpstreamError = s__(
          'VirtualRegistry|Something went wrong while adding the upstream to virtual registry. Try again.',
        );
        this.handleError(error);
      } finally {
        this.linkUpstreamInProgress = false;
      }
    },
    showClearRegistryCacheModal() {
      this.registryClearCacheModalIsShown = true;
    },
    hideRegistryClearCacheModal() {
      this.registryClearCacheModalIsShown = false;
    },
    async clearRegistryCache() {
      this.resetUpdateActionErrorMessage();
      this.hideRegistryClearCacheModal();
      try {
        if (this.deleteRegistryCacheMutation) {
          const { data } = await this.$apollo.mutate({
            mutation: this.deleteRegistryCacheMutation,
            variables: {
              id: convertToGraphQLId(this.ids.baseRegistry, this.registryId),
            },
          });
          if (data.registryCacheDelete.errors.length) {
            throw data.registryCacheDelete.errors;
          }
        } else {
          await deleteMavenRegistryCache({ id: this.registryId });
        }
        this.$toast.show(s__('VirtualRegistry|Registry cache cleared successfully.'));
      } catch (error) {
        this.updateActionErrorMessage = s__(
          'VirtualRegistry|Failed to clear registry cache. Try again.',
        );
        this.handleError(error);
      }
    },
    showClearUpstreamCacheModal(upstream) {
      this.upstreamToBeCleared = upstream;
      this.upstreamClearCacheModalIsShown = true;
    },
    hideUpstreamClearCacheModal() {
      this.upstreamClearCacheModalIsShown = false;
      this.upstreamToBeCleared = null;
    },
    async clearUpstreamCache() {
      const gid = this.upstreamToBeCleared.id;
      const id = getIdFromGraphQLId(gid);
      this.resetUpdateActionErrorMessage();
      this.hideUpstreamClearCacheModal();
      try {
        if (this.deleteUpstreamCacheMutation) {
          const { data } = await this.$apollo.mutate({
            mutation: this.deleteUpstreamCacheMutation,
            variables: {
              id: gid,
            },
          });
          if (data.cacheDelete.errors.length) {
            throw data.cacheDelete.errors;
          }
        } else {
          await deleteMavenUpstreamCache({ id });
        }
        this.$toast.show(s__('VirtualRegistry|Upstream cache cleared successfully.'));
      } catch (error) {
        this.updateActionErrorMessage = s__(
          'VirtualRegistry|Failed to clear upstream cache. Try again.',
        );
        this.handleError(error);
      }
    },
    async removeUpstream(upstreamAssociationId) {
      this.resetUpdateActionErrorMessage();
      try {
        if (this.deleteRegistryUpstreamMutation) {
          const { data } = await this.$apollo.mutate({
            mutation: this.deleteRegistryUpstreamMutation,
            variables: {
              id: upstreamAssociationId,
            },
          });

          if (data?.upstreamDelete?.errors?.length) {
            throw data.upstreamDelete.errors[0];
          }
        } else {
          await removeMavenUpstreamRegistryAssociation({
            id: getIdFromGraphQLId(upstreamAssociationId),
          });
        }
        this.$toast.show(s__('VirtualRegistry|Removed upstream from virtual registry.'));
        this.$emit('update');
      } catch (error) {
        this.updateActionErrorMessage = s__(
          'VirtualRegistry|Failed to remove upstream. Try again.',
        );
        this.handleError(error);
      }
    },
    resetUpdateActionErrorMessage() {
      this.updateActionErrorMessage = '';
    },
    showCreateForm() {
      this.currentFormType = FORM_TYPES.CREATE;
      this.$refs.registryDetailsCrud.showForm();
    },
    showLinkForm() {
      this.currentFormType = FORM_TYPES.LINK;
      this.$refs.registryDetailsCrud.showForm();
    },
    hideForm() {
      this.$refs.registryDetailsCrud.hideForm();
      this.currentFormType = '';
      if (this.createUpstreamError) {
        this.createUpstreamError = '';
      }
    },
    handleError(error) {
      captureException({ error, component: this.$options.name });
    },
  },
  upstreamRegistryCreate: 'createUpstream',
  modal: {
    primaryAction: {
      text: s__('VirtualRegistry|Clear cache'),
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
  <crud-component
    ref="registryDetailsCrud"
    :title="s__('VirtualRegistry|Upstreams')"
    :is-loading="loading"
    :description="
      s__(
        'VirtualRegistry|Use the arrow buttons to reorder upstreams. Artifacts are resolved from top to bottom.',
      )
    "
  >
    <template #count>
      <gl-badge>
        {{ upstreamsCountBadgeText }}
      </gl-badge>
    </template>
    <template #actions="{ isFormVisible }">
      <gl-button
        v-if="canClearRegistryCache"
        data-testid="clear-registry-cache-button"
        size="small"
        category="tertiary"
        @click="showClearRegistryCacheModal"
      >
        {{ s__('VirtualRegistry|Clear all caches') }}
      </gl-button>
      <span v-if="upstreamsLimitReached" data-testid="max-upstreams">{{
        s__('VirtualRegistry|Maximum number of upstreams reached.')
      }}</span>
      <add-upstream
        v-else-if="canCreate"
        :loading="queriesInProgress"
        :can-link="canLinkUpstream"
        :disabled="isFormVisible"
        @create="showCreateForm"
        @link="showLinkForm"
      />
    </template>
    <template #default>
      <div v-if="upstreamsCount" class="gl-flex gl-flex-col gl-gap-3">
        <gl-alert
          v-if="updateActionErrorMessage"
          data-testid="update-action-error-alert"
          variant="danger"
          @dismiss="resetUpdateActionErrorMessage"
        >
          {{ updateActionErrorMessage }}
        </gl-alert>
        <registry-upstream-item
          v-for="(registryUpstream, index) in registryUpstreams"
          :key="registryUpstream.id"
          :registry-upstream="registryUpstream"
          :upstreams-count="upstreamsCount"
          :index="index"
          @reorder-upstream="reorderUpstream"
          @clear-cache="showClearUpstreamCacheModal"
          @remove-upstream="removeUpstream"
        />
        <gl-modal
          v-model="registryClearCacheModalIsShown"
          data-testid="clear-registry-cache-modal"
          modal-id="clear-registry-cache-modal"
          size="sm"
          :title="s__('VirtualRegistry|Clear all caches?')"
          :action-primary="$options.modal.primaryAction"
          :action-cancel="$options.modal.cancelAction"
          @canceled="hideRegistryClearCacheModal"
          @primary="clearRegistryCache"
        >
          {{
            s__(
              'VirtualRegistry|This will delete all cached packages for exclusive upstream registries in this virtual registry. If any upstream is unavailable or misconfigured after clearing, jobs that rely on those packages might fail. Are you sure you want to continue?',
            )
          }}
        </gl-modal>
        <upstream-clear-cache-modal
          v-model="upstreamClearCacheModalIsShown"
          :upstream-name="upstreamNameForClearCache"
          @primary="clearUpstreamCache"
          @canceled="hideUpstreamClearCacheModal"
        />
      </div>
      <p v-else class="gl-mb-0 gl-text-subtle">
        {{ s__('VirtualRegistry|No upstreams yet') }}
      </p>
    </template>
    <template #form>
      <gl-alert v-if="createUpstreamError" variant="danger" @dismiss="createUpstreamError = ''">
        {{ createUpstreamError }}
      </gl-alert>
      <registry-upstream-form
        v-if="isCreateUpstreamForm"
        :loading="createUpstreamMutationLoading"
        @submit="createUpstream"
        @cancel="hideForm"
      />
      <link-upstream-form
        v-if="isLinkUpstreamForm"
        :loading="linkUpstreamInProgress"
        :linked-upstream-ids="linkedUpstreamIds"
        @submit="linkUpstream"
        @cancel="hideForm"
      />
    </template>
  </crud-component>
</template>
