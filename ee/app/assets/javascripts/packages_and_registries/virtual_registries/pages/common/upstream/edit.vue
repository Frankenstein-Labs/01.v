<script>
import { GlButton, GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { s__, sprintf } from '~/locale';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { createAlert } from '~/alert';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { updateMavenUpstream } from 'ee/api/virtual_registries_api';
import DeleteUpstreamWithModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/delete_modal.vue';
import UpstreamForm from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/form.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

export default {
  name: 'UpstreamEdit',
  components: {
    ErrorsAlert,
    GlButton,
    GlEmptyState,
    GlSkeletonLoader,
    PageHeading,
    UpstreamForm,
    DeleteUpstreamWithModal,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    initialUpstream: {
      default: {},
    },
    routes: { default: {} },
    upstreamsPath: {
      default: '',
    },
    upstreamPath: {
      default: '',
    },
    ids: { default: {} },
    getUpstreamQuery: { default: null },
    updateUpstreamMutation: { default: null },
  },
  props: {
    id: {
      type: [Number, String],
      required: false,
      default: null,
    },
  },
  data() {
    return {
      errors: [],
      loading: false,
      upstream: this.initialUpstream || {},
      upstreamId: convertToGraphQLId(this.ids.baseUpstream, this.id || this.initialUpstream.id),
      upstreamDeleteModalIsShown: false,
    };
  },
  apollo: {
    upstream: {
      query() {
        return this.getUpstreamQuery;
      },
      skip() {
        return Object.keys(this.initialUpstream).length;
      },
      variables() {
        return {
          id: this.upstreamId,
        };
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    deleteModalUpstreamId() {
      return getIdFromGraphQLId(this.upstream.id);
    },
  },
  methods: {
    async updateUpstream(formData) {
      this.errors = [];
      this.loading = true;

      try {
        if (this.updateUpstreamMutation) {
          await this.updateUpstreamWithMutation(formData);
        } else {
          await this.updateUpstreamForMaven(formData);
        }
      } catch (error) {
        this.handleUpdateError(error);
      } finally {
        this.loading = false;
      }
    },
    async updateUpstreamWithMutation(formData) {
      const response = await this.$apollo.mutate({
        mutation: this.updateUpstreamMutation,
        variables: {
          id: this.upstreamId,
          ...formData,
        },
      });

      const { updateUpstream } = response.data;
      const { upstream, errors } = updateUpstream;

      if (errors.length) {
        this.errors = errors;
      } else if (upstream) {
        this.navigateToUpstream(upstream);
        this.showSuccessAlert();
      }
    },
    async updateUpstreamForMaven(formData) {
      const { cacheValidityHours, metadataCacheValidityHours, ...restFields } = formData;

      await updateMavenUpstream({
        id: this.initialUpstream.id,
        data: {
          ...restFields,
          cache_validity_hours: cacheValidityHours,
          metadata_cache_validity_hours: metadataCacheValidityHours,
        },
      });

      visitUrlWithAlerts(this.upstreamPath, [
        {
          message: s__('VirtualRegistry|Maven upstream has been updated.'),
        },
      ]);
    },
    handleUpdateError(error) {
      if (error.response?.status === 400 && typeof error.response?.data?.message === 'object') {
        const message = Object.entries(error.response.data.message)[0].join(' ');
        this.errors = [message];
      } else {
        this.errors = [this.parseError(error)];
      }
    },
    navigateToUpstream(upstream) {
      this.$router.push({
        name: this.routes.showUpstreamRouteName,
        params: { id: getIdFromGraphQLId(upstream.id) },
      });
    },
    showSuccessAlert() {
      createAlert({
        message: sprintf(s__('VirtualRegistry|Upstream %{name} was successfully updated.'), {
          name: this.upstream.name,
        }),
        variant: 'success',
      });
    },
    parseError(error) {
      captureException({ component: this.$options.name, error });
      return error.response?.data?.error || error.message;
    },
    handleSuccess() {
      if (this.upstreamsPath) {
        visitUrlWithAlerts(this.upstreamsPath, [
          {
            message: s__('VirtualRegistry|Maven upstream has been deleted.'),
          },
        ]);
      } else {
        this.$router.push({
          name: this.routes.upstreamsIndexRouteName,
        });
        createAlert({
          message: sprintf(s__('VirtualRegistry|Upstream %{name} was successfully deleted.'), {
            name: this.upstream.name,
          }),
          variant: 'success',
        });
      }
    },

    handleError(error) {
      this.errors = [this.parseError(error)];
    },

    showModal() {
      this.upstreamDeleteModalIsShown = true;
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <gl-skeleton-loader
      v-if="$apollo.queries.upstream.loading"
      :lines="2"
      :width="500"
      class="gl-mt-4"
    />
    <template v-else-if="upstream">
      <page-heading :heading="s__('VirtualRegistry|Edit upstream')" />
      <errors-alert :errors="errors" class="gl-mb-3" @dismiss="errors = []" />
      <upstream-form :upstream="upstream" :loading="loading" @submit="updateUpstream">
        <template v-if="glAbilities.destroyVirtualRegistry" #actions>
          <gl-button category="secondary" variant="danger" @click="showModal">
            {{ s__('VirtualRegistry|Delete upstream') }}
          </gl-button>
        </template>
      </upstream-form>
      <delete-upstream-with-modal
        v-model="upstreamDeleteModalIsShown"
        :upstream-id="deleteModalUpstreamId"
        :upstream-name="upstream.name"
        @success="handleSuccess"
        @error="handleError"
        @canceled="upstreamDeleteModalIsShown = false"
      />
    </template>
    <template v-else>
      <gl-empty-state
        :title="s__('Virtual registry|Upstream not found.')"
        :svg-path="$options.emptySearchSvg"
      />
    </template>
  </div>
</template>
