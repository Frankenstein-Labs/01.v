<script>
import { defineComponent } from 'vue';
import {
  GlAvatar,
  GlBadge,
  GlButton,
  GlIcon,
  GlLink,
  GlLoadingIcon,
  GlModal,
  GlTooltipDirective,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import memberNamespacesQuery from '../graphql/queries/member_namespaces.query.graphql';
import namespaceQuery from '../graphql/queries/namespace.query.graphql';
import orbitUpdateMutation from '../graphql/mutations/orbit_update.mutation.graphql';
import { fetchOrbitStatus } from '../api/orbit_api';
import {
  STATUS_HEALTHY,
  STATUS_MIGRATING,
  STATUS_UNKNOWN,
  GITLAB_COM_STATUS_URL,
} from '../constants';
import ComponentHealthCard from './component_health_card.vue';
import NamespaceIndexCard from './namespace_index_card.vue';
import OrbitEmptyState from './orbit_empty_state.vue';
import TurnOnIndexingModal from './turn_on_indexing_modal.vue';

export default defineComponent({
  name: 'OrbitSettingsPage',
  compatConfig: { MODE: 3 },
  components: {
    GlAvatar,
    GlBadge,
    GlIcon,
    GlButton,
    GlLink,
    GlLoadingIcon,
    GlModal,
    CrudComponent,
    ComponentHealthCard,
    NamespaceIndexCard,
    OrbitEmptyState,
    TurnOnIndexingModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [InternalEvents.mixin()],
  gitlabStatusUrl: GITLAB_COM_STATUS_URL,
  i18n: {
    notOwnerTooltip: s__('Orbit|Only owners of this top-level group can change Orbit indexing.'),
  },
  props: {
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
    explorePath: {
      type: String,
      required: false,
      default: null,
    },
    schemaPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  apollo: {
    namespace: {
      query: namespaceQuery,
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update(data) {
        return data.group || null;
      },
      skip() {
        return !this.groupFullPath;
      },
      error() {
        createAlert({ message: s__('Orbit|Failed to load group. Please try again.') });
      },
    },
    namespaces: {
      query: memberNamespacesQuery,
      variables() {
        return { first: 25 };
      },
      update(data) {
        return data.groups?.nodes || [];
      },
      skip() {
        return Boolean(this.groupFullPath);
      },
      error() {
        createAlert({ message: s__('Orbit|Failed to load groups. Please try again.') });
      },
    },
  },
  data() {
    return {
      namespace: null,
      namespaces: [],
      togglingGroups: {},
      status: {
        version: '-',
        overall: STATUS_UNKNOWN,
        components: [],
      },
      statusLoading: true,
      showServices: false,
      enableNamespace: null,
      pendingDisableNamespace: null,
      disableModalVisible: false,
    };
  },
  computed: {
    isSingleGroupMode() {
      return Boolean(this.groupFullPath);
    },
    singleGroupLoading() {
      return this.$apollo.queries.namespace.loading;
    },
    singleGroupToggling() {
      return this.namespace ? this.isToggling(this.namespace.fullPath) : false;
    },
    namespacesLoading() {
      return this.$apollo.queries.namespaces.loading;
    },
    showComponents() {
      return !this.statusLoading && this.status.components.length > 0;
    },
    isOrbitUnavailable() {
      return (
        !this.statusLoading &&
        this.status.overall !== STATUS_HEALTHY &&
        this.status.overall !== STATUS_MIGRATING
      );
    },
    isOrbitHealthy() {
      return (
        !this.statusLoading &&
        (this.status.overall === STATUS_HEALTHY || this.status.overall === STATUS_MIGRATING)
      );
    },
    servicesButtonLabel() {
      return this.showServices ? s__('Orbit|Hide services') : s__('Orbit|Show services');
    },
    enabledNamespaces() {
      return this.namespaces.filter((ns) => ns.knowledgeGraphEnabled);
    },
    disabledNamespaces() {
      return this.namespaces.filter((ns) => !ns.knowledgeGraphEnabled);
    },
    showConfigurationHeader() {
      if (!this.isSingleGroupMode) return true;
      if (this.singleGroupLoading || !this.namespace) return true;
      return this.namespace.knowledgeGraphEnabled;
    },
    disablePendingToggling() {
      return this.pendingDisableNamespace
        ? this.isToggling(this.pendingDisableNamespace.fullPath)
        : false;
    },
    disablePrimaryAction() {
      return {
        text: s__('Orbit|Turn off indexing'),
        attributes: { variant: 'danger', loading: this.disablePendingToggling },
      };
    },
    disableCancelAction() {
      return {
        text: s__('Orbit|Cancel'),
        attributes: { disabled: this.disablePendingToggling },
      };
    },
  },
  watch: {
    statusLoading(newVal) {
      if (!newVal) {
        this.showServices = this.isOrbitUnavailable;
      }
    },
  },
  mounted() {
    this.fetchStatus();
  },
  methods: {
    async fetchStatus() {
      try {
        const { data } = await fetchOrbitStatus();
        const system = data.system || {};
        this.status = {
          version: system.version || '-',
          overall: system.status || STATUS_UNKNOWN,
          components: system.components || [],
        };
      } catch (error) {
        Sentry.captureException(error);
        createAlert({ message: s__('Orbit|Unable to load cluster status.') });
      } finally {
        this.statusLoading = false;
      }
    },
    isToggling(fullPath) {
      return Boolean(this.togglingGroups[fullPath]);
    },
    handleDisableNamespace(ns) {
      this.trackEvent('click_orbit_turn_off_indexing');
      this.pendingDisableNamespace = ns;
      this.disableModalVisible = true;
    },
    async onConfirmDisable() {
      const ns = this.pendingDisableNamespace;
      if (!ns || this.disablePendingToggling) return;
      await this.toggleNamespace(ns, false);
      this.disableModalVisible = false;
    },
    onDisableModalHidden() {
      if (this.disablePendingToggling) return;
      this.pendingDisableNamespace = null;
    },
    handleEnableNamespace(ns) {
      this.enableNamespace = ns;
    },
    async onIndexingEnabled() {
      if (this.isSingleGroupMode) {
        await this.$apollo.queries.namespace.refetch();
      } else {
        await this.$apollo.queries.namespaces.refetch();
      }
    },
    onEnableModalHidden() {
      this.enableNamespace = null;
    },
    async toggleNamespace(ns, enabled) {
      this.togglingGroups = { ...this.togglingGroups, [ns.fullPath]: true };

      try {
        const { data } = await this.$apollo.mutate({
          mutation: orbitUpdateMutation,
          variables: {
            input: { groupPath: ns.fullPath, enabled },
          },
        });

        const result = data.orbitUpdate;
        if (result.errors?.length) {
          throw new Error(result.errors.join(', '));
        }

        if (this.isSingleGroupMode) {
          await this.$apollo.queries.namespace.refetch();
        } else {
          await this.$apollo.queries.namespaces.refetch();
        }
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          message: s__('Orbit|Failed to update group setting. Please try again.'),
        });
      } finally {
        const { [ns.fullPath]: _, ...rest } = this.togglingGroups;
        this.togglingGroups = rest;
      }
    },
  },
});
</script>

<template>
  <div
    class="gl-flex gl-flex-1 gl-flex-col gl-gap-7 gl-pb-11 gl-pt-5"
    data-testid="orbit-settings-page"
  >
    <div v-if="showConfigurationHeader" class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <h1 class="gl-my-0">{{ s__('Orbit|Orbit configuration') }}</h1>
      <gl-badge variant="info" class="gl-self-center">{{ s__('Orbit|Beta') }}</gl-badge>
      <div v-if="explorePath || schemaPath" class="gl-ml-auto gl-flex gl-flex-row gl-gap-5">
        <gl-link v-if="explorePath" :href="explorePath">{{ s__('Orbit|Explore') }}</gl-link>
        <gl-link v-if="schemaPath" :href="schemaPath">{{ s__('Orbit|Schema') }}</gl-link>
      </div>
    </div>

    <!-- Unavailability banner (top-level group / .com) -->
    <div
      v-if="isSingleGroupMode && isOrbitUnavailable"
      class="gl-flex gl-items-center gl-gap-3 gl-rounded-lg gl-bg-subtle gl-p-4"
      data-testid="orbit-unavailable-row"
    >
      <gl-icon name="warning" variant="danger" :size="16" />
      <span class="gl-mr-auto">{{ s__('Orbit|Orbit is unavailable.') }}</span>
      <gl-link :href="$options.gitlabStatusUrl" target="_blank" rel="noopener noreferrer">
        {{ s__('Orbit|GitLab status') }}
        <gl-icon name="external-link" :size="12" />
      </gl-link>
    </div>

    <!-- Health Status (admin / multi-group) -->
    <crud-component
      v-if="!isSingleGroupMode"
      :is-loading="statusLoading"
      :class="showServices ? null : '!gl-pb-0'"
      :body-class="showServices ? null : 'gl-hidden'"
    >
      <template #title>
        <span v-if="isOrbitHealthy" class="gl-flex gl-items-center gl-gap-3">
          <span
            class="gl-inline-block gl-h-3 gl-w-3 gl-shrink-0 gl-rounded-full gl-bg-status-success"
            aria-hidden="true"
          ></span>
          {{ s__('Orbit|Orbit is available') }}
        </span>
        <span v-else class="gl-flex gl-items-center gl-gap-2">
          <gl-icon name="warning" variant="danger" :size="16" />
          {{ s__('Orbit|Orbit is unavailable') }}
        </span>
      </template>
      <template #actions>
        <div class="gl-flex gl-items-center gl-gap-5">
          <span class="gl-font-monospace gl-text-sm gl-text-subtle"
            >{{ s__('Orbit|Version') }} {{ status.version }}</span
          >
          <gl-button
            size="small"
            data-testid="toggle-services-btn"
            @click="showServices = !showServices"
          >
            {{ servicesButtonLabel }}
          </gl-button>
        </div>
      </template>
      <div class="gl-flex gl-flex-col gl-gap-5">
        <template v-if="showComponents">
          <div class="gl-flex gl-flex-wrap gl-gap-3">
            <component-health-card
              v-for="component in status.components"
              :key="component.name"
              :component="component"
            />
          </div>
        </template>
      </div>
    </crud-component>

    <!-- Single-group mode: current group's Index -->
    <template v-if="isSingleGroupMode">
      <gl-loading-icon v-if="singleGroupLoading" size="lg" />
      <template v-else-if="namespace">
        <section v-if="namespace.knowledgeGraphEnabled">
          <div
            class="gl-flex gl-flex-col gl-gap-3 sm:gl-flex-row sm:gl-items-center"
            data-testid="orbit-index-row"
          >
            <h2 class="gl-heading-2 gl-mb-0 sm:gl-mr-auto">{{ s__('Orbit|Index') }}</h2>
            <span
              v-gl-tooltip="namespace.knowledgeGraphAvailable ? '' : $options.i18n.notOwnerTooltip"
              tabindex="0"
            >
              <gl-button
                category="secondary"
                variant="danger"
                class="gl-whitespace-nowrap"
                :loading="singleGroupToggling"
                :disabled="!namespace.knowledgeGraphAvailable"
                data-testid="turn-off-indexing-btn"
                @click="handleDisableNamespace(namespace)"
              >
                {{ s__('Orbit|Turn off indexing') }}
              </gl-button>
            </span>
          </div>
          <namespace-index-card :namespace="namespace" class="gl-mt-4" />
        </section>
        <orbit-empty-state v-else class="gl-min-h-[70vh]">
          <div class="gl-mt-3">
            <span
              v-gl-tooltip="namespace.knowledgeGraphAvailable ? '' : $options.i18n.notOwnerTooltip"
              tabindex="0"
            >
              <gl-button
                variant="confirm"
                :disabled="!namespace.knowledgeGraphAvailable"
                data-testid="orbit-get-started-btn"
                @click="handleEnableNamespace(namespace)"
              >
                {{ s__('Orbit|Turn on') }}
              </gl-button>
            </span>
          </div>
        </orbit-empty-state>
      </template>
    </template>

    <!-- Multi-group mode (admin): existing all-groups UI -->
    <template v-else>
      <section>
        <h2 class="gl-heading-2">{{ s__('Orbit|Indexed groups') }}</h2>
        <gl-loading-icon v-if="namespacesLoading" size="lg" />
        <template v-else>
          <div class="gl-flex gl-flex-col gl-gap-7">
            <div
              v-for="ns in enabledNamespaces"
              :key="ns.fullPath"
              class="gl-flex gl-flex-col gl-gap-4"
            >
              <div class="gl-flex gl-flex-col gl-gap-3 sm:gl-flex-row sm:gl-items-center">
                <div class="gl-flex gl-min-w-0 gl-items-center gl-gap-3 sm:gl-mr-auto">
                  <gl-avatar
                    :src="ns.avatarUrl"
                    :entity-name="ns.name"
                    :size="32"
                    shape="rect"
                    class="gl-flex-shrink-0"
                  />
                  <h3 class="gl-heading-4 gl-mb-0 gl-min-w-0 gl-break-words">
                    <a
                      :href="`/${ns.fullPath}`"
                      class="gl-text-default gl-no-underline hover:gl-underline"
                    >
                      {{ ns.name }}
                    </a>
                  </h3>
                </div>
                <span
                  v-gl-tooltip="ns.knowledgeGraphAvailable ? '' : $options.i18n.notOwnerTooltip"
                  tabindex="0"
                >
                  <gl-button
                    category="secondary"
                    variant="danger"
                    class="gl-whitespace-nowrap"
                    :loading="isToggling(ns.fullPath)"
                    :disabled="!ns.knowledgeGraphAvailable"
                    @click="handleDisableNamespace(ns)"
                  >
                    {{ s__('Orbit|Turn off indexing') }}
                  </gl-button>
                </span>
              </div>
              <namespace-index-card :namespace="ns" />
            </div>
          </div>
          <p v-if="enabledNamespaces.length === 0" class="gl-mt-3 gl-text-subtle">
            {{ s__('Orbit|No namespaces have indexing enabled.') }}
          </p>
        </template>
      </section>

      <section v-if="!namespacesLoading && disabledNamespaces.length">
        <h2 class="gl-heading-2 gl-mb-2">{{ s__('Orbit|Available groups') }}</h2>
        <p class="gl-mb-3 gl-text-subtle">
          {{ s__('Orbit|Enable indexing for a top-level group to make its projects queryable.') }}
        </p>
        <div
          v-for="ns in disabledNamespaces"
          :key="ns.fullPath"
          class="gl-border-b gl-flex gl-items-center gl-gap-3 gl-border-default gl-py-4 last:gl-border-b-0"
        >
          <gl-avatar :src="ns.avatarUrl" :entity-name="ns.name" :size="24" shape="rect" />
          <a
            :href="`/${ns.fullPath}`"
            class="gl-flex-1 gl-text-default gl-no-underline hover:gl-underline"
            >{{ ns.name }}</a
          >
          <span
            v-gl-tooltip="ns.knowledgeGraphAvailable ? '' : $options.i18n.notOwnerTooltip"
            tabindex="0"
          >
            <gl-button
              variant="confirm"
              :disabled="!ns.knowledgeGraphAvailable"
              @click="handleEnableNamespace(ns)"
            >
              {{ s__('Orbit|Turn on indexing') }}
            </gl-button>
          </span>
        </div>
      </section>
    </template>

    <turn-on-indexing-modal
      modal-id="orbit-settings-enable-modal"
      :group="enableNamespace"
      @enabled="onIndexingEnabled"
      @hidden="onEnableModalHidden"
    />

    <gl-modal
      v-model="disableModalVisible"
      modal-id="orbit-disable-confirm-modal"
      :title="s__('Orbit|Turn off Orbit indexing')"
      :action-primary="disablePrimaryAction"
      :action-cancel="disableCancelAction"
      data-testid="orbit-disable-confirm-modal"
      @primary.prevent="onConfirmDisable"
      @hidden="onDisableModalHidden"
    >
      <p>
        {{
          s__(
            'Orbit|Turning off Orbit indexing will prevent users and agents from accessing Orbit data. Updates will not be scanned by Orbit.',
          )
        }}
      </p>
    </gl-modal>
  </div>
</template>
