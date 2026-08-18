<script>
import { GlForm, GlFormGroup, GlFormInput, GlFormTextarea, GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { isValidURL } from '~/lib/utils/url_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import TestUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/test_button.vue';

const DEFAULT_CACHE_VALIDITY_HOURS = 24;
const PASSWORD_PLACEHOLDER = '*****';
const DEFAULT_MAVEN_CENTRAL_CACHE_VALIDITY_HOURS = 0;

export default {
  name: 'UpstreamForm',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlButton,
    TestUpstreamButton,
  },
  inject: {
    mavenCentralUrl: {
      default: '',
    },
    upstreamPath: {
      default: '',
    },
    routes: { default: {} },
    isMavenUpstream: { default: false },
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    upstream: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  i18n: {
    nameLabel: s__('VirtualRegistry|Name'),
    upstreamUrlLabel: s__('VirtualRegistry|Upstream URL'),
    upstreamUrlDescription: s__(
      'VirtualRegistry|You can add GitLab-hosted repositories as upstreams. Use your GitLab username and a personal access token as the password.',
    ),
    upstreamUrlWarning: s__(
      'VirtualRegistry|Changing the URL will clear the username and password.',
    ),
    descriptionLabel: s__('VirtualRegistry|Description (optional)'),
    usernameLabel: s__('VirtualRegistry|Username (optional)'),
    passwordLabel: s__('VirtualRegistry|Password (optional)'),
    passwordDescription: s__(
      'VirtualRegistry|Enter a personal access token for GitLab-hosted upstreams.',
    ),
    passwordPlaceholder: s__('VirtualRegistry|Enter password'),
    cacheValidityHoursLabel: s__('VirtualRegistry|Artifact caching period'),
    cacheValidityHoursHelpText: s__('VirtualRegistry|Time in hours'),
    createUpstreamButtonLabel: s__('VirtualRegistry|Create upstream'),
    metadataCacheValidityHoursLabel: s__('VirtualRegistry|Metadata caching period'),
    invalidUrl: s__('VirtualRegistry|Please provide a valid URL.'),
    cancelButtonLabel: __('Cancel'),
  },
  /**
   * @event submit - Emitted when the form is submitted
   * @property {Object} form - The form data
   */
  /**
   * @event cancel - Emitted when the "Cancel" button is clicked
   */
  emits: ['submit', 'cancel'],
  data() {
    return {
      form: {
        name: this.upstream.name ? this.upstream.name : '',
        url: this.upstream.url ? this.upstream.url : '',
        description: this.upstream.description ? this.upstream.description : '',
        username: this.upstream.username ? this.upstream.username : '',
        password: '',
        // `0` is a valid value for cache validity hour fields
        cacheValidityHours:
          typeof this.upstream.cacheValidityHours === 'number'
            ? this.upstream.cacheValidityHours
            : DEFAULT_CACHE_VALIDITY_HOURS,
        ...(this.isMavenUpstream && {
          metadataCacheValidityHours:
            typeof this.upstream.metadataCacheValidityHours === 'number'
              ? this.upstream.metadataCacheValidityHours
              : DEFAULT_CACHE_VALIDITY_HOURS,
        }),
      },
      showValidation: false,
    };
  },
  ids: {
    nameInputId: 'name-input',
    upstreamUrlInputId: 'upstream-url-input',
    descriptionInputId: 'description-input',
    usernameInputId: 'username-input',
    passwordInputId: 'password-input',
    cacheValidityHoursInputId: 'cache-validity-hours-input',
    metadataCacheValidityHoursInputId: 'metadata-cache-validity-hours-input',
  },
  computed: {
    cancelRoute() {
      return this.upstream.id
        ? {
            name: this.routes.showUpstreamRouteName,
            params: { id: getIdFromGraphQLId(this.upstream.id) },
          }
        : {};
    },
    hasOriginalPassword() {
      return Boolean(this.upstream.username);
    },
    urlWasChanged() {
      return this.upstream.id && this.upstream.url !== this.form.url;
    },
    cacheValidityHoursDescription() {
      if (this.isMavenCentralUrl) {
        return s__(
          'VirtualRegistry|Cache revalidation is disabled. Upstream URL is known to have immutable responses.',
        );
      }
      return '';
    },
    isTestUpstreamButtonDisabled() {
      if (!this.isValidURL) return true;
      return !this.upstream.id && this.form.username.length > 0 && this.form.password.length === 0;
    },
    isValidURL() {
      return isValidURL(this.form.url);
    },
    isValidUrlState() {
      return this.showValidation ? this.isValidURL : true;
    },
    passwordPlaceholder() {
      if (this.hasOriginalPassword && !this.urlWasChanged) {
        return PASSWORD_PLACEHOLDER;
      }
      return '';
    },
    saveButtonText() {
      return this.upstream.id ? __('Save changes') : this.$options.i18n.createUpstreamButtonLabel;
    },
    isMavenCentralUrl() {
      return this.mavenCentralUrl && this.form.url.startsWith(this.mavenCentralUrl);
    },
  },
  methods: {
    handleUrlChange(newUrl) {
      if (!this.upstream.id) return;

      const urlChanged = this.upstream.url !== newUrl;
      this.form.username = urlChanged ? '' : this.upstream.username;
      if (urlChanged) this.form.password = '';
    },
    submit() {
      this.showValidation = true;

      if (this.isValidURL) {
        this.$emit('submit', {
          ...this.form,
          ...(this.isMavenCentralUrl && {
            cacheValidityHours: DEFAULT_MAVEN_CENTRAL_CACHE_VALIDITY_HOURS,
          }),
        });
      }
    },
    cancel() {
      this.$emit('cancel');
    },
  },
  DEFAULT_MAVEN_CENTRAL_CACHE_VALIDITY_HOURS,
};
</script>
<template>
  <gl-form @submit.prevent="submit">
    <gl-form-group :label="$options.i18n.nameLabel" :label-for="$options.ids.nameInputId">
      <gl-form-input
        :id="$options.ids.nameInputId"
        v-model="form.name"
        data-testid="name-input"
        required
        autofocus
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.upstreamUrlLabel"
      :label-for="$options.ids.upstreamUrlInputId"
      :invalid-feedback="$options.i18n.invalidUrl"
      :state="isValidUrlState"
    >
      <gl-form-input
        :id="$options.ids.upstreamUrlInputId"
        v-model="form.url"
        type="url"
        data-testid="upstream-url-input"
        required
        @input="handleUrlChange"
      />
      <template #description>
        <div data-testid="upstream-url-description">
          <p>{{ $options.i18n.upstreamUrlDescription }}</p>
          <p v-if="upstream.id">{{ $options.i18n.upstreamUrlWarning }}</p>
        </div>
      </template>
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.descriptionLabel"
      :label-for="$options.ids.descriptionInputId"
    >
      <gl-form-textarea
        :id="$options.ids.descriptionInputId"
        v-model="form.description"
        data-testid="description-input"
      />
    </gl-form-group>
    <gl-form-group :label="$options.i18n.usernameLabel" :label-for="$options.ids.usernameInputId">
      <gl-form-input
        :id="$options.ids.usernameInputId"
        v-model="form.username"
        data-testid="username-input"
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.passwordLabel"
      :label-for="$options.ids.passwordInputId"
      :description="$options.i18n.passwordDescription"
    >
      <gl-form-input
        :id="$options.ids.passwordInputId"
        v-model="form.password"
        data-testid="password-input"
        :placeholder="passwordPlaceholder"
        type="password"
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.cacheValidityHoursLabel"
      :label-for="$options.ids.cacheValidityHoursInputId"
      :label-description="$options.i18n.cacheValidityHoursHelpText"
      :description="cacheValidityHoursDescription"
    >
      <gl-form-input
        v-if="isMavenCentralUrl"
        :id="$options.ids.cacheValidityHoursInputId"
        :readonly="true"
        data-testid="cache-validity-hours-input"
        class="gl-max-w-15"
        type="number"
        :value="$options.DEFAULT_MAVEN_CENTRAL_CACHE_VALIDITY_HOURS"
        :min="0"
      />
      <gl-form-input
        v-else
        :id="$options.ids.cacheValidityHoursInputId"
        v-model="form.cacheValidityHours"
        data-testid="cache-validity-hours-input"
        class="gl-max-w-15"
        type="number"
        number
        :min="0"
      />
    </gl-form-group>
    <gl-form-group
      v-if="isMavenUpstream"
      :label="$options.i18n.metadataCacheValidityHoursLabel"
      :label-for="$options.ids.metadataCacheValidityHoursInputId"
      :label-description="$options.i18n.cacheValidityHoursHelpText"
    >
      <gl-form-input
        :id="$options.ids.metadataCacheValidityHoursInputId"
        v-model="form.metadataCacheValidityHours"
        data-testid="metadata-cache-validity-hours-input"
        class="gl-max-w-15"
        type="number"
        number
        :min="0"
      />
    </gl-form-group>
    <div class="gl-flex gl-flex-wrap gl-justify-between gl-gap-3">
      <div class="gl-flex gl-gap-3">
        <gl-button
          data-testid="submit-button"
          class="js-no-auto-disable"
          variant="confirm"
          category="primary"
          type="submit"
          :loading="loading"
        >
          {{ saveButtonText }}
        </gl-button>
        <gl-button
          :href="upstreamPath"
          :to="cancelRoute"
          data-testid="cancel-button"
          category="secondary"
          @click="cancel"
        >
          {{ $options.i18n.cancelButtonLabel }}
        </gl-button>
        <test-upstream-button
          :disabled="isTestUpstreamButtonDisabled"
          :upstream-id="upstream.id"
          :url="form.url"
          :username="form.username"
          :password="form.password"
        />
      </div>
      <div>
        <slot name="actions"></slot>
      </div>
    </div>
  </gl-form>
</template>
