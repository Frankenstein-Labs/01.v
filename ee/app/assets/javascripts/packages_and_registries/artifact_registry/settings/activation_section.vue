<script>
import { GlAlert, GlButton, GlCard, GlSkeletonLoader } from '@gitlab/ui';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  REGISTRY_ACTION_DISABLE,
  REGISTRY_ACTION_ENABLE,
  REGISTRY_STATUS_ACTIONS,
  REGISTRY_STATUS_INDICATIONS,
  REGISTRY_STATUS_INDICATION_UNKNOWN,
} from '../constants';
import disableArtifactRegistryMutation from '../graphql/mutations/disable_artifact_registry.mutation.graphql';
import enableArtifactRegistryMutation from '../graphql/mutations/enable_artifact_registry.mutation.graphql';
import getArtifactRegistryQuery from '../graphql/queries/get_artifact_registry.query.graphql';
import { buildRegistryClientUrl } from '../utils';
import DisableConfirmation from './disable_confirmation.vue';

// `Object.hasOwn` rather than indexing straight into the map, so an inherited property
// name such as `constructor` arriving as a status reads as unrecognized.
const forStatus = (map, status, fallback = null) =>
  Object.hasOwn(map, status) ? map[status] : fallback;

export default {
  name: 'ArtifactRegistryActivationSection',
  components: {
    ClipboardButton,
    DisableConfirmation,
    GlAlert,
    GlButton,
    GlCard,
    GlSkeletonLoader,
  },
  inject: ['organizationGid', 'clientBaseUrl'],
  emits: ['error', 'success'],
  data() {
    return {
      registry: undefined,
      hasError: false,
      isConfirmingDisable: false,
      isRunningAction: false,
    };
  },
  apollo: {
    registry: {
      query: getArtifactRegistryQuery,
      variables() {
        return { organizationId: this.organizationGid };
      },
      update: ({ organization }) => organization?.artifactRegistry ?? null,
      result({ error }) {
        this.hasError = Boolean(error);
      },
      error() {
        this.hasError = true;
      },
    },
  },
  computed: {
    // Only the first read has nothing to stand in for: a re-read after an action keeps
    // the identity and the control the user just used in place rather than replacing them.
    isLoading() {
      return this.$apollo.queries.registry.loading && this.registry === undefined;
    },
    // A null field is a failed resolution, not a missing registry: the route already
    // answers not-found without a mapping row.
    isUnavailable() {
      return this.hasError || this.registry === null;
    },
    clientUrl() {
      return buildRegistryClientUrl({
        clientBaseUrl: this.clientBaseUrl,
        handle: this.registry.handle,
      });
    },
    activeSince() {
      return localeDateFormat.asDate.format(newDate(this.registry.createdAt));
    },
    indication() {
      return forStatus(
        REGISTRY_STATUS_INDICATIONS,
        this.registry.status,
        REGISTRY_STATUS_INDICATION_UNKNOWN,
      );
    },
    action() {
      return forStatus(REGISTRY_STATUS_ACTIONS, this.registry.status);
    },
    offersDisable() {
      return this.action === REGISTRY_ACTION_DISABLE;
    },
    offersEnable() {
      return this.action === REGISTRY_ACTION_ENABLE;
    },
  },
  methods: {
    disable() {
      return this.runAction({
        mutation: disableArtifactRegistryMutation,
        payloadKey: 'disableRegistry',
        message: this.$options.i18n.disableSuccess,
      });
    },
    enable() {
      return this.runAction({
        mutation: enableArtifactRegistryMutation,
        payloadKey: 'enableRegistry',
        message: this.$options.i18n.enableSuccess,
      });
    },
    async runAction({ mutation, payloadKey, message }) {
      this.isRunningAction = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation,
          variables: { input: { organizationId: this.organizationGid } },
        });

        const { errors } = data[payloadKey];

        if (errors.length) {
          this.$emit('error', errors.join(' '));
          return;
        }

        // The mutation invalidated the resolution Rails had cached, so the new state is
        // read back from Artifact Registry rather than inferred from having asked for it.
        // A read that fails once the condition was applied does not make the action fail,
        // and is not announced as one: the query's own error state renders the section as
        // unavailable, which is where the reader learns the state is unknown.
        try {
          await this.$apollo.queries.registry.refetch();
        } catch (readError) {
          Sentry.captureException(readError);
        }

        this.$emit('success', message);
      } catch (error) {
        this.$emit('error', this.$options.i18n.genericError);
        Sentry.captureException(error);
      } finally {
        this.isRunningAction = false;
        // The section closes the confirmation itself: a successful disable unmounts the
        // dialog before its own loading watcher can, leaving it to reopen with the disable.
        this.isConfirmingDisable = false;
      }
    },
  },
  i18n: {
    unavailable: s__('ArtifactRegistry|The Artifact Registry service is unavailable.'),
    handle: s__('ArtifactRegistry|Registry handle'),
    url: s__('ArtifactRegistry|Registry URL'),
    activeSince: s__('ArtifactRegistry|Active since'),
    copyHandle: s__('ArtifactRegistry|Copy registry handle'),
    copyUrl: s__('ArtifactRegistry|Copy registry URL'),
    disable: s__('ArtifactRegistry|Disable Artifact Registry'),
    enable: s__('ArtifactRegistry|Enable Artifact Registry'),
    disableSuccess: s__('ArtifactRegistry|Artifact Registry was disabled.'),
    enableSuccess: s__('ArtifactRegistry|Artifact Registry was enabled.'),
    genericError: __('Something went wrong. Please try again.'),
  },
};
</script>

