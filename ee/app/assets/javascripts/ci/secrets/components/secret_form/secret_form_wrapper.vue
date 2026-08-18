<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, s__ } from '~/locale';
import {
  ENVIRONMENT_FETCH_ERROR,
  ENVIRONMENT_QUERY_LIMIT,
  mapEnvironmentNames,
} from '~/ci/common/private/ci_environments_dropdown';
import { InternalEvents } from '~/tracking';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { formatGraphQLError } from 'ee/ci/secrets/utils';
import {
  ACCEPTED_CONTEXTS,
  ENTITY_PROJECT,
  ENTITLEMENT_STATE_TRIAL_ELIGIBLE,
  INDEX_ROUTE_NAME,
  PAGE_VISIT_EDIT,
  PAGE_VISIT_NEW,
} from 'ee/ci/secrets/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SecretForm from './secret_form.vue';

const i18n = {
  descriptionGroup: s__(
    'SecretsManager|Add a new secret to the group by following the instructions in the form below.',
  ),
  descriptionProject: s__(
    'SecretsManager|Add a new secret to the project by following the instructions in the form below.',
  ),
  titleNew: s__('SecretsManager|New secret'),
};

export default {
  name: 'SecretFormWrapper',
  components: {
    GlLoadingIcon,
    SecretForm,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin(), glListenersMixin],
  inject: ['contextConfig', 'entitlement', 'fullPath'],
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    secretName: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      environments: [],
      secretData: null,
    };
  },
  apollo: {
    environments: {
      skip() {
        return !ACCEPTED_CONTEXTS.includes(this.contextType);
      },
      query() {
        return this.contextConfig.environments.query;
      },
      variables() {
        return {
          first: ENVIRONMENT_QUERY_LIMIT,
          fullPath: this.fullPath,
          search: '',
        };
      },
      update(data) {
        const contextLookupData = this.contextConfig.environments.lookup(data);
        return mapEnvironmentNames(contextLookupData?.nodes || []);
      },
      error(e) {
        createAlert({
          message: ENVIRONMENT_FETCH_ERROR,
          captureError: true,
          error: e,
        });
      },
    },
    secretData: {
      skip() {
        return !this.isEditing;
      },
      query() {
        return this.contextConfig.getSecretDetails.query;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          name: this.secretName,
        };
      },
      update(data) {
        return data.secret || null;
      },
      error(e) {
        createAlert({
          message: formatGraphQLError(e.message),
          captureError: true,
          error: e,
        });
      },
    },
  },
  computed: {
    areEnvironmentsLoading() {
      return this.$apollo.queries.environments.loading;
    },
    contextType() {
      return this.contextConfig.type;
    },
    isSecretLoading() {
      return this.isEditing && this.$apollo.queries.secretData.loading;
    },
    pageDescription() {
      if (this.contextType === ENTITY_PROJECT) {
        return this.$options.i18n.descriptionProject;
      }

      return this.$options.i18n.descriptionGroup;
    },
    pageTitle() {
      if (this.isEditing) {
        return sprintf(s__('SecretsManager|Edit %{name}'), { name: this.secretName });
      }

      return this.$options.i18n.titleNew;
    },
  },
  mounted() {
    if (
      this.glFeatures.secretsManagerPaidExperience &&
      this.entitlement?.state === ENTITLEMENT_STATE_TRIAL_ELIGIBLE
    ) {
      this.$router.push({ name: INDEX_ROUTE_NAME });
      return;
    }

    const { eventTracking } = this.contextConfig;
    const label = this.isEditing ? PAGE_VISIT_EDIT : PAGE_VISIT_NEW;
    this.trackEvent(eventTracking.pageVisit, { label });
  },
  methods: {
    searchEnvironment(searchTerm) {
      this.$apollo.queries.environments.refetch({ search: searchTerm });
    },
  },
  i18n,
};
</script>
<template>
  <div>
    <h1 class="page-title gl-text-size-h-display">{{ pageTitle }}</h1>
    <p v-if="!isEditing">{{ pageDescription }}</p>
    <gl-loading-icon
      v-if="isSecretLoading"
      data-testid="secret-loading-icon"
      size="lg"
      class="gl-mt-6"
    />
    <secret-form
      v-else
      :are-environments-loading="areEnvironmentsLoading"
      :environments="environments"
      :is-editing="isEditing"
      :secret-data="secretData"
      @search-environment="searchEnvironment"
      v-on="glListeners()"
    />
  </div>
</template>