<template>
  <div>
    <gl-skeleton-loader v-if="isLoading" :lines="3" :width="400" />

    <gl-alert v-else-if="isUnavailable" variant="danger" :dismissible="false">
      {{ $options.i18n.unavailable }}
    </gl-alert>

    <template v-else>
      <gl-card>
        <template #header>
          <h3 class="gl-my-0 gl-text-base" data-testid="registry-status">{{ indication }}</h3>
        </template>

        <dl class="gl-mb-5 gl-flex gl-flex-col gl-gap-2" data-testid="registry-identity">
          <div class="gl-flex gl-items-center gl-gap-2">
            <dt class="gl-w-18 gl-shrink-0 gl-font-bold">
              {{ $options.i18n.handle }}
            </dt>
            <!-- The copy action sits inside the value it copies: a `dl` may only group
                 `dt` and `dd`, so a control beside them is a structure violation. -->
            <dd class="gl-mb-0 gl-flex gl-items-center gl-gap-2" data-testid="registry-handle">
              {{ registry.handle }}
              <clipboard-button
                :text="registry.handle"
                :title="$options.i18n.copyHandle"
                category="tertiary"
                size="small"
              />
            </dd>
          </div>

          <!-- No registry URL rather than one with a hole in it: the builder returns null
               where the instance configures no usable Artifact Registry origin. -->
          <div v-if="clientUrl" class="gl-flex gl-items-center gl-gap-2">
            <dt class="gl-w-18 gl-shrink-0 gl-font-bold">
              {{ $options.i18n.url }}
            </dt>
            <dd class="gl-mb-0 gl-flex gl-items-center gl-gap-2" data-testid="registry-url">
              <span>{{ clientUrl }}</span>
              <clipboard-button
                :text="clientUrl"
                :title="$options.i18n.copyUrl"
                category="tertiary"
                size="small"
              />
            </dd>
          </div>

          <div class="gl-flex gl-items-center gl-gap-2">
            <dt class="gl-w-18 gl-shrink-0 gl-font-bold">
              {{ $options.i18n.activeSince }}
            </dt>
            <dd class="gl-mb-0" data-testid="registry-active-since">{{ activeSince }}</dd>
          </div>
        </dl>

        <template v-if="action">
          <!-- The confirmation closes as it confirms, so the action it left running is
               reported here or nowhere, and reports it by staying unpressable. -->
          <gl-button
            v-if="offersDisable"
            variant="danger"
            :loading="isRunningAction"
            data-testid="disable-registry"
            @click="isConfirmingDisable = true"
          >
            {{ $options.i18n.disable }}
          </gl-button>

          <gl-button
            v-if="offersEnable"
            variant="confirm"
            :loading="isRunningAction"
            data-testid="enable-registry"
            @click="enable"
          >
            {{ $options.i18n.enable }}
          </gl-button>
        </template>
      </gl-card>

      <disable-confirmation
        v-if="offersDisable"
        v-model="isConfirmingDisable"
        :handle="registry.handle"
        :loading="isRunningAction"
        @confirm="disable"
      />
    </template>
  </div>
</template>
